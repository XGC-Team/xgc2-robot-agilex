#!/usr/bin/env bash
set -euo pipefail

ROS_DISTRO="${ROS_DISTRO:-melodic}"
PREFIX="/opt/ros/${ROS_DISTRO}"

deb_packages=(
  "ros-${ROS_DISTRO}-xgc2-agilex-serial-imu"
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io"
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-description"
  "ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge"
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-autostart"
)

ros_packages=(
  serial_imu
  wrp_io
  ugv_sdk
  scout_msgs
  scout_base
  scout_description
  swarm_ros_bridge
  agilex_onboard_autostart
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

test -x "${PREFIX}/lib/serial_imu/serial_imu"
test -f "${PREFIX}/include/wrp_io/async_can.hpp"
test -f "${PREFIX}/lib/libwrp_io.so"
test -f "${PREFIX}/lib/libugv_sdk.so"
test -x "${PREFIX}/lib/scout_base/scout_base_node"
test -f "${PREFIX}/share/scout_description/urdf/scout_v2.xacro"
test -f "${PREFIX}/share/scout_description/launch/description.launch"
test ! -d "${PREFIX}/share/scout_description/maps"
test ! -d "${PREFIX}/share/imu_launch"
test ! -d "${PREFIX}/share/scout_bringup"
test -x "${PREFIX}/lib/swarm_ros_bridge/bridge_node"
test -f "${PREFIX}/share/swarm_ros_bridge/launch/test.launch"
test -f "${PREFIX}/share/agilex_onboard_autostart/launch/imu.launch"
test -f "${PREFIX}/share/agilex_onboard_autostart/launch/chassis.launch"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-imu"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-chassis"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-swarm-ros-bridge"
test -f /lib/systemd/system/xgc2-agilex-onboard.target
test -f /etc/udev/rules.d/99-xgc2-agilex-imu.rules
test -f /etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml

roslaunch --files agilex_onboard_autostart imu.launch >/dev/null
roslaunch --files agilex_onboard_autostart chassis.launch >/dev/null
roslaunch --files swarm_ros_bridge test.launch >/dev/null

echo "Installed AgileX onboard ROS1 package checks passed"
