#!/usr/bin/env bash
# Official ROS packages must already be in the xgc2-build image layer.
# Never apt-get here.
set -euo pipefail

: "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"

need=(
  "ros-${ROS_DISTRO}-catkin"
  "ros-${ROS_DISTRO}-roscpp"
  "ros-${ROS_DISTRO}-std-msgs"
  "ros-${ROS_DISTRO}-sensor-msgs"
  "ros-${ROS_DISTRO}-geometry-msgs"
)

missing=0
for pkg in "${need[@]}"; do
  if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
    echo "image is missing ${pkg}; use the matching xgc2-build-<ubuntu>-ros-<distro> layer" >&2
    missing=1
  fi
done
if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi
