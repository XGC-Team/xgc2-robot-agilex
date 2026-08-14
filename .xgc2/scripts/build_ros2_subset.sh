#!/usr/bin/env bash
# Portable subset for ROS 2 / Jazzy: wrp_io, ugv_sdk, and scout_description.
# The vehicle C++ nodes are still ROS 1 and are not packaged here.
set -euo pipefail

SOURCE_ROOT=""
INSTALL_ROOT=""
OUTPUT_DIR=""
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
PACKAGE_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-root)
      SOURCE_ROOT="$2"
      shift 2
      ;;
    --install-root)
      INSTALL_ROOT="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${SOURCE_ROOT}" || -z "${INSTALL_ROOT}" || -z "${OUTPUT_DIR}" ]]; then
  echo "--source-root, --install-root, and --output-dir are required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PACKAGE_VERSION="$(awk -F': *' '/^version:/ {print $2; exit}' "${REPO_ROOT}/.xgc2/product.yml")"
ARCH="$(dpkg --print-architecture)"
PREFIX="/opt/ros/${ROS_DISTRO}"
DEST="${INSTALL_ROOT}${PREFIX}"
BUILD_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

rm -rf "${DEST}"
mkdir -p "${DEST}" "${OUTPUT_DIR}"

cmake -S "${SOURCE_ROOT}/chassis/wrp_io" -B "${BUILD_DIR}/wrp_io" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${BUILD_DIR}/wrp_io" -j"$(nproc)"
DESTDIR="${INSTALL_ROOT}" cmake --install "${BUILD_DIR}/wrp_io"

cmake -S "${SOURCE_ROOT}/chassis/ugv_sdk" -B "${BUILD_DIR}/ugv_sdk" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_PREFIX_PATH="${DEST}"
cmake --build "${BUILD_DIR}/ugv_sdk" -j"$(nproc)"
DESTDIR="${INSTALL_ROOT}" cmake --install "${BUILD_DIR}/ugv_sdk"

mkdir -p "${DEST}/share/scout_description"
cp -a "${SOURCE_ROOT}/chassis/scout_description/package.xml" \
  "${DEST}/share/scout_description/package.xml"
cp -a "${SOURCE_ROOT}/chassis/scout_description/urdf" \
  "${SOURCE_ROOT}/chassis/scout_description/meshes" \
  "${SOURCE_ROOT}/chassis/scout_description/launch" \
  "${DEST}/share/scout_description/"

package_tree() {
  local deb_pkg="$1"
  local depends="$2"
  local description="$3"
  shift 3
  local pkg_root="${BUILD_DIR}/${deb_pkg}"
  rm -rf "${pkg_root}"
  mkdir -p "${pkg_root}${PREFIX}" "${pkg_root}/DEBIAN"
  local path
  for path in "$@"; do
    if [[ -e "${DEST}/${path}" ]]; then
      mkdir -p "${pkg_root}${PREFIX}/$(dirname "${path}")"
      cp -a "${DEST}/${path}" "${pkg_root}${PREFIX}/${path}"
    fi
  done
  cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${deb_pkg}
Version: ${PACKAGE_VERSION}
Section: misc
Priority: optional
Architecture: ${ARCH}
Maintainer: XGC Team <apt@example.com>
Depends: ${depends}
Description: ${description}
 Portable AgileX subset for ROS ${ROS_DISTRO}.
EOF
  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control"
  fakeroot dpkg-deb --build "${pkg_root}" \
    "${OUTPUT_DIR}/${deb_pkg}_${PACKAGE_VERSION}_${ARCH}.deb" >/dev/null
}

package_tree \
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io" \
  "libc6" \
  "Weston Robot Platform IO library" \
  include/wrp_io include/asio include/asio.hpp lib/libwrp_io.so lib/cmake/wrp_io

package_tree \
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk" \
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io (>= ${PACKAGE_VERSION})" \
  "AgileX UGV SDK" \
  include/ugv_sdk lib/libugv_sdk.so lib/cmake/ugv_sdk

package_tree \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-description" \
  "ros-${ROS_DISTRO}-xacro" \
  "Scout visual/TF model assets" \
  share/scout_description
