#!/usr/bin/env bash
set -euo pipefail

ROS_DISTRO="${ROS_DISTRO:-melodic}"
PREFIX="/opt/ros/${ROS_DISTRO}"

deb_packages=(
  "ros-${ROS_DISTRO}-scout-msgs"
  "ros-${ROS_DISTRO}-xgc2-agilex"
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io"
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk"
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base"
  "ros-${ROS_DISTRO}-xgc2-agilex-chassis"
  "ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge"
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-autostart"
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-teleop"
  "ros-${ROS_DISTRO}-xgc2-scout-description"
)

if dpkg -s "ros-${ROS_DISTRO}-swarm-ros-bridge" >/dev/null 2>&1; then
  deb_packages+=("ros-${ROS_DISTRO}-swarm-ros-bridge")
fi

ros_packages=(
  wrp_io
  ugv_sdk
  scout_msgs
  scout_base
  scout_description
  agilex_swarm_ros_bridge
  agilex_onboard_autostart
  xgc2_onboard_teleop
)

for package in "${deb_packages[@]}"; do
  dpkg -s "${package}" >/dev/null
done

if dpkg -s "ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs" >/dev/null 2>&1; then
  echo "retired fork ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs must not be installed" >&2
  exit 1
fi
if dpkg -s "ros-${ROS_DISTRO}-xgc2-agilex-scout-description" >/dev/null 2>&1; then
  echo "retired fork ros-${ROS_DISTRO}-xgc2-agilex-scout-description must not be installed" >&2
  exit 1
fi

set +u
source "${PREFIX}/setup.bash"
set -u

for package in "${ros_packages[@]}"; do
  rospack find "${package}" >/dev/null
  test -f "${PREFIX}/share/${package}/package.xml"
done

test ! -e "${PREFIX}/share/serial_imu/package.xml"
test -f "${PREFIX}/include/wrp_io/async_can.hpp"
test -f "${PREFIX}/lib/libwrp_io.so"
test -f "${PREFIX}/lib/libugv_sdk.so"
test -x "${PREFIX}/lib/scout_base/scout_base_node"
test -f "${PREFIX}/share/scout_description/urdf/scout_visual.urdf"
test ! -d "${PREFIX}/share/scout_description/launch"
test ! -d "${PREFIX}/share/scout_description/maps"
test -f "${PREFIX}/share/agilex_onboard_autostart/launch/description.launch"
test ! -d "${PREFIX}/share/imu_launch"
test ! -d "${PREFIX}/share/scout_bringup"
if dpkg -s "ros-${ROS_DISTRO}-swarm-ros-bridge" >/dev/null 2>&1; then
  test -x "${PREFIX}/lib/swarm_ros_bridge/bridge_node"
  test -f "${PREFIX}/share/swarm_ros_bridge/launch/test.launch"
