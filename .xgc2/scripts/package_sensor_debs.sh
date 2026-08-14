#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT=""
OUTPUT_DIR=""
ROS_DISTRO="${ROS_DISTRO:-melodic}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PACKAGE_VERSION="$(awk -F': *' '/^version:/ {print $2; exit}' "${REPO_ROOT}/.xgc2/sensors.yml")"

ros_package_xml() {
  local ros_pkg="$1"
  local package_xml
  package_xml="$(find "${REPO_ROOT}/onboard/ros1/sensors/src" \
    -type f -path "*/${ros_pkg}/package.xml" -print | sort | head -n 1)"
  if [[ -z "${package_xml}" ]]; then
    echo "missing package.xml for ${ros_pkg}" >&2
    exit 1
  fi
  printf '%s\n' "${package_xml}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${INSTALL_ROOT}" || -z "${OUTPUT_DIR}" ]]; then
  echo "--install-root and --output-dir are required" >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
PREFIX="/opt/ros/${ROS_DISTRO}"
PREFIX_ROOT="${INSTALL_ROOT}${PREFIX}"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${BUILD_DIR}"' EXIT
mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_DIR}/ros-${ROS_DISTRO}-xgc2-agilex-realsense2-"*.deb \
  "${OUTPUT_DIR}/ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk_"*.deb \
  "${OUTPUT_DIR}/ros-${ROS_DISTRO}-xgc2-agilex-onboard-sensors_"*.deb

copy_path() {
  local src="$1" dst_root="$2"
  if [[ -e "${src}" ]]; then
    mkdir -p "${dst_root}$(dirname "${src#${INSTALL_ROOT}}")"
    cp -a "${src}" "${dst_root}${src#${INSTALL_ROOT}}"
  fi
}

write_control() {
  mkdir -p "${1}/DEBIAN"
  cat > "${1}/DEBIAN/control" <<EOF
Package: ${2}
Version: ${3}
Section: misc
Priority: optional
Architecture: ${ARCH}
Maintainer: XGC Team <apt@example.com>
Depends: ${4}
Description: ${5}
 Optional AgileX onboard sensor package. Not started by xgc2-agilex-onboard.target.
EOF
}

build_deb() {
  local deb_pkg="$1" ros_pkg="$2" depends="$3" description="$4"
  shift 4
  local pkg_root="${BUILD_DIR}/${deb_pkg}"
  mkdir -p "${pkg_root}"
  copy_path "${PREFIX_ROOT}/share/${ros_pkg}" "${pkg_root}"
  copy_path "${PREFIX_ROOT}/lib/${ros_pkg}" "${pkg_root}"
  copy_path "${PREFIX_ROOT}/include/${ros_pkg}" "${pkg_root}"
  copy_path "${PREFIX_ROOT}/lib/lib${ros_pkg}.so" "${pkg_root}"
  local extra
  for extra in "$@"; do
    copy_path "${PREFIX_ROOT}/${extra}" "${pkg_root}"
  done
  write_control "${pkg_root}" "${deb_pkg}" "${PACKAGE_VERSION}" "${depends}" "${description}"
  mkdir -p "${pkg_root}/usr/share/doc/${deb_pkg}"
  echo "${deb_pkg} ${ros_pkg} ${PACKAGE_VERSION}" > "${pkg_root}/usr/share/doc/${deb_pkg}/README"
  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control"
  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${PACKAGE_VERSION}_${ARCH}.deb" >/dev/null
}

if [[ -d "${PREFIX_ROOT}/share/realsense2_camera" ]]; then
  build_deb \
    "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-camera" \
    "realsense2_camera" \
    "ros-${ROS_DISTRO}-cv-bridge, ros-${ROS_DISTRO}-ddynamic-reconfigure, ros-${ROS_DISTRO}-image-transport, ros-${ROS_DISTRO}-nodelet, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-tf" \
    "Vehicle-true RealSense D435i ROS wrapper" \
    "lib/librealsense2_camera.so"
fi

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-description" \
  "realsense2_description" \
  "ros-${ROS_DISTRO}-xacro" \
  "RealSense URDF/meshes from the vehicle tree"

if [[ -x "${PREFIX_ROOT}/lib/rslidar_sdk/rslidar_sdk_node" ]]; then
  build_deb \
    "ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk" \
    "rslidar_sdk" \
    "libpcap0.8, libyaml-cpp0.5v5 | libyaml-cpp0.6, ros-${ROS_DISTRO}-pcl-conversions, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs" \
    "RoboSense Helios 16 driver from the vehicle tree" \
    "lib/rslidar_sdk/rslidar_sdk_node"
fi

camera_dep=""
if [[ -d "${PREFIX_ROOT}/share/realsense2_camera" ]]; then
  camera_dep=", ros-${ROS_DISTRO}-xgc2-agilex-realsense2-camera (>= ${PACKAGE_VERSION})"
fi
lidar_dep=""
if [[ -x "${PREFIX_ROOT}/lib/rslidar_sdk/rslidar_sdk_node" ]]; then
  lidar_dep=", ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk (>= ${PACKAGE_VERSION})"
fi

if [[ -d "${PREFIX_ROOT}/share/agilex_d435_media" ]]; then
  d435_depends="ros-${ROS_DISTRO}-image-transport, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs"
  build_deb \
    "ros-${ROS_DISTRO}-xgc2-agilex-d435-media" \
    "agilex_d435_media" \
    "${d435_depends}" \
    "D435 capture owner for ROS images and Media Edge H264/RTP" \
    "lib/agilex_d435_media/d435_parallel_source"
fi

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-sensors" \
  "agilex_onboard_sensors" \
  "ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-rviz, ros-${ROS_DISTRO}-xgc2-agilex-realsense2-description (>= ${PACKAGE_VERSION})${camera_dep}${lidar_dep}" \
  "Compose launches and RViz for D435i + Helios 16"

find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "ros-${ROS_DISTRO}-xgc2-agilex-*.deb" -print | sort
