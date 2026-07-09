#!/usr/bin/env bash
set -euo pipefail

ROS_DISTRO="${ROS_DISTRO:-melodic}"
PREFIX="/opt/ros/${ROS_DISTRO}"

deb_packages=(
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-imu"
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io"
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-description"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-bringup"
)

ros_packages=(
  agilex_onboard_imu
  wrp_io
  ugv_sdk
  scout_msgs
  scout_description
  scout_base
  scout_bringup
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

roslaunch --files agilex_onboard_imu imu_msg.launch >/dev/null
roslaunch --files scout_base scout_mini_base.launch >/dev/null
roslaunch --files scout_bringup scout_minimal.launch >/dev/null

echo "Installed AgileX onboard ROS1 package checks passed"
