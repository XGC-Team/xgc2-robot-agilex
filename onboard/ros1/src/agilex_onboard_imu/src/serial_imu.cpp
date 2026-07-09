// ROS driver for the AgileX onboard ANROT/HI226-style serial IMU.

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <string>

#include <ros/ros.h>
#include <sensor_msgs/Imu.h>
#include <serial/serial.h>

extern "C" {
#include "imu_data_decode.h"
#include "packet.h"
}

namespace {

constexpr double kGravity = 9.8;
constexpr double kDegToRad = 0.01745329;
constexpr std::size_t kBufferSize = 1024;

int frame_rate = 0;

void update_frame_rate(const ros::Time& now)
{
  static ros::Time last_update = now;
  static uint32_t last_frame_count = frame_count;

  if ((now - last_update).toSec() < 1.0) {
    return;
  }

  frame_rate = static_cast<int>(frame_count - last_frame_count);
  last_frame_count = frame_count;
  last_update = now;
}

void dump_data_packet(const receive_imusol_packet_t& data)
{
  if (bitmap & BIT_VALID_ID) {
    std::printf("   Device ID:%6d\n", data.id);
  }

  if (bitmap & BIT_VALID_TIMES) {
    std::printf("   Run time: %d days  %d:%d:%d:%d\n",
                data.times / 86400000,
                data.times / 3600000 % 24,
                data.times / 60000 % 60,
                data.times / 1000 % 60,
                data.times % 1000);
  }

  std::printf(" Frame Rate:  %4dHz\n", frame_rate);
  if (bitmap & BIT_VALID_ACC) {
    std::printf("     Acc(G):%8.3f %8.3f %8.3f\n",
                data.acc[0], data.acc[1], data.acc[2]);
  }

  if (bitmap & BIT_VALID_GYR) {
    std::printf(" Gyr(deg/s):%8.2f %8.2f %8.2f\n",
                data.gyr[0], data.gyr[1], data.gyr[2]);
  }

  if (bitmap & BIT_VALID_MAG) {
    std::printf("    Mag(uT):%8.2f %8.2f %8.2f\n",
                data.mag[0], data.mag[1], data.mag[2]);
  }

  if (bitmap & BIT_VALID_EUL) {
    std::printf(" Eul(R P Y):%8.2f %8.2f %8.2f\n",
                data.eul[0], data.eul[1], data.eul[2]);
  }

  if (bitmap & BIT_VALID_QUAT) {
    std::printf("Quat(W X Y Z):%8.3f %8.3f %8.3f %8.3f\n",
                data.quat[0], data.quat[1], data.quat[2], data.quat[3]);
  }
}

void fill_imu_message(const receive_imusol_packet_t& data, sensor_msgs::Imu* imu_data)
{
  imu_data->orientation.x = data.quat[1];
  imu_data->orientation.y = data.quat[2];
  imu_data->orientation.z = data.quat[3];
  imu_data->orientation.w = data.quat[0];
  imu_data->angular_velocity.x = data.gyr[0] * kDegToRad;
  imu_data->angular_velocity.y = data.gyr[1] * kDegToRad;
  imu_data->angular_velocity.z = data.gyr[2] * kDegToRad;
  imu_data->linear_acceleration.x = data.acc[0] * kGravity;
  imu_data->linear_acceleration.y = data.acc[1] * kGravity;
  imu_data->linear_acceleration.z = data.acc[2] * kGravity;
}

void publish_imu_packet(const receive_imusol_packet_t& data,
                        const ros::Time& stamp,
                        const std::string& frame_id,
                        const ros::Publisher& publisher,
                        bool print_packets)
{
  sensor_msgs::Imu imu_data;
  imu_data.header.stamp = stamp;
  imu_data.header.frame_id = frame_id;
  fill_imu_message(data, &imu_data);
  publisher.publish(imu_data);

  if (print_packets) {
    dump_data_packet(data);
  }
}

}  // namespace

int main(int argc, char** argv)
{
  ros::init(argc, argv, "agilex_onboard_imu");
  ros::NodeHandle nh;
  ros::NodeHandle private_nh("~");

  std::string port;
  std::string topic;
  std::string frame_id;
  int baud = 115200;
  int poll_rate_hz = 500;
  bool print_packets = false;

  private_nh.param<std::string>("port", port, "/dev/imu");
  private_nh.param("baud", baud, 115200);
  private_nh.param<std::string>("topic", topic, "imu/data_raw");
  private_nh.param<std::string>("frame_id", frame_id, "imu_link");
  private_nh.param("poll_rate_hz", poll_rate_hz, 500);
  private_nh.param("print_packets", print_packets, false);

  if (baud <= 0) {
    ROS_ERROR_STREAM("Invalid IMU baud rate: " << baud);
    return 1;
  }

  if (poll_rate_hz <= 0) {
    ROS_WARN_STREAM("Invalid poll_rate_hz " << poll_rate_hz << ", using 500");
    poll_rate_hz = 500;
  }

  ros::Publisher imu_pub = nh.advertise<sensor_msgs::Imu>(topic, 20);

  serial::Serial serial_port;
  serial_port.setPort(port);
  serial_port.setBaudrate(static_cast<uint32_t>(baud));
  serial::Timeout timeout = serial::Timeout::simpleTimeout(100);
  serial_port.setTimeout(timeout);

  imu_data_decode_init();

  try {
    ROS_INFO_STREAM("Opening IMU serial port " << port << " at " << baud << " baud");
    serial_port.open();
  } catch (const serial::IOException& error) {
    ROS_ERROR_STREAM("Unable to open IMU serial port " << port << ": " << error.what());
    return 1;
  }

  if (!serial_port.isOpen()) {
    ROS_ERROR_STREAM("IMU serial port " << port << " did not open");
    return 1;
  }

  ROS_INFO_STREAM("Publishing IMU data on " << imu_pub.getTopic()
                  << " with frame_id " << frame_id);

  ros::Rate loop_rate(poll_rate_hz);
  while (ros::ok()) {
    const std::size_t available = serial_port.available();
    if (available == 0) {
      ros::spinOnce();
      loop_rate.sleep();
      continue;
    }

    uint8_t buffer[kBufferSize];
    const std::size_t read_size = std::min(available, kBufferSize);
    const std::size_t bytes_read = serial_port.read(buffer, read_size);
    if (bytes_read == 0) {
      ros::spinOnce();
      loop_rate.sleep();
      continue;
    }

    const uint32_t frame_count_before_decode = frame_count;
    for (std::size_t i = 0; i < bytes_read; ++i) {
      packet_decode(buffer[i]);
    }

    const ros::Time now = ros::Time::now();
    update_frame_rate(now);

    if (frame_count == frame_count_before_decode) {
      ros::spinOnce();
      loop_rate.sleep();
      continue;
    }

    if (receive_gwsol.tag == KItemGWSOL && receive_gwsol.n > 0) {
      ROS_DEBUG_STREAM("Publishing " << static_cast<int>(receive_gwsol.n)
                       << " IMU samples from gateway " << static_cast<int>(receive_gwsol.gw_id));
      for (int i = 0; i < receive_gwsol.n; ++i) {
        publish_imu_packet(receive_gwsol.receive_imusol[i],
                           now,
                           frame_id,
                           imu_pub,
                           print_packets);
      }
    } else {
      publish_imu_packet(receive_imusol, now, frame_id, imu_pub, print_packets);
    }

    ros::spinOnce();
    loop_rate.sleep();
  }

  serial_port.close();
  return 0;
}
