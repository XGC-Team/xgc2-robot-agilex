#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-ros:melodic-ros-base-bionic}"
DOCKER_NETWORK="${DOCKER_NETWORK:-}"
WORK_DIR="${WORK_DIR:-${REPO_ROOT}/.work/source-compliance}"
XGC2_APT_BASE_URL="${XGC2_APT_BASE_URL:-https://xgc2.apt.xiaokang.ink}"
XGC2_APT_DISTRIBUTION="${XGC2_APT_DISTRIBUTION:-bionic}"

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
  -e XGC2_APT_OVERLAY_URL="${XGC2_APT_OVERLAY_URL:-}" \
  "${docker_network_args[@]}" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e XGC2_APT_BASE_URL="${XGC2_APT_BASE_URL}" \
  -e XGC2_APT_DISTRIBUTION="${XGC2_APT_DISTRIBUTION}" \
  -v "${REPO_ROOT}:/workspace/agilex:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL "${XGC2_APT_BASE_URL}/xgc2-archive-keyring.gpg" \
      -o /etc/apt/keyrings/xgc2-archive-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] ${XGC2_APT_BASE_URL} ${XGC2_APT_DISTRIBUTION} main" \
      > /etc/apt/sources.list.d/xgc2.list

      if [[ -n "${XGC2_APT_OVERLAY_URL:-}" ]]; then
        sed "s#${XGC2_APT_BASE_URL:-https://xgc2.apt.xiaokang.ink}#${XGC2_APT_OVERLAY_URL%/}#g" \
          /etc/apt/sources.list.d/xgc2.list \
          > /etc/apt/sources.list.d/00-xgc2-release-train.list
      fi
    curl -fsSL https://librealsense.realsenseai.com/Debian/librealsenseai.asc \
      | gpg --dearmor > /etc/apt/keyrings/librealsenseai.gpg
    echo "deb [signed-by=/etc/apt/keyrings/librealsenseai.gpg] https://librealsense.realsenseai.com/Debian/apt-repo bionic main" \
      > /etc/apt/sources.list.d/librealsense.list
    apt-get update
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      git \
      libpcap-dev \
      libpcl-dev \
      librealsense2-dev \
      libyaml-cpp-dev \
      rsync \
      ros-melodic-controller-manager \
      ros-melodic-cv-bridge \
      ros-melodic-ddynamic-reconfigure \
      ros-melodic-diagnostic-updater \
      ros-melodic-genmsg \
      ros-melodic-geometry-msgs \
      ros-melodic-image-transport \
      ros-melodic-message-generation \
      ros-melodic-message-runtime \
      ros-melodic-nav-msgs \
      ros-melodic-nodelet \
      ros-melodic-pcl-conversions \
      ros-melodic-pcl-ros \
      ros-melodic-roscpp \
      ros-melodic-roslaunch \
      ros-melodic-roslib \
      ros-melodic-rospack \
      ros-melodic-scout-msgs \
      ros-melodic-sensor-msgs \
      ros-melodic-serial \
      ros-melodic-std-msgs \
      ros-melodic-std-srvs \
      ros-melodic-swarm-ros-bridge \
      ros-melodic-tf \
      ros-melodic-tf2 \
      ros-melodic-tf2-ros \
      ros-melodic-topic-tools \
      ros-melodic-xacro

    rm -rf /workspace/work/build /workspace/work/devel /workspace/work/install-root /workspace/work/src
    mkdir -p /workspace/work/src/agilex-onboard
    rsync -a --delete --exclude extend/ /workspace/agilex/onboard/ros1/src/ /workspace/work/src/agilex-onboard/

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
    test "$(rospack find agilex_onboard_imu)" = "/workspace/work/src/agilex-onboard/sensors/agilex_onboard_imu"
    test "$(rospack find wrp_io)" = "/workspace/work/src/agilex-onboard/chassis/wrp_io"
    test "$(rospack find ugv_sdk)" = "/workspace/work/src/agilex-onboard/chassis/ugv_sdk"
    test "$(rospack find scout_msgs)" = "/opt/ros/melodic/share/scout_msgs"
    test "$(rospack find swarm_ros_bridge)" = "/opt/ros/melodic/share/swarm_ros_bridge"
    test "$(rospack find scout_base)" = "/workspace/work/src/agilex-onboard/chassis/scout_base"
    test "$(rospack find scout_bringup)" = "/workspace/work/src/agilex-onboard/scout_bringup"
    test "$(rospack find agilex_swarm_ros_bridge)" = "/workspace/work/src/agilex-onboard/communication/agilex_swarm_ros_bridge"
    test "$(rospack find realsense2_camera)" = "/workspace/work/src/agilex-onboard/sensors/realsense2_camera"
    test "$(rospack find realsense2_description)" = "/workspace/work/src/agilex-onboard/sensors/realsense2_description"
    test "$(rospack find rslidar_sdk)" = "/workspace/work/src/agilex-onboard/sensors/rslidar_sdk"
    test "$(rospack find agilex_onboard_autostart)" = "/workspace/work/src/agilex-onboard/autostart/agilex_onboard_autostart"
    roslaunch --files agilex_onboard_imu imu_msg.launch >/tmp/xgc2-agilex-onboard-imu-files.txt
    roslaunch --files scout_base scout_mini_base.launch >/tmp/xgc2-agilex-scout-base-files.txt
    roslaunch --files scout_bringup scout_minimal.launch >/tmp/xgc2-agilex-scout-bringup-files.txt
    roslaunch --files agilex_swarm_ros_bridge agilex_swarm_ros_bridge.launch >/tmp/xgc2-agilex-swarm-ros-bridge-files.txt
    roslaunch --files realsense2_camera rs_camera.launch >/tmp/xgc2-agilex-realsense2-camera-files.txt
    roslaunch --files rslidar_sdk start.launch >/tmp/xgc2-agilex-rslidar-sdk-files.txt
  '

echo "Source workspace compliance check passed"
