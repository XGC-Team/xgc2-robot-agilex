#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_IMAGE="${DOCKER_IMAGE:-ghcr.io/xgc-team/xgc2-images/xgc2-build-bionic-ros-melodic:1.0.0}"
WORK_DIR="${WORK_DIR:-${REPO_ROOT}/.work/sensors-docker}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/debs-sensors}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) DOCKER_IMAGE="$2"; shift 2 ;;
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"
docker pull "${DOCKER_IMAGE}"
docker run --rm \
  -e DEBIAN_FRONTEND=noninteractive \
  -v "${REPO_ROOT}:/workspace/agilex:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  -v "${OUTPUT_DIR}:/workspace/out" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail
    : "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
      ca-certificates \
      gnupg \
      libpcap-dev \
      libpcl-dev \
      libyaml-cpp-dev \
      ros-${ROS_DISTRO}-cv-bridge \
      ros-${ROS_DISTRO}-ddynamic-reconfigure \
      ros-${ROS_DISTRO}-diagnostic-updater \
      ros-${ROS_DISTRO}-image-transport \
      ros-${ROS_DISTRO}-nodelet \
      ros-${ROS_DISTRO}-pcl-conversions \
      ros-${ROS_DISTRO}-pcl-ros \
      ros-${ROS_DISTRO}-tf \
      rsync || true

    if ! pkg-config --exists realsense2; then
      apt-get install -y --no-install-recommends software-properties-common || true
      apt-key adv --keyserver keyserver.ubuntu.com --recv-key \
        F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE || true
      add-apt-repository -y \
        "deb https://librealsense.intel.com/Debian/apt-repo $(. /etc/os-release && echo $VERSION_CODENAME) main" || true
      apt-get update || true
      apt-get install -y --no-install-recommends librealsense2-dev || true
    fi

    rm -rf /workspace/work/build /workspace/work/devel /workspace/work/install-root /workspace/work/src
    mkdir -p /workspace/work/src/agilex-sensors
    rsync -a --delete /workspace/agilex/onboard/ros1/sensors/src/ /workspace/work/src/agilex-sensors/
    if ! pkg-config --exists realsense2; then
      echo "librealsense2 missing; skipping realsense2_camera compile" >&2
      touch /workspace/work/src/agilex-sensors/realsense2_camera/CATKIN_IGNORE
    fi

    cd /workspace/work
    set +u
    source /opt/ros/${ROS_DISTRO}/setup.bash
    set -u
    parallel_jobs="$(nproc)"
    DESTDIR=/workspace/work/install-root catkin_make -j"${parallel_jobs}" -l"${parallel_jobs}" install \
      -DCMAKE_INSTALL_PREFIX=/opt/ros/${ROS_DISTRO} \
      -DCMAKE_BUILD_TYPE=Release

    /workspace/agilex/.xgc2/scripts/package_sensor_debs.sh \
      --install-root /workspace/work/install-root \
      --output-dir /workspace/out
  '

echo "Sensor Debian package output:"
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "*.deb" -print | sort
