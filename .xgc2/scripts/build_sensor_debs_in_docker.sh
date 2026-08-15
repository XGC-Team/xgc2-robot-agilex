#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_IMAGE="${DOCKER_IMAGE:-ghcr.io/xgc-team/xgc2-images/xgc2-build-bionic-full-melodic:1.0.0}"
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
docker run --rm --network none \
  -e DEBIAN_FRONTEND=noninteractive \
  -v "${REPO_ROOT}:/workspace/agilex:ro" \
  -v "${WORK_DIR}:/workspace/work" \
  -v "${OUTPUT_DIR}:/workspace/out" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail
    : "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"
    /workspace/agilex/.xgc2/scripts/require_image_ros.sh
    for pkg in \
      "ros-${ROS_DISTRO}-cv-bridge" \
      "ros-${ROS_DISTRO}-image-transport" \
      "ros-${ROS_DISTRO}-pcl-ros" \
      libpcl-dev \
      libyaml-cpp-dev
    do
      if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
        echo "full image is missing ${pkg}; use xgc2-build-<ubuntu>-full-<distro>" >&2
        exit 1
      fi
    done

    rm -rf /workspace/work/build /workspace/work/devel /workspace/work/install-root /workspace/work/src
    mkdir -p /workspace/work/src/agilex-sensors
    rsync -a --delete /workspace/agilex/onboard/ros1/sensors/src/ /workspace/work/src/agilex-sensors/

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
