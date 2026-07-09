#!/usr/bin/env bash
set -euo pipefail

ROS_DISTRO="${ROS_DISTRO:-melodic}"
PREFIX="/opt/ros/${ROS_DISTRO}"
PACKAGE="ros-${ROS_DISTRO}-xgc2-agilex-onboard-imu"
ROS_PACKAGE="agilex_onboard_imu"
COMPAT_ROS_PACKAGE="imu_launch"
NODE="agilex_onboard_imu_node"

dpkg -s "${PACKAGE}" >/dev/null

set +u
source "${PREFIX}/setup.bash"
set -u

rospack find "${ROS_PACKAGE}" >/dev/null
rospack find "${COMPAT_ROS_PACKAGE}" >/dev/null
test -f "${PREFIX}/share/${ROS_PACKAGE}/package.xml"
test -f "${PREFIX}/share/${ROS_PACKAGE}/launch/imu_msg.launch"
test -f "${PREFIX}/share/${COMPAT_ROS_PACKAGE}/package.xml"
test -f "${PREFIX}/share/${COMPAT_ROS_PACKAGE}/launch/imu_msg.launch"
test -x "${PREFIX}/lib/${ROS_PACKAGE}/${NODE}"
roslaunch --files "${ROS_PACKAGE}" imu_msg.launch >/dev/null
roslaunch --files "${COMPAT_ROS_PACKAGE}" imu_msg.launch >/dev/null

echo "Installed AgileX onboard IMU package check passed"
