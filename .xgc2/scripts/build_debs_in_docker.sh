#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-ghcr.io/xgc-team/xgc2-images/xgc2-build-bionic-ros-melodic:1.0.0}"
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
    : "${ROS_DISTRO:?ROS_DISTRO must be set in the image}"

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
      shopt -s nullglob
      agilex_debs=(/workspace/out/ros-${ROS_DISTRO}-xgc2-agilex-*_${architecture}.deb)
      agilex_meta=(/workspace/out/ros-${ROS_DISTRO}-xgc2-agilex_*_${architecture}.deb)
      shopt -u nullglob
      if [[ "${#agilex_debs[@]}" -ne 8 ]]; then
        echo "expected 8 AgileX debs for ${architecture}, found ${#agilex_debs[@]}" >&2
        ls -la /workspace/out >&2 || true
        exit 1
      fi
      if [[ "${#agilex_meta[@]}" -ne 1 ]]; then
        echo "expected 1 AgileX meta deb, found ${#agilex_meta[@]}" >&2
        ls -la /workspace/out >&2 || true
        exit 1
      fi
      apt-get install -y "${agilex_debs[@]}" "${agilex_meta[@]}"
      /workspace/agilex/.xgc2/scripts/check_installed_packages.sh
    '
fi

echo "Debian package output:"
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "*.deb" -print | sort
