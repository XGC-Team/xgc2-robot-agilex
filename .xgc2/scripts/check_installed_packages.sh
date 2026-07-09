#!/usr/bin/env bash
set -euo pipefail

ROS_DISTRO="${ROS_DISTRO:-melodic}"
PREFIX="/opt/ros/${ROS_DISTRO}"

deb_packages=(
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-imu"
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io"
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk"
  "ros-${ROS_DISTRO}-scout-msgs"
  "ros-${ROS_DISTRO}-swarm-ros-bridge"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-bringup"
  "ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge"
  "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-camera"
  "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-description"
  "ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk"
)

ros_packages=(
  agilex_onboard_imu
  wrp_io
  ugv_sdk
  scout_msgs
  swarm_ros_bridge
  scout_base
  scout_bringup
  agilex_swarm_ros_bridge
  realsense2_camera
  realsense2_description
  rslidar_sdk
)

for package in "${deb_packages[@]}"; do
  dpkg -s "${package}" >/dev/null
done

set +u
source "${PREFIX}/setup.bash"
set -u

for package in "${ros_packages[@]}"; do
  rospack find "${package}" >/dev/null
  test -f "${PREFIX}/share/${package}/package.xml"
done

test -f "${PREFIX}/share/agilex_onboard_imu/launch/imu_msg.launch"
test -x "${PREFIX}/lib/agilex_onboard_imu/agilex_onboard_imu_node"
test -x "${PREFIX}/share/agilex_onboard_imu/scripts/install_imu_udev_rule.sh"

test -f "${PREFIX}/include/wrp_io/async_can.hpp"
test -f "${PREFIX}/include/ugv_sdk/scout/scout_base.hpp"
test -f "${PREFIX}/include/scout_msgs/ScoutStatus.h"
test -f "${PREFIX}/lib/libwrp_io.so"
test -f "${PREFIX}/lib/libugv_sdk.so"
test -x "${PREFIX}/lib/scout_base/scout_base_node"
test -x "${PREFIX}/lib/swarm_ros_bridge/bridge_node"
test -f "${PREFIX}/share/agilex_swarm_ros_bridge/config/ros_topics.yaml"
test -f "${PREFIX}/share/realsense2_camera/launch/rs_camera.launch"
test -f "${PREFIX}/share/realsense2_description/urdf/_d435.urdf.xacro"
test -x "${PREFIX}/lib/rslidar_sdk/rslidar_sdk_node"
test -f "${PREFIX}/share/rslidar_sdk/launch/start.launch"
test -f "${PREFIX}/share/rslidar_sdk/config/config.yaml"

roslaunch --files agilex_onboard_imu imu_msg.launch >/dev/null
roslaunch --files scout_base scout_mini_base.launch >/dev/null
roslaunch --files scout_bringup scout_minimal.launch >/dev/null
roslaunch --files agilex_swarm_ros_bridge agilex_swarm_ros_bridge.launch >/dev/null
roslaunch --files realsense2_camera rs_camera.launch >/dev/null
roslaunch --files rslidar_sdk start.launch >/dev/null

echo "Installed AgileX onboard ROS1 package checks passed"
