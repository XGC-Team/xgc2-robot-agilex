// Serial HI226 IMU. Publish one ROS message per complete decoded packet.

#include <ros/ros.h>
#include <serial/serial.h>
#include <sensor_msgs/Imu.h>
#include <signal.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include "packet.h"
#include "imu_data_decode.h"

#ifdef __cplusplus
}
#endif

#define IMU_SERIAL "/dev/imu"
#define BAUD (115200)
#define GRA_ACC (9.8)
#define DEG_TO_RAD (0.01745329)
#define BUF_SIZE 1024

int imu_data_decode_init(void);

static void publish_imu_data(const receive_imusol_packet_t *data,
                             sensor_msgs::Imu *imu_data) {
  imu_data->orientation.x = data->quat[1];
  imu_data->orientation.y = data->quat[2];
  imu_data->orientation.z = data->quat[3];
  imu_data->orientation.w = data->quat[0];
  imu_data->angular_velocity.x = data->gyr[0] * DEG_TO_RAD;
  imu_data->angular_velocity.y = data->gyr[1] * DEG_TO_RAD;
  imu_data->angular_velocity.z = data->gyr[2] * DEG_TO_RAD;
  imu_data->linear_acceleration.x = data->acc[0] * GRA_ACC;
  imu_data->linear_acceleration.y = data->acc[1] * GRA_ACC;
  imu_data->linear_acceleration.z = data->acc[2] * GRA_ACC;
}

int main(int argc, char **argv) {
  ros::init(argc, argv, "serial_imu");
  ros::NodeHandle n;
  ros::Publisher imu_pub = n.advertise<sensor_msgs::Imu>("imu/data", 200);

  serial::Serial sp;
  sp.setPort(IMU_SERIAL);
  sp.setBaudrate(BAUD);
  sp.setTimeout(serial::Timeout::simpleTimeout(20));

  imu_data_decode_init();

  try {
    sp.open();
  } catch (serial::IOException &e) {
    ROS_ERROR_STREAM("Unable to open " << IMU_SERIAL << ": " << e.what());
    return 1;
  }
  if (!sp.isOpen()) {
    ROS_ERROR_STREAM("Unable to open " << IMU_SERIAL);
    return 1;
  }
  ROS_INFO("serial_imu opened %s at %d", IMU_SERIAL, BAUD);

  sensor_msgs::Imu imu_data;
  imu_data.header.frame_id = "imu_link";
  uint8_t buffer[BUF_SIZE];

  while (ros::ok()) {
    if (!sp.waitReadable()) {
      ros::spinOnce();
      continue;
    }
    size_t num = sp.available();
    if (num == 0) {
      continue;
    }
    if (num > BUF_SIZE) {
      num = BUF_SIZE;
    }
    num = sp.read(buffer, num);
    uint32_t seen = frame_count;
    for (size_t i = 0; i < num; ++i) {
      packet_decode(buffer[i]);
      if (frame_count == seen) {
        continue;
      }
      seen = frame_count;
      if (receive_gwsol.tag == KItemGWSOL) {
        continue;
      }
      imu_data.header.stamp = ros::Time::now();
      imu_data.header.seq = frame_count;
      publish_imu_data(&receive_imusol, &imu_data);
      imu_pub.publish(imu_data);
    }
    ros::spinOnce();
  }

  sp.close();
  return 0;
}
