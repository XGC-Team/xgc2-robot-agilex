#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-ghcr.io/xgc-team/xgc2-images/xgc2-build-bionic-ros-melodic:1.0.0}"
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

DEPS_DIR="${WORK_DIR}/xgc2-product-debs"
mkdir -p "${DEPS_DIR}"
docker pull "${DOCKER_IMAGE}"
IMAGE_ROS_DISTRO="$(docker run --rm "${DOCKER_IMAGE}" bash -lc 'printf %s "${ROS_DISTRO}"')"
IMAGE_ARCH="$(docker run --rm "${DOCKER_IMAGE}" bash -lc 'dpkg --print-architecture')"
ROS_DISTRO="${IMAGE_ROS_DISTRO}" XGC2_DEB_ARCH="${IMAGE_ARCH}" \
  "${SCRIPT_DIR}/fetch_xgc2_runtime_debs.sh" "${DEPS_DIR}"

docker run --rm --network none \
  -e DEBIAN_FRONTEND=noninteractive \
  -e XGC2_PRODUCT_DEB_DIR=/workspace/deps \
  -v "${REPO_ROOT}:/workspace/agilex:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  -v "${DEPS_DIR}:/workspace/deps:ro" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail
    : "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"
    /workspace/agilex/.xgc2/scripts/require_image_ros.sh
    /workspace/agilex/.xgc2/scripts/install_local_xgc2_debs.sh

    find /workspace/agilex/onboard/ros1/base/src \
      /workspace/agilex/onboard/ros1/communication/src \
      /workspace/agilex/onboard/ros1/autostart/src \
      \( -name package.xml -o -name "*.launch" -o -name "*.xacro" -o -name "*.urdf" \) \
      -print0 | xargs -0 xmllint --noout
    test ! -d /workspace/agilex/onboard/ros1/src
    test ! -d /workspace/agilex/onboard/ros1/base/src/autostart
    test ! -d /workspace/agilex/onboard/ros1/base/src/communication
    test ! -d /workspace/agilex/onboard/ros1/base/src/sensors
    test -f /workspace/agilex/onboard/ros1/autostart/src/agilex_onboard_autostart/package.xml
    test -f /workspace/agilex/onboard/ros1/communication/src/agilex_swarm_ros_bridge/package.xml
    test -f /workspace/agilex/onboard/ros1/sensors/src/agilex_onboard_sensors/package.xml
    test -f /workspace/agilex/onboard/ros1/sensors/src/agilex_d435_media/package.xml

    rm -rf /workspace/work/build /workspace/work/devel /workspace/work/src
    mkdir -p /workspace/work/src/agilex-onboard /workspace/work/src/agilex-communication /workspace/work/src/agilex-autostart
    rsync -a --delete /workspace/agilex/onboard/ros1/base/src/ /workspace/work/src/agilex-onboard/
    rsync -a --delete /workspace/agilex/onboard/ros1/communication/src/ /workspace/work/src/agilex-communication/
    rsync -a --delete /workspace/agilex/onboard/ros1/autostart/src/ /workspace/work/src/agilex-autostart/

    cd /workspace/work
    set +u
    source /opt/ros/${ROS_DISTRO}/setup.bash
    set -u
    catkin_make install \
      -DCMAKE_INSTALL_PREFIX=/opt/ros/${ROS_DISTRO} \
      -DCMAKE_BUILD_TYPE=Release
    set +u
    source devel/setup.bash
    set -u

    test "$(rospack find serial_imu)" = "/workspace/work/src/agilex-onboard/imu/serial_imu"
    test ! -e /workspace/work/src/agilex-onboard/imu/serial_imu/src/subscriber.cpp
    test ! -e /opt/ros/${ROS_DISTRO}/lib/serial_imu/imu_subscriber
    test "$(rospack find wrp_io)" = "/workspace/work/src/agilex-onboard/chassis/wrp_io"
    test "$(rospack find ugv_sdk)" = "/workspace/work/src/agilex-onboard/chassis/ugv_sdk"
    test "$(rospack find scout_msgs)" = "/opt/ros/${ROS_DISTRO}/share/scout_msgs"
    test ! -d /workspace/work/src/agilex-onboard/chassis/scout_msgs
    test "$(rospack find scout_base)" = "/workspace/work/src/agilex-onboard/chassis/scout_base"
    test "$(rospack find scout_description)" = "/opt/ros/${ROS_DISTRO}/share/scout_description"
    test ! -d /workspace/work/src/agilex-onboard/chassis/scout_description
    test ! -d /workspace/work/src/agilex-onboard/communication/swarm_ros_bridge
    if dpkg -s "ros-${ROS_DISTRO}-swarm-ros-bridge" >/dev/null 2>&1; then
      test "$(rospack find swarm_ros_bridge)" = "/opt/ros/${ROS_DISTRO}/share/swarm_ros_bridge"
    else
      echo "ros-${ROS_DISTRO}-swarm-ros-bridge not in image or fetched debs" >&2
    fi
    test "$(rospack find agilex_swarm_ros_bridge)" = "/workspace/work/src/agilex-communication/agilex_swarm_ros_bridge"
    test "$(rospack find agilex_mocap)" = "/workspace/work/src/agilex-communication/agilex_mocap"
    test ! -d /workspace/work/src/agilex-onboard/communication
    test "$(rospack find agilex_onboard_autostart)" = "/workspace/work/src/agilex-autostart/agilex_onboard_autostart"
    test ! -d /workspace/work/src/agilex-onboard/autostart
    test ! -d /workspace/work/src/agilex-onboard/sensors
    test ! -d /workspace/work/src/agilex-onboard/imu/imu_launch
    test ! -d /workspace/work/src/agilex-onboard/chassis/scout_bringup

    test -f "$(rospack find scout_description)/urdf/scout_visual.urdf"
    test ! -d "$(rospack find scout_description)/launch"
    test -f "$(rospack find agilex_onboard_autostart)/launch/base.launch"
    test -f "$(rospack find agilex_onboard_autostart)/launch/description.launch"
    test -f "$(rospack find agilex_swarm_ros_bridge)/launch/swarm.launch"
    test -f "$(rospack find agilex_swarm_ros_bridge)/config/ros_topics.yaml"
    test -f "$(rospack find agilex_onboard_autostart)/launch/swarm.launch"
    test ! -f "$(rospack find agilex_onboard_autostart)/config/ros_topics.yaml"
    test ! -e /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/scout_status_to_std
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/start-base
    test ! -e /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/start-imu
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_swarm_ros_bridge/scout_status_to_std
    test ! -e /opt/ros/${ROS_DISTRO}/lib/agilex_swarm_ros_bridge/start-communication
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/start-communication
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/start-camera
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/start-lidar
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/start-mocap
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_mocap/vrpn_relay
    test -f "$(rospack find agilex_swarm_ros_bridge)/src/scout_status_to_std.cpp"
    test -f "$(rospack find agilex_onboard_autostart)/systemd/xgc2-agilex-base.service"
    test -f "$(rospack find agilex_onboard_autostart)/systemd/xgc2-agilex-communication.service"
    test -f "$(rospack find agilex_onboard_autostart)/systemd/xgc2-agilex-camera.service"
    test -f "$(rospack find agilex_onboard_autostart)/systemd/xgc2-agilex-lidar.service"
    test -f "$(rospack find agilex_onboard_autostart)/systemd/xgc2-agilex-mocap.service"
    test ! -d "$(rospack find agilex_swarm_ros_bridge)/systemd"
    test ! -f "$(rospack find agilex_onboard_autostart)/systemd/xgc2-agilex-onboard.target"
    test ! -f "$(rospack find agilex_onboard_autostart)/systemd/xgc2-roscore.service"

    roslaunch --files agilex_onboard_autostart base.launch >/dev/null
    roslaunch --files agilex_onboard_autostart imu.launch >/dev/null
    roslaunch --files agilex_onboard_autostart chassis.launch >/dev/null
    roslaunch --files agilex_onboard_autostart description.launch >/dev/null
    roslaunch --files agilex_swarm_ros_bridge swarm.launch >/dev/null
    roslaunch --files agilex_onboard_autostart swarm.launch >/dev/null
    roslaunch --files scout_base scout_mini_base.launch >/dev/null
  '
