#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable xgc2-agilex-chassis.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-roscore.service >/dev/null 2>&1 || true
    systemctl disable xgc2-field-panel.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-onboard-teleop.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-imu.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-imu-hi226.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-base.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-communication.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-swarm-ros-bridge.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-camera.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-media-edge.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-lidar.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-lidar-helios16.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-mocap.service >/dev/null 2>&1 || true
  fi
fi

exit 0
