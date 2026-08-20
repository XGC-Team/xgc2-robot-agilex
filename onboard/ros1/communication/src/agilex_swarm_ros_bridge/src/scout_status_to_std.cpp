// Relay ScoutStatus onto std_msgs the official swarm_ros_bridge can carry.
// /scout_status stays local. Voltage is Float32 at 0.5 Hz; chassis_state is a
// packed UInt32 at 1 Hz. Do not wrap fields as String.

#include <cstdint>
#include <string>

#include <ros/ros.h>
#include <scout_msgs/ScoutStatus.h>
#include <std_msgs/Float32.h>
#include <std_msgs/UInt32.h>

namespace {

scout_msgs::ScoutStatus g_latest;
bool g_have_status = false;

void onStatus(const scout_msgs::ScoutStatus::ConstPtr& msg) {
  g_latest = *msg;
  g_have_status = true;
}

uint32_t packChassisState(const scout_msgs::ScoutStatus& status) {
  return (static_cast<uint32_t>(status.control_mode) & 0xFFu) |
         ((static_cast<uint32_t>(status.base_state) & 0xFFu) << 8) |
         ((static_cast<uint32_t>(status.fault_code) & 0xFFFFu) << 16);
}

}  // namespace

int main(int argc, char** argv) {
  ros::init(argc, argv, "scout_status_to_std");
  ros::NodeHandle nh;
  ros::NodeHandle private_nh("~");

  double voltage_rate_hz = 0.5;
  double chassis_rate_hz = 1.0;
  std::string voltage_topic = "/PowerVoltage";
  std::string chassis_topic = "/scout/chassis_state";
  private_nh.param("voltage_rate", voltage_rate_hz, voltage_rate_hz);
  private_nh.param("chassis_rate", chassis_rate_hz, chassis_rate_hz);
  private_nh.param("voltage_topic", voltage_topic, voltage_topic);
  private_nh.param("chassis_topic", chassis_topic, chassis_topic);
  if (voltage_rate_hz <= 0.0) {
    voltage_rate_hz = 0.5;
  }
  if (chassis_rate_hz <= 0.0) {
    chassis_rate_hz = 1.0;
  }

  ros::Subscriber sub = nh.subscribe("/scout_status", 1, onStatus);
  ros::Publisher voltage_pub = nh.advertise<std_msgs::Float32>(voltage_topic, 1);
  ros::Publisher chassis_pub = nh.advertise<std_msgs::UInt32>(chassis_topic, 1);

  ros::Timer voltage_timer = nh.createTimer(
      ros::Duration(1.0 / voltage_rate_hz), [&](const ros::TimerEvent&) {
        if (!g_have_status) {
          return;
        }
        std_msgs::Float32 message;
        message.data = static_cast<float>(g_latest.battery_voltage);
        voltage_pub.publish(message);
      });
  ros::Timer chassis_timer = nh.createTimer(
      ros::Duration(1.0 / chassis_rate_hz), [&](const ros::TimerEvent&) {
        if (!g_have_status) {
          return;
        }
        std_msgs::UInt32 message;
        message.data = packChassisState(g_latest);
        chassis_pub.publish(message);
      });

  ros::spin();
  return 0;
}
