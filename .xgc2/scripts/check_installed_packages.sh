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
  "ros-${ROS_DISTRO}-xgc2-scout-description"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-bringup"
  "ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge"
  "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-camera"
  "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-description"
  "ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk"
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-autostart"
)

ros_packages=(
  agilex_onboard_imu
  wrp_io
  ugv_sdk
  scout_msgs
  swarm_ros_bridge
  scout_description
  scout_base
  scout_bringup
  agilex_swarm_ros_bridge
  realsense2_camera
  realsense2_description
  rslidar_sdk
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

test -f "${PREFIX}/share/agilex_onboard_imu/launch/imu_msg.launch"
test -x "${PREFIX}/lib/agilex_onboard_imu/agilex_onboard_imu_node"
test -x "${PREFIX}/share/agilex_onboard_imu/scripts/install_imu_udev_rule.sh"

test -f "${PREFIX}/include/wrp_io/async_can.hpp"
test -f "${PREFIX}/include/ugv_sdk/scout/scout_base.hpp"
test -f "${PREFIX}/include/scout_msgs/ScoutStatus.h"
test -f "${PREFIX}/lib/libwrp_io.so"
test -f "${PREFIX}/lib/libugv_sdk.so"
test -x "${PREFIX}/lib/scout_base/scout_base_node"
test ! -e "${PREFIX}/share/scout_base/launch/display_model.launch"
test -f "${PREFIX}/share/scout_description/urdf/scout_visual.urdf"
test ! -d "${PREFIX}/share/scout_description/launch"
test -f "${PREFIX}/share/scout_bringup/launch/description.launch"
test -f "${PREFIX}/share/scout_bringup/launch/display_model.launch"
test -f "${PREFIX}/share/scout_bringup/launch/display_mini_models.launch"
test -f "${PREFIX}/share/scout_bringup/launch/display_scout_mini.launch"
test -f "${PREFIX}/share/scout_bringup/launch/scout_mini_stock.launch"
test -f "${PREFIX}/share/scout_bringup/maps/map.pgm"
test -f "${PREFIX}/share/scout_bringup/maps/map.yaml"
test -f "${PREFIX}/share/scout_bringup/param/4wd/costmap_common_params.yaml"
test -f "${PREFIX}/share/scout_bringup/rviz/model_display.rviz"
test -x "${PREFIX}/lib/swarm_ros_bridge/bridge_node"
test -f "${PREFIX}/share/agilex_swarm_ros_bridge/config/ros_topics.yaml"
test -f "${PREFIX}/share/realsense2_camera/launch/rs_camera.launch"
test -f "${PREFIX}/share/realsense2_description/urdf/_d435.urdf.xacro"
test -x "${PREFIX}/lib/rslidar_sdk/rslidar_sdk_node"
test -f "${PREFIX}/share/rslidar_sdk/launch/start.launch"
test -f "${PREFIX}/share/rslidar_sdk/config/config.yaml"
test -x "${PREFIX}/lib/agilex_onboard_autostart/wait-ros-master"
test -x "${PREFIX}/lib/agilex_onboard_autostart/wait-ros-node"
test -x "${PREFIX}/lib/agilex_onboard_autostart/wait-ros-topic"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-imu"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-chassis"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-swarm-ros-bridge"
test -f /lib/systemd/system/xgc2-agilex-onboard.target
test -f /lib/systemd/system/xgc2-roscore.service
test -f /lib/systemd/system/xgc2-agilex-imu.service
test -f /lib/systemd/system/xgc2-agilex-can0.service
test -f /lib/systemd/system/xgc2-agilex-chassis.service
test -f /lib/systemd/system/xgc2-agilex-swarm-ros-bridge.service
test -f /etc/udev/rules.d/99-xgc2-agilex-imu.rules
test -f /etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml

roslaunch --files agilex_onboard_imu imu_msg.launch >/dev/null
roslaunch --files scout_base scout_mini_base.launch >/dev/null
roslaunch --files scout_bringup scout_minimal.launch >/dev/null
for launch_file in \
  description.launch \
  display_model.launch \
  display_mini_models.launch \
  display_scout_mini.launch \
  scout_mini_stock.launch
do
  roslaunch --files scout_bringup "${launch_file}" >/dev/null
done
roslaunch --files agilex_swarm_ros_bridge agilex_swarm_ros_bridge.launch >/dev/null
roslaunch --files realsense2_camera rs_camera.launch >/dev/null
roslaunch --files rslidar_sdk start.launch >/dev/null

test -x "${PREFIX}/lib/joint_state_publisher/joint_state_publisher"
test -x "${PREFIX}/lib/joint_state_publisher_gui/joint_state_publisher_gui"
test -x "${PREFIX}/lib/robot_state_publisher/robot_state_publisher"
test -x "${PREFIX}/lib/rviz/rviz"

description_version="$(dpkg-query -W -f='${Version}' "ros-${ROS_DISTRO}-xgc2-scout-description")"
dpkg --compare-versions "${description_version}" ge 0.4.10-1
bringup_depends="$(dpkg-query -W -f='${Depends}' "ros-${ROS_DISTRO}-xgc2-agilex-scout-bringup")"
grep -F "ros-${ROS_DISTRO}-xgc2-scout-description (>= 0.4.10-1)" <<<"${bringup_depends}" >/dev/null

if grep -R -E '\$\(find (scout_description|hunter_bringup)\)/(launch|maps|param|rviz)' \
  "${PREFIX}/share/scout_bringup/launch"
then
  echo "scout_bringup still references legacy description-owned runtime assets" >&2
  exit 1
fi

runtime_pids=()
cleanup_runtime() {
  local pid
  for pid in "${runtime_pids[@]}"; do
    kill -INT "${pid}" >/dev/null 2>&1 || true
  done
  for pid in "${runtime_pids[@]}"; do
    wait "${pid}" >/dev/null 2>&1 || true
  done
}
trap cleanup_runtime EXIT

export ROS_MASTER_URI=http://127.0.0.1:11311
roscore >/tmp/xgc2-scout-display-roscore.log 2>&1 &
runtime_pids+=("$!")
for _ in $(seq 1 50); do
  if rosparam list >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
rosparam list >/dev/null

roslaunch scout_bringup display_scout_mini.launch gui:=false \
  >/tmp/xgc2-scout-display-launch.log 2>&1 &
runtime_pids+=("$!")
for _ in $(seq 1 50); do
  if rosparam get /robot_description >/tmp/xgc2-scout-robot-description.xml 2>/dev/null \
    && rosnode list 2>/dev/null | grep -qx '/joint_state_publisher' \
    && rosnode list 2>/dev/null | grep -qx '/robot_state_publisher'
  then
    break
  fi
  sleep 0.1
done

grep -F 'package://scout_description/meshes/' \
  /tmp/xgc2-scout-robot-description.xml >/dev/null
rosnode list | grep -qx '/joint_state_publisher'
rosnode list | grep -qx '/robot_state_publisher'

cleanup_runtime
trap - EXIT

echo "Installed AgileX onboard ROS1 package checks passed"