fi
test ! -f "${PREFIX}/share/agilex_onboard_autostart/launch/base.launch"
test -f "${PREFIX}/share/agilex_onboard_autostart/launch/imu-hi226.launch"
test -f "${PREFIX}/share/agilex_onboard_autostart/launch/chassis.launch"
test -x "${PREFIX}/lib/agilex_onboard_autostart/apply-host-defaults"
test ! -e "${PREFIX}/lib/agilex_onboard_autostart/start-base"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-chassis"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-imu-hi226"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-swarm-ros-bridge"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-camera"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-lidar-helios16"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-mocap"
test ! -e "${PREFIX}/lib/agilex_estimator/vrpn_relay"
test ! -e "${PREFIX}/share/agilex_estimator"
test -x "${PREFIX}/lib/agilex_onboard_autostart/setup-can0"
test -x "${PREFIX}/lib/agilex_onboard_autostart/wait-device"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-roscore"
test -x "${PREFIX}/lib/agilex_onboard_autostart/wait-roscore"
test -x "${PREFIX}/lib/agilex_onboard_autostart/usb-recover"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-field-panel"
test -x "${PREFIX}/lib/agilex_onboard_autostart/start-onboard-teleop"
test -x "${PREFIX}/lib/xgc2_onboard_teleop/onboard_teleop_node"
test -f "${PREFIX}/share/xgc2_onboard_teleop/web/index.html"
test -f "${PREFIX}/share/xgc2_onboard_teleop/launch/teleop.launch"
test ! -e "${PREFIX}/lib/agilex_onboard_autostart/start-communication"
test ! -e "${PREFIX}/lib/agilex_onboard_autostart/scout_status_to_std"
test -x "${PREFIX}/lib/agilex_swarm_ros_bridge/scout_status_to_std"
test ! -e "${PREFIX}/lib/agilex_swarm_ros_bridge/start-swarm-ros-bridge"
test -f "${PREFIX}/share/agilex_swarm_ros_bridge/launch/swarm.launch"
test ! -f "${PREFIX}/share/agilex_swarm_ros_bridge/config/ros_topics.yaml"
test ! -f "${PREFIX}/share/agilex_onboard_autostart/config/ros_topics.yaml"
test -f "${PREFIX}/share/agilex_onboard_autostart/launch/swarm.launch"
test -f /lib/systemd/system/xgc2-agilex-chassis.service
test -f /lib/systemd/system/xgc2-agilex-roscore.service
test -f /lib/systemd/system/xgc2-agilex-usb-recover@.service
test -f /lib/systemd/system/xgc2-field-panel.service
test -f /lib/systemd/system/xgc2-agilex-onboard-teleop.service
test -f /lib/systemd/system/xgc2-agilex-imu-hi226.service
test -f /lib/systemd/system/xgc2-agilex-swarm-ros-bridge.service
test -f /lib/systemd/system/xgc2-agilex-camera.service
test -f /lib/systemd/system/xgc2-agilex-lidar-helios16.service
test -f /lib/systemd/system/xgc2-agilex-mocap.service
test ! -f /lib/systemd/system/xgc2-agilex-base.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-chassis.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-roscore.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-imu-hi226.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-swarm-ros-bridge.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-camera.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-lidar-helios16.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-mocap.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-field-panel.service
test ! -e /etc/systemd/system/multi-user.target.wants/xgc2-agilex-onboard-teleop.service
test ! -f /lib/systemd/system/xgc2-agilex-onboard.target
test ! -f /lib/systemd/system/xgc2-roscore.service
test ! -f /lib/systemd/system/xgc2-agilex-boot-settle.service
test ! -f /lib/systemd/system/xgc2-agilex-can0.service
test ! -f /lib/systemd/system/xgc2-agilex-communication.service
test ! -f /etc/udev/rules.d/99-xgc2-agilex-imu.rules
test -f /etc/udev/rules.d/99-xgc2-agilex-usb-recover.rules
test -f /etc/xgc2/agilex/onboard.env
grep -q '^MOCAP_RIGID_BODY=' /etc/xgc2/agilex/onboard.env
grep -q '^VRPN_SERVER=' /etc/xgc2/agilex/onboard.env
grep -q '^FIELD_PANEL_STATE_SOURCE=estimator$' /etc/xgc2/agilex/onboard.env
! grep -E '^Environment=' /lib/systemd/system/xgc2-agilex-*.service
! grep -E '^Environment=' /lib/systemd/system/xgc2-field-panel.service
! grep -E '^Environment=' /lib/systemd/system/xgc2-agilex-onboard-teleop.service
grep -q 'EnvironmentFile=-/etc/xgc2/agilex/onboard.env' /lib/systemd/system/xgc2-agilex-chassis.service
grep -q 'EnvironmentFile=-/etc/xgc2/agilex/onboard.env' /lib/systemd/system/xgc2-agilex-roscore.service
grep -q 'EnvironmentFile=-/etc/xgc2/agilex/onboard.env' /lib/systemd/system/xgc2-agilex-mocap.service
grep -q 'roslaunch --wait' "${PREFIX}/lib/agilex_onboard_autostart/start-chassis"
grep -q 'required="true"' "${PREFIX}/share/scout_base/launch/scout_mini_base.launch"
test ! -e /etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml

# Field yaml is written by configure network, not packaged. roslaunch --files
# still loads rosparam, so CI uses a throwaway stub.
bridge_stub="$(mktemp)"
cat >"${bridge_stub}" <<'YAML'
send_topics: []
recv_topics: []
YAML

roslaunch --files agilex_onboard_autostart imu-hi226.launch >/dev/null
roslaunch --files agilex_onboard_autostart chassis.launch >/dev/null
roslaunch --files agilex_swarm_ros_bridge swarm.launch "config:=${bridge_stub}" >/dev/null
roslaunch --files agilex_onboard_autostart swarm.launch "config:=${bridge_stub}" >/dev/null
roslaunch --files xgc2_onboard_teleop teleop.launch >/dev/null
rm -f -- "${bridge_stub}"
! grep -E 'look_angle_shaping|guidance_two_stage|agilex_nmpc' \
  "${PREFIX}/lib/agilex_onboard_autostart/start-onboard-teleop"
! grep -E 'look_angle_shaping|guidance_two_stage|agilex_nmpc' \
  "${PREFIX}/lib/xgc2_onboard_teleop/onboard_teleop_node"

echo "Installed AgileX chassis ROS1 package checks passed"
