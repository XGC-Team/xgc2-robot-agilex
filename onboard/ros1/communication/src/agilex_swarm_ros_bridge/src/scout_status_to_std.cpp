// Forward bag-validated ScoutStatus fields as standard ROS messages at 1 Hz.
// Official swarm_ros_bridge only carries Imu, Twist, and String.

#include <cstdio>
#include <string>

#include <geometry_msgs/Twist.h>
#include <ros/ros.h>
#include <scout_msgs/ScoutStatus.h>
#include <std_msgs/String.h>

namespace {

scout_msgs::ScoutStatus g_latest;
bool g_have_status = false;

void onStatus(const scout_msgs::ScoutStatus::ConstPtr& msg) {
  g_latest = *msg;
  g_have_status = true;
}

}  // namespace

int main(int argc, char** argv) {
  ros::init(argc, argv, "scout_status_to_std");
  ros::NodeHandle nh;
  ros::NodeHandle private_nh("~");

  double rate_hz = 1.0;
  std::string twist_topic = "/scout/twist";
  std::string text_topic = "/scout/status_text";
  private_nh.param("rate", rate_hz, rate_hz);
  private_nh.param("twist_topic", twist_topic, twist_topic);
  private_nh.param("text_topic", text_topic, text_topic);
  if (rate_hz <= 0.0) {
    rate_hz = 1.0;
  }

  ros::Subscriber sub = nh.subscribe("/scout_status", 1, onStatus);
  ros::Publisher twist_pub = nh.advertise<geometry_msgs::Twist>(twist_topic, 1);
  ros::Publisher text_pub = nh.advertise<std_msgs::String>(text_topic, 1);
  ros::Rate rate(rate_hz);

  while (ros::ok()) {
    ros::spinOnce();
    if (g_have_status) {
      geometry_msgs::Twist twist;
      twist.linear.x = g_latest.linear_velocity;
      twist.angular.z = g_latest.angular_velocity;
      twist_pub.publish(twist);

      char buf[160];
      std::snprintf(
          buf, sizeof(buf),
          "mode=%u base=%u fault=%u batt=%.2f light_mode=%u light=%u",
          static_cast<unsigned>(g_latest.control_mode),
          static_cast<unsigned>(g_latest.base_state),
          static_cast<unsigned>(g_latest.fault_code),
          g_latest.battery_voltage,
          static_cast<unsigned>(g_latest.front_light_state.mode),
          static_cast<unsigned>(g_latest.front_light_state.custom_value));
      std_msgs::String text;
      text.data = buf;
      text_pub.publish(text);
    }
    rate.sleep();
  }
  return 0;
}
