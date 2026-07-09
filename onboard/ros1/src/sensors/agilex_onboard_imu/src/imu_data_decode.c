#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "imu_data_decode.h"
#include "packet.h"

static packet_t RxPkt;

uint8_t bitmap;
receive_imusol_packet_t receive_imusol;
receive_gwsol_packet_t receive_gwsol;

static int stream2int16(int* dest, const uint8_t* src)
{
  dest[0] = (int16_t)(src[0] | src[1] << 8);
  dest[1] = (int16_t)(src[2] | src[3] << 8);
  dest[2] = (int16_t)(src[4] | src[5] << 8);
  return 0;
}

static void on_data_received(packet_t* pkt)
{
  int temp[3] = {0};
  int offset = 0;
  uint8_t* p = pkt->buf;

  if (pkt->type != 0xA5) {
    return;
  }

  bitmap = 0;
  receive_imusol.tag = 0;
  receive_gwsol.tag = 0;
  receive_gwsol.n = 0;

  while (offset < pkt->payload_len) {
    switch (p[offset]) {
      case kItemID:
        if (offset + 2 <= pkt->payload_len) {
          bitmap |= BIT_VALID_ID;
          receive_imusol.id = p[offset + 1];
        }
        offset += 2;
        break;

      case kItemAccRaw:
        if (offset + 7 <= pkt->payload_len) {
          bitmap |= BIT_VALID_ACC;
          stream2int16(temp, p + offset + 1);
          receive_imusol.acc[0] = (float)temp[0] / 1000;
          receive_imusol.acc[1] = (float)temp[1] / 1000;
          receive_imusol.acc[2] = (float)temp[2] / 1000;
        }
        offset += 7;
        break;

      case kItemGyrRaw:
      case kItemGyrRaw_yunjing:
        if (offset + 7 <= pkt->payload_len) {
          bitmap |= BIT_VALID_GYR;
          stream2int16(temp, p + offset + 1);
          receive_imusol.gyr[0] = (float)temp[0] / 10;
          receive_imusol.gyr[1] = (float)temp[1] / 10;
          receive_imusol.gyr[2] = (float)temp[2] / 10;
        }
        offset += 7;
        break;

      case kItemMagRaw:
        if (offset + 7 <= pkt->payload_len) {
          bitmap |= BIT_VALID_MAG;
          stream2int16(temp, p + offset + 1);
          receive_imusol.mag[0] = (float)temp[0] / 10;
          receive_imusol.mag[1] = (float)temp[1] / 10;
          receive_imusol.mag[2] = (float)temp[2] / 10;
        }
        offset += 7;
        break;

      case kItemRotationEul:
        if (offset + 7 <= pkt->payload_len) {
          bitmap |= BIT_VALID_EUL;
          stream2int16(temp, p + offset + 1);
          receive_imusol.eul[1] = (float)temp[0] / 100;
          receive_imusol.eul[0] = (float)temp[1] / 100;
          receive_imusol.eul[2] = (float)temp[2] / 10;
        }
        offset += 7;
        break;

      case kItemRotationQuat:
        if (offset + 17 <= pkt->payload_len) {
          bitmap |= BIT_VALID_QUAT;
          memcpy(receive_imusol.quat, p + offset + 1, sizeof(receive_imusol.quat));
        }
        offset += 17;
        break;

      case kItemPressure:
        offset += 5;
        break;

      case KItemIMUSOL:
        if (offset + 76 <= pkt->payload_len) {
          bitmap = BIT_VALID_ALL;
          receive_imusol.tag = p[offset];
          receive_imusol.id = p[offset + 1];
          memcpy(&receive_imusol.times, p + offset + 8, sizeof(receive_imusol.times));
          memcpy(receive_imusol.acc, p + offset + 12, sizeof(float) * 16);
        }
        offset += 76;
        break;

      case KItemGWSOL: {
        if (offset + 8 > pkt->payload_len) {
          offset = pkt->payload_len;
          break;
        }

        const uint8_t packet_count = p[offset + 2];
        uint8_t stored_count = 0;

        receive_gwsol.tag = p[offset];
        receive_gwsol.gw_id = p[offset + 1];
        bitmap = BIT_VALID_ALL;
        offset += 8;

        for (uint8_t i = 0; i < packet_count && offset + 76 <= pkt->payload_len; ++i) {
          if (stored_count < MAX_LENGTH) {
            receive_imusol_packet_t* target = &receive_gwsol.receive_imusol[stored_count];
            target->tag = p[offset];
            target->id = p[offset + 1];
            memcpy(&target->times, p + offset + 8, sizeof(target->times));
            memcpy(target->acc, p + offset + 12, sizeof(float) * 16);
            ++stored_count;
          }
          offset += 76;
        }
        receive_gwsol.n = stored_count;
        break;
      }

      default:
        ++offset;
        break;
    }
  }
}

int imu_data_decode_init(void)
{
  packet_decode_init(&RxPkt, on_data_received);
  return 0;
}
