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
      git \
      rsync \
      ros-melodic-controller-manager \
      ros-melodic-geometry-msgs \
      ros-melodic-joint-state-publisher \
      ros-melodic-message-generation \
      ros-melodic-message-runtime \
      ros-melodic-nav-msgs \
      ros-melodic-roscpp \
      ros-melodic-roslaunch \
      ros-melodic-rospack \
      ros-melodic-robot-state-publisher \
      ros-melodic-scout-msgs \
      ros-melodic-sensor-msgs \
      ros-melodic-serial \
      ros-melodic-std-msgs \
      ros-melodic-tf \
      ros-melodic-tf2 \
      ros-melodic-tf2-ros \
      ros-melodic-topic-tools \
      ros-melodic-urdf \
      ros-melodic-xacro

    rm -rf /workspace/work/build /workspace/work/devel /workspace/work/install-root /workspace/work/src
    mkdir -p /workspace/work/src/agilex-onboard
    rsync -a --delete /workspace/agilex/onboard/ros1/src/ /workspace/work/src/agilex-onboard/

    cd /workspace/work
    set +u
    source /opt/ros/melodic/setup.bash
    set -u
    DESTDIR=/workspace/work/install-root catkin_make install \
      -DCMAKE_INSTALL_PREFIX=/opt/ros/melodic \
      -DCMAKE_BUILD_TYPE=Release
    set +u
    source devel/setup.bash
    set -u
    test "$(rospack find agilex_onboard_imu)" = "/workspace/work/src/agilex-onboard/imu/agilex_onboard_imu"
    test "$(rospack find wrp_io)" = "/workspace/work/src/agilex-onboard/chassis/wrp_io"
    test "$(rospack find ugv_sdk)" = "/workspace/work/src/agilex-onboard/chassis/ugv_sdk"
    test "$(rospack find scout_msgs)" = "/opt/ros/melodic/share/scout_msgs"
    test "$(rospack find scout_description)" = "/workspace/work/src/agilex-onboard/chassis/scout_description"
    test "$(rospack find scout_base)" = "/workspace/work/src/agilex-onboard/chassis/scout_base"
    test "$(rospack find scout_bringup)" = "/workspace/work/src/agilex-onboard/chassis/scout_bringup"
    roslaunch --files agilex_onboard_imu imu_msg.launch >/tmp/xgc2-agilex-onboard-imu-files.txt
    roslaunch --files scout_base scout_mini_base.launch >/tmp/xgc2-agilex-scout-base-files.txt
    roslaunch --files scout_bringup scout_minimal.launch >/tmp/xgc2-agilex-scout-bringup-files.txt
  '

echo "Source workspace compliance check passed"
