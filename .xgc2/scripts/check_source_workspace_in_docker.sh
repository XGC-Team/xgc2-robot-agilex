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

docker pull "${DOCKER_IMAGE}"
docker run --rm \
  "${docker_network_args[@]}" \
  -e DEBIAN_FRONTEND=noninteractive \
  -e "XGC2_APT_OVERLAY_URL=${XGC2_APT_OVERLAY_URL:-}" \
  -v "${REPO_ROOT}:/workspace/agilex:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail
    : "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"

    find /workspace/agilex/onboard/ros1/src \
      \( -name package.xml -o -name "*.launch" -o -name "*.xacro" -o -name "*.urdf" \) \
      -print0 | xargs -0 xmllint --noout

    /workspace/agilex/.xgc2/scripts/install_scout_msgs_dependency.sh
    /workspace/agilex/.xgc2/scripts/install_scout_description_dependency.sh
    /workspace/agilex/.xgc2/scripts/install_swarm_ros_bridge_dependency.sh

    rm -rf /workspace/work/build /workspace/work/devel /workspace/work/src
    mkdir -p /workspace/work/src/agilex-onboard
    rsync -a --delete /workspace/agilex/onboard/ros1/src/ /workspace/work/src/agilex-onboard/

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
    test "$(rospack find wrp_io)" = "/workspace/work/src/agilex-onboard/chassis/wrp_io"
    test "$(rospack find ugv_sdk)" = "/workspace/work/src/agilex-onboard/chassis/ugv_sdk"
    test "$(rospack find scout_msgs)" = "/opt/ros/${ROS_DISTRO}/share/scout_msgs"
    test ! -d /workspace/work/src/agilex-onboard/chassis/scout_msgs
    test "$(rospack find scout_base)" = "/workspace/work/src/agilex-onboard/chassis/scout_base"
    test "$(rospack find scout_description)" = "/opt/ros/${ROS_DISTRO}/share/scout_description"
    test ! -d /workspace/work/src/agilex-onboard/chassis/scout_description
    test ! -d /workspace/work/src/agilex-onboard/communication/swarm_ros_bridge
    test "$(rospack find swarm_ros_bridge)" = "/opt/ros/${ROS_DISTRO}/share/swarm_ros_bridge"
    test "$(rospack find agilex_onboard_autostart)" = "/workspace/work/src/agilex-onboard/autostart/agilex_onboard_autostart"
    test ! -d /workspace/work/src/agilex-onboard/imu/imu_launch
    test ! -d /workspace/work/src/agilex-onboard/chassis/scout_bringup

    test -f "$(rospack find scout_description)/urdf/scout_visual.urdf"
    test ! -d "$(rospack find scout_description)/launch"
    test -f "$(rospack find agilex_onboard_autostart)/launch/description.launch"
    test -f "$(rospack find agilex_onboard_autostart)/launch/swarm.launch"
    test -x /opt/ros/${ROS_DISTRO}/lib/agilex_onboard_autostart/scout_status_to_std

    roslaunch --files agilex_onboard_autostart imu.launch >/dev/null
    roslaunch --files agilex_onboard_autostart chassis.launch >/dev/null
    roslaunch --files agilex_onboard_autostart description.launch >/dev/null
    roslaunch --files agilex_onboard_autostart swarm.launch >/dev/null
    roslaunch --files scout_base scout_mini_base.launch >/dev/null
  '
