#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-ros:melodic-ros-base-bionic}"
DOCKER_NETWORK="${DOCKER_NETWORK:-}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-}"
WORK_DIR="${WORK_DIR:-${REPO_ROOT}/.work/docker}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/debs}"
INSTALL_CHECK="${INSTALL_CHECK:-true}"
BUILD_PACKAGES=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      DOCKER_IMAGE="$2"
      shift 2
      ;;
    --work-dir)
      WORK_DIR="$2"
      shift 2
      ;;
    --network)
      DOCKER_NETWORK="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --platform)
      DOCKER_PLATFORM="$2"
      shift 2
      ;;
    --skip-install-check)
      INSTALL_CHECK=false
      shift
      ;;
    --install-check-only)
      BUILD_PACKAGES=false
      INSTALL_CHECK=true
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"

docker_network_args=()
if [[ -n "${DOCKER_NETWORK}" ]]; then
  docker_network_args=(--network "${DOCKER_NETWORK}")
fi

docker_platform_args=()
if [[ -n "${DOCKER_PLATFORM}" ]]; then
  docker_platform_args=(--platform "${DOCKER_PLATFORM}")
fi

docker pull "${docker_platform_args[@]}" "${DOCKER_IMAGE}"
if [[ "${BUILD_PACKAGES}" == "true" ]]; then
  docker run --rm \
  "${docker_platform_args[@]}" \
  "${docker_network_args[@]}" \
  -e DEBIAN_FRONTEND=noninteractive \
  -v "${REPO_ROOT}:/workspace/agilex:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  -v "${OUTPUT_DIR}:/workspace/out" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    : "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"

    apt-get update
    if [[ "${ROS_DISTRO}" == "jazzy" ]]; then
      apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        dpkg-dev \
        fakeroot \
        python3 \
        rsync \
        ros-jazzy-ament-cmake \
        ros-jazzy-ros-core
      /workspace/agilex/.xgc2/scripts/build_ros2_subset.sh \
        --source-root /workspace/agilex/onboard/ros1/src \
        --install-root /workspace/work/install-root \
        --output-dir /workspace/out
    else
      apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        dpkg-dev \
        fakeroot \
        libzmq3-dev \
        libzmqpp-dev \
        rsync \
        ros-${ROS_DISTRO}-geometry-msgs \
        ros-${ROS_DISTRO}-joint-state-publisher \
        ros-${ROS_DISTRO}-message-generation \
        ros-${ROS_DISTRO}-message-runtime \
        ros-${ROS_DISTRO}-nav-msgs \
        ros-${ROS_DISTRO}-robot-state-publisher \
        ros-${ROS_DISTRO}-roscpp \
        ros-${ROS_DISTRO}-roslaunch \
        ros-${ROS_DISTRO}-roslib \
        ros-${ROS_DISTRO}-rospack \
        ros-${ROS_DISTRO}-rospy \
        ros-${ROS_DISTRO}-sensor-msgs \
        ros-${ROS_DISTRO}-serial \
        ros-${ROS_DISTRO}-std-msgs \
        ros-${ROS_DISTRO}-tf \
        ros-${ROS_DISTRO}-tf2 \
        ros-${ROS_DISTRO}-tf2-ros \
        ros-${ROS_DISTRO}-topic-tools \
        ros-${ROS_DISTRO}-xacro

      rm -rf /workspace/work/build /workspace/work/devel /workspace/work/install-root /workspace/work/src
      mkdir -p /workspace/work/src/agilex-onboard
      rsync -a --delete /workspace/agilex/onboard/ros1/src/ /workspace/work/src/agilex-onboard/

      cd /workspace/work
      set +u
      source /opt/ros/${ROS_DISTRO}/setup.bash
      set -u
      parallel_jobs="$(nproc)"
      DESTDIR=/workspace/work/install-root catkin_make -j"${parallel_jobs}" -l"${parallel_jobs}" install \
        -DCMAKE_INSTALL_PREFIX=/opt/ros/${ROS_DISTRO} \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
        -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG"

      /workspace/agilex/.xgc2/scripts/package_debs.sh \
        --install-root /workspace/work/install-root \
        --output-dir /workspace/out
    fi
  '
fi

if [[ "${INSTALL_CHECK}" == "true" ]]; then
  docker run --rm \
    "${docker_platform_args[@]}" \
    "${docker_network_args[@]}" \
    -e DEBIAN_FRONTEND=noninteractive \
    -v "${REPO_ROOT}:/workspace/agilex:ro" \
    -v "${OUTPUT_DIR}:/workspace/out:ro" \
    "${DOCKER_IMAGE}" \
    bash -lc '
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      : "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"
      architecture="$(dpkg --print-architecture)"
      apt-get update

      if [[ "${ROS_DISTRO}" == "jazzy" ]]; then
        apt-get install -y --no-install-recommends ca-certificates
        shopt -s nullglob
        agilex_debs=(/workspace/out/ros-jazzy-xgc2-agilex-*_${architecture}.deb)
        shopt -u nullglob
        if [[ "${#agilex_debs[@]}" -ne 3 ]]; then
          echo "expected 3 AgileX ROS2 debs for ${architecture}, found ${#agilex_debs[@]}" >&2
          ls -la /workspace/out >&2 || true
          exit 1
        fi
        apt-get install -y "${agilex_debs[@]}"
        /workspace/agilex/.xgc2/scripts/check_installed_ros2_packages.sh
      else
        apt-get install -y --no-install-recommends \
          ca-certificates \
          libzmq3-dev \
          libzmqpp-dev \
          ros-${ROS_DISTRO}-geometry-msgs \
          ros-${ROS_DISTRO}-joint-state-publisher \
          ros-${ROS_DISTRO}-message-runtime \
          ros-${ROS_DISTRO}-nav-msgs \
          ros-${ROS_DISTRO}-robot-state-publisher \
          ros-${ROS_DISTRO}-roscpp \
          ros-${ROS_DISTRO}-roslaunch \
          ros-${ROS_DISTRO}-roslib \
          ros-${ROS_DISTRO}-rospack \
          ros-${ROS_DISTRO}-rospy \
          ros-${ROS_DISTRO}-sensor-msgs \
          ros-${ROS_DISTRO}-serial \
          ros-${ROS_DISTRO}-std-msgs \
          ros-${ROS_DISTRO}-tf \
          ros-${ROS_DISTRO}-tf2 \
          ros-${ROS_DISTRO}-tf2-ros \
          ros-${ROS_DISTRO}-topic-tools \
          ros-${ROS_DISTRO}-xacro
        shopt -s nullglob
        agilex_debs=(/workspace/out/ros-${ROS_DISTRO}-xgc2-agilex-*_${architecture}.deb)
        shopt -u nullglob
        if [[ "${#agilex_debs[@]}" -ne 8 ]]; then
          echo "expected 8 AgileX debs for ${architecture}, found ${#agilex_debs[@]}" >&2
          ls -la /workspace/out >&2 || true
          exit 1
        fi
        apt-get install -y "${agilex_debs[@]}"
        /workspace/agilex/.xgc2/scripts/check_installed_packages.sh
      fi
    '
fi

echo "Debian package output:"
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "*.deb" -print | sort
