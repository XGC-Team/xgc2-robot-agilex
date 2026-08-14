// Exclusive capture owner: librealsense -> ROS Image + GStreamer H264/RTP.
// Do not run this while realsense2_camera already holds the device.
#include <librealsense2/rs.hpp>
#include <ros/ros.h>
#include <sensor_msgs/Image.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

int main(int argc, char** argv) {
  ros::init(argc, argv, "d435_parallel_source");
  ros::NodeHandle nh;
  ros::NodeHandle pnh("~");
  ROS_ERROR(
      "d435_parallel_source is the exclusive-capture path. "
      "Do not start it while realsense2_camera is running. "
      "Use ros_fallback_rtp for WebRTC without stealing the device.");
  return 1;
}
