#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT=""
OUTPUT_DIR=""
ROS_DISTRO="${ROS_DISTRO:-melodic}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PACKAGE="ros-${ROS_DISTRO}-xgc2-agilex-onboard-imu"
ROS_PACKAGE="agilex_onboard_imu"
COMPAT_ROS_PACKAGE="imu_launch"
NODE="agilex_onboard_imu_node"

product_version() {
  awk -F': *' '/^version:/ {print $2; exit}' "${REPO_ROOT}/.xgc2/product.yml"
}

VERSION="${PACKAGE_VERSION:-$(product_version)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -z "${INSTALL_ROOT}" || -z "${OUTPUT_DIR}" ]]; then
  echo "--install-root and --output-dir are required" >&2
  exit 1
fi

if [[ -z "${VERSION}" ]]; then
  echo "package version is missing" >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
PREFIX="/opt/ros/${ROS_DISTRO}"
PREFIX_ROOT="${INSTALL_ROOT}${PREFIX}"
BUILD_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_DIR}/${PACKAGE}_"*.deb

copy_path() {
  local src="$1"
  local dst_root="$2"
  if [[ -e "${src}" ]]; then
    mkdir -p "${dst_root}$(dirname "${src#${INSTALL_ROOT}}")"
    cp -a "${src}" "${dst_root}${src#${INSTALL_ROOT}}"
  fi
}

pkg_root="${BUILD_DIR}/${PACKAGE}"
mkdir -p "${pkg_root}"

copy_path "${PREFIX_ROOT}/share/${ROS_PACKAGE}" "${pkg_root}"
copy_path "${PREFIX_ROOT}/share/${COMPAT_ROS_PACKAGE}" "${pkg_root}"
copy_path "${PREFIX_ROOT}/lib/${ROS_PACKAGE}" "${pkg_root}"

if [[ ! -x "${pkg_root}${PREFIX}/lib/${ROS_PACKAGE}/${NODE}" ]]; then
  echo "missing installed ${NODE} executable" >&2
  exit 1
fi

mkdir -p "${pkg_root}/DEBIAN" "${pkg_root}/usr/share/doc/${PACKAGE}"
cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${PACKAGE}
Version: ${VERSION}
Section: misc
Priority: optional
Architecture: ${ARCH}
Maintainer: XGC2 <apt@example.com>
Depends: ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-serial
Description: XGC2 AgileX onboard serial IMU driver
 ROS ${ROS_DISTRO} package for the AgileX onboard serial IMU. It preserves the
 recovered vehicle runtime surface by publishing sensor_msgs/Imu on /imu/data_raw
 from /dev/imu at 115200 baud by default.
EOF

cat > "${pkg_root}/usr/share/doc/${PACKAGE}/README" <<EOF
XGC2 AgileX Onboard IMU

ROS package:
  ${ROS_PACKAGE}

Default launch:
  roslaunch ${ROS_PACKAGE} imu_msg.launch

Default runtime:
  port=/dev/imu
  baud=115200
  topic=/imu/data_raw
  frame_id=imu_link
EOF

find "${pkg_root}" -type d -exec chmod 0755 {} +
find "${pkg_root}" -type f -exec chmod 0644 {} +
chmod 0755 "${pkg_root}/DEBIAN"
chmod 0755 "${pkg_root}${PREFIX}/lib/${ROS_PACKAGE}/${NODE}"

fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${PACKAGE}_${VERSION}_${ARCH}.deb" >/dev/null
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "${PACKAGE}_*.deb" -print | sort
