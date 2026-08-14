#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-ros:melodic-ros-base-bionic}"
DOCKER_NETWORK="${DOCKER_NETWORK:-}"
WORK_DIR="${WORK_DIR:-${REPO_ROOT}/.work/source-compliance}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      DOCKER_IMAGE="$2"
      shift 2
      ;;
    --network)
      DOCKER_NETWORK="$2"
      shift 2
      ;;
    --work-dir)
      WORK_DIR="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "${WORK_DIR}"

docker_network_args=()
if [[ -n "${DOCKER_NETWORK}" ]]; then
  docker_network_args=(--network "${DOCKER_NETWORK}")
fi

docker pull "${DOCKER_IMAGE}"
docker run --rm \
  "${docker_network_args[@]}" \
  -e DEBIAN_FRONTEND=noninteractive \
  -v "${REPO_ROOT}:/workspace/agilex:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      libzmq3-dev \
      libzmqpp-dev \
      rsync \
      ros-melodic-geometry-msgs \
      ros-melodic-joint-state-publisher \
      ros-melodic-message-generation \
      ros-melodic-message-runtime \
      ros-melodic-nav-msgs \
      ros-melodic-robot-state-publisher \
      ros-melodic-roscpp \
      ros-melodic-roslaunch \
      ros-melodic-roslib \
      ros-melodic-rospack \
      ros-melodic-rospy \
      ros-melodic-sensor-msgs \
      ros-melodic-serial \
      ros-melodic-std-msgs \
      ros-melodic-tf \
      ros-melodic-tf2 \
      ros-melodic-tf2-ros \
      ros-melodic-topic-tools \
      ros-melodic-xacro

    rm -rf /workspace/work/build /workspace/work/devel /workspace/work/src
    mkdir -p /workspace/work/src/agilex-onboard
    rsync -a --delete /workspace/agilex/onboard/ros1/src/ /workspace/work/src/agilex-onboard/

    cd /workspace/work
    set +u
    source /opt/ros/melodic/setup.bash
    set -u
    catkin_make install \
      -DCMAKE_INSTALL_PREFIX=/opt/ros/melodic \
      -DCMAKE_BUILD_TYPE=Release
    set +u
    source devel/setup.bash
    set -u

    test "$(rospack find serial_imu)" = "/workspace/work/src/agilex-onboard/imu/serial_imu"
    test "$(rospack find imu_launch)" = "/workspace/work/src/agilex-onboard/imu/imu_launch"
    test "$(rospack find wrp_io)" = "/workspace/work/src/agilex-onboard/chassis/wrp_io"
    test "$(rospack find ugv_sdk)" = "/workspace/work/src/agilex-onboard/chassis/ugv_sdk"
    test "$(rospack find scout_msgs)" = "/workspace/work/src/agilex-onboard/chassis/scout_msgs"
    test "$(rospack find scout_base)" = "/workspace/work/src/agilex-onboard/chassis/scout_base"
    test "$(rospack find scout_description)" = "/workspace/work/src/agilex-onboard/chassis/scout_description"
    test "$(rospack find scout_bringup)" = "/workspace/work/src/agilex-onboard/chassis/scout_bringup"
    test "$(rospack find swarm_ros_bridge)" = "/workspace/work/src/agilex-onboard/communication/swarm_ros_bridge"
    test "$(rospack find agilex_onboard_autostart)" = "/workspace/work/src/agilex-onboard/autostart/agilex_onboard_autostart"

    test -f "$(rospack find scout_description)/urdf/scout_v2.xacro"
    test -f "$(rospack find scout_description)/launch/description.launch"
    test ! -e "$(rospack find scout_bringup)/launch/gmapping.launch"
    test ! -e "$(rospack find scout_bringup)/launch/open_rslidar.launch"

    roslaunch --files imu_launch imu_msg.launch >/dev/null
    roslaunch --files scout_base scout_mini_base.launch >/dev/null
    roslaunch --files scout_bringup scout_minimal.launch >/dev/null
    roslaunch --files scout_description description.launch >/dev/null
    roslaunch --files swarm_ros_bridge test.launch >/dev/null
  '
