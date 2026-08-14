#!/usr/bin/env bash
set -euo pipefail

ROS_DISTRO="${ROS_DISTRO:-jazzy}"
PREFIX="/opt/ros/${ROS_DISTRO}"

for package in \
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io" \
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk" \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-description"
do
  dpkg -s "${package}" >/dev/null
done

test -f "${PREFIX}/include/wrp_io/async_can.hpp"
test -f "${PREFIX}/lib/libwrp_io.so"
test -f "${PREFIX}/lib/libugv_sdk.so"
test -f "${PREFIX}/share/scout_description/urdf/scout_v2.xacro"
test -f "${PREFIX}/share/scout_description/launch/description.launch"

echo "Installed AgileX ROS2 subset package checks passed"
