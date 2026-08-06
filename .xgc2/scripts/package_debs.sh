#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT=""
OUTPUT_DIR=""
ROS_DISTRO="${ROS_DISTRO:-melodic}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PACKAGE_VERSION="$(awk -F': *' '/^version:/ {print $2; exit}' "${REPO_ROOT}/.xgc2/product.yml")"
if [[ -z "${PACKAGE_VERSION}" ]]; then
  echo "missing product version in .xgc2/product.yml" >&2
  exit 1
fi

ros_package_xml() {
  local ros_pkg="$1"
  local package_xml
  package_xml="$(find "${REPO_ROOT}/onboard/ros1/src" \
    -type f \
    -path "*/${ros_pkg}/package.xml" \
    -print | sort | head -n 1)"
  if [[ -z "${package_xml}" ]]; then
    echo "missing package.xml for ${ros_pkg}" >&2
    exit 1
  fi
  printf '%s\n' "${package_xml}"
}

ros_package_version() {
  local ros_pkg="$1"
  sed -n 's:.*<version>\(.*\)</version>.*:\1:p' \
    "$(ros_package_xml "${ros_pkg}")" | head -n 1
}

deb_version() {
  local ros_pkg="$1"
  if [[ -z "$(ros_package_version "${ros_pkg}")" ]]; then
    echo "missing package.xml version for ${ros_pkg}" >&2
    exit 1
  fi
  printf '%s\n' "${PACKAGE_VERSION}"
}

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

ARCH="$(dpkg --print-architecture)"
PREFIX="/opt/ros/${ROS_DISTRO}"
PREFIX_ROOT="${INSTALL_ROOT}${PREFIX}"
BUILD_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_DIR}/ros-${ROS_DISTRO}-xgc2-agilex-"*.deb

copy_path() {
  local src="$1"
  local dst_root="$2"
  if [[ -e "${src}" ]]; then
    mkdir -p "${dst_root}$(dirname "${src#${INSTALL_ROOT}}")"
    cp -a "${src}" "${dst_root}${src#${INSTALL_ROOT}}"
  fi
}

copy_glob() {
  local dst_root="$1"
  shift
  local pattern
  local src
  shopt -s nullglob
  for pattern in "$@"; do
    for src in ${pattern}; do
      copy_path "${src}" "${dst_root}"
    done
  done
  shopt -u nullglob
}

copy_ros_package_paths() {
  local ros_pkg="$1"
  local pkg_root="$2"

  copy_path "${PREFIX_ROOT}/share/${ros_pkg}" "${pkg_root}"
  copy_path "${PREFIX_ROOT}/lib/${ros_pkg}" "${pkg_root}"
  copy_path "${PREFIX_ROOT}/include/${ros_pkg}" "${pkg_root}"
  copy_glob "${pkg_root}" "${PREFIX_ROOT}"/lib/python*/dist-packages/"${ros_pkg}"
  copy_path "${PREFIX_ROOT}/share/common-lisp/ros/${ros_pkg}" "${pkg_root}"
  copy_path "${PREFIX_ROOT}/share/gennodejs/ros/${ros_pkg}" "${pkg_root}"
  copy_path "${PREFIX_ROOT}/share/roseus/ros/${ros_pkg}" "${pkg_root}"
}

write_control() {
  local pkg_root="$1"
  local deb_pkg="$2"
  local version="$3"
  local depends="$4"
  local description="$5"

  mkdir -p "${pkg_root}/DEBIAN"
  cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${deb_pkg}
Version: ${version}
Section: misc
Priority: optional
Architecture: ${ARCH}
Maintainer: XGC2 <apt@example.com>
Depends: ${depends}
Description: ${description}
 XGC2 AgileX ROS ${ROS_DISTRO} package generated from the recovered onboard
 source tree and split by ROS package for independent installation.
EOF
}

write_readme() {
  local pkg_root="$1"
  local deb_pkg="$2"
  local ros_pkg="$3"
  local version="$4"

  mkdir -p "${pkg_root}/usr/share/doc/${deb_pkg}"
  cat > "${pkg_root}/usr/share/doc/${deb_pkg}/README" <<EOF
${deb_pkg}

ROS package:
  ${ros_pkg}

Version:
  ${version}

Install prefix:
  ${PREFIX}
EOF
}

build_deb() {
  local deb_pkg="$1"
  local ros_pkg="$2"
  local depends="$3"
  local description="$4"
  shift 4

  local pkg_root="${BUILD_DIR}/${deb_pkg}"
  local version
  version="$(deb_version "${ros_pkg}")"
  mkdir -p "${pkg_root}"

  copy_ros_package_paths "${ros_pkg}" "${pkg_root}"

  local extra
  for extra in "$@"; do
    copy_glob "${pkg_root}" "${PREFIX_ROOT}/${extra}"
  done

  if [[ ! -e "${pkg_root}${PREFIX}/share/${ros_pkg}/package.xml" ]]; then
    echo "missing installed package.xml for ${ros_pkg}" >&2
    exit 1
  fi

  write_control "${pkg_root}" "${deb_pkg}" "${version}" "${depends}" "${description}"
  write_readme "${pkg_root}" "${deb_pkg}" "${ros_pkg}" "${version}"

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control"
  chmod 0644 "${pkg_root}/usr/share/doc/${deb_pkg}/README"

  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${version}_${ARCH}.deb" >/dev/null
}

build_autostart_deb() {
  local deb_pkg="ros-${ROS_DISTRO}-xgc2-agilex-onboard-autostart"
  local ros_pkg="agilex_onboard_autostart"
  local version
  local pkg_root="${BUILD_DIR}/${deb_pkg}"
  version="$(deb_version "${ros_pkg}")"

  mkdir -p "${pkg_root}"
  copy_ros_package_paths "${ros_pkg}" "${pkg_root}"

  if [[ ! -e "${pkg_root}${PREFIX}/share/${ros_pkg}/package.xml" ]]; then
    echo "missing installed package.xml for ${ros_pkg}" >&2
    exit 1
  fi

  mkdir -p \
    "${pkg_root}/etc/udev/rules.d" \
    "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge" \
    "${pkg_root}/lib/systemd/system"

  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/udev/99-xgc2-agilex-imu.rules" \
    "${pkg_root}/etc/udev/rules.d/99-xgc2-agilex-imu.rules"
  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/config/ros_topics.yaml" \
    "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml"
  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/systemd/"* \
    "${pkg_root}/lib/systemd/system/"

  write_control \
    "${pkg_root}" \
    "${deb_pkg}" \
    "${version}" \
    "iproute2, systemd, udev, ros-${ROS_DISTRO}-rosgraph, ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-rospy, ros-${ROS_DISTRO}-xgc2-agilex-onboard-imu (>= $(deb_version agilex_onboard_imu)), ros-${ROS_DISTRO}-xgc2-agilex-scout-bringup (>= $(deb_version scout_bringup)), ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge (>= $(deb_version agilex_swarm_ros_bridge))" \
    "XGC2 AgileX onboard systemd autostart configuration"
  write_readme "${pkg_root}" "${deb_pkg}" "${ros_pkg}" "${version}"

  cat > "${pkg_root}/DEBIAN/conffiles" <<EOF
/etc/udev/rules.d/99-xgc2-agilex-imu.rules
/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml
EOF

  cat > "${pkg_root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = "configure" ]; then
  if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules >/dev/null 2>&1 || true
    udevadm trigger --subsystem-match=tty >/dev/null 2>&1 || true
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xgc2-agilex-onboard.target >/dev/null 2>&1 || true
  fi
fi

exit 0
EOF

  cat > "${pkg_root}/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable xgc2-agilex-onboard.target >/dev/null 2>&1 || true
  fi
fi

exit 0
EOF

  cat > "${pkg_root}/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload >/dev/null 2>&1 || true
fi

exit 0
EOF

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control" "${pkg_root}/DEBIAN/conffiles"
  chmod 0755 "${pkg_root}/DEBIAN/postinst" "${pkg_root}/DEBIAN/prerm" "${pkg_root}/DEBIAN/postrm"
  chmod 0644 "${pkg_root}/usr/share/doc/${deb_pkg}/README"
  find "${pkg_root}/lib/systemd/system" -type f -exec chmod 0644 {} +
  chmod 0644 "${pkg_root}/etc/udev/rules.d/99-xgc2-agilex-imu.rules"
  chmod 0644 "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml"

  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${version}_${ARCH}.deb" >/dev/null
}

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-imu" \
  "agilex_onboard_imu" \
  "ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-serial" \
  "XGC2 AgileX onboard serial IMU driver" \
  "lib/agilex_onboard_imu/agilex_onboard_imu_node"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io" \
  "wrp_io" \
  "ros-${ROS_DISTRO}-catkin" \
  "XGC2 AgileX Weston Robot Platform IO library" \
  "lib/libwrp_io.*" \
  "include/asio" \
  "include/asio.hpp"

wrp_io_dep="ros-${ROS_DISTRO}-xgc2-agilex-wrp-io (>= $(deb_version wrp_io))"
ugv_sdk_dep="ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk (>= $(deb_version ugv_sdk))"
scout_msgs_dep="ros-${ROS_DISTRO}-scout-msgs (>= 0.3.3-5)"
scout_description_dep="ros-${ROS_DISTRO}-xgc2-scout-description (>= 0.4.10-1)"
swarm_ros_bridge_dep="ros-${ROS_DISTRO}-swarm-ros-bridge (>= 1.1.0-3)"
scout_base_dep="ros-${ROS_DISTRO}-xgc2-agilex-scout-base (>= $(deb_version scout_base))"
realsense2_description_dep="ros-${ROS_DISTRO}-xgc2-agilex-realsense2-description (>= $(deb_version realsense2_description))"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk" \
  "ugv_sdk" \
  "ros-${ROS_DISTRO}-catkin, ${wrp_io_dep}" \
  "XGC2 AgileX UGV SDK" \
  "lib/libugv_sdk.*"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base" \
  "scout_base" \
  "ros-${ROS_DISTRO}-controller-manager, ros-${ROS_DISTRO}-geometry-msgs, ros-${ROS_DISTRO}-nav-msgs, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-tf, ros-${ROS_DISTRO}-tf2, ros-${ROS_DISTRO}-tf2-ros, ros-${ROS_DISTRO}-topic-tools, ${scout_msgs_dep}, ${ugv_sdk_dep}" \
  "XGC2 AgileX Scout base driver" \
  "lib/libscout_messenger.*"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-bringup" \
  "scout_bringup" \
  "ros-${ROS_DISTRO}-joint-state-publisher, ros-${ROS_DISTRO}-joint-state-publisher-gui, ros-${ROS_DISTRO}-robot-state-publisher, ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-rviz, ${scout_base_dep}, ${scout_description_dep}" \
  "XGC2 AgileX Scout bringup, display, and recovered navigation assets"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge" \
  "agilex_swarm_ros_bridge" \
  "ros-${ROS_DISTRO}-roslaunch, ${swarm_ros_bridge_dep}" \
  "XGC2 AgileX swarm bridge configuration"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-description" \
  "realsense2_description" \
  "ros-${ROS_DISTRO}-xacro" \
  "XGC2 AgileX RealSense description assets"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-realsense2-camera" \
  "realsense2_camera" \
  "librealsense2-dev, ros-${ROS_DISTRO}-cv-bridge, ros-${ROS_DISTRO}-ddynamic-reconfigure, ros-${ROS_DISTRO}-diagnostic-updater, ros-${ROS_DISTRO}-image-transport, ros-${ROS_DISTRO}-message-runtime, ros-${ROS_DISTRO}-nav-msgs, ros-${ROS_DISTRO}-nodelet, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-std-msgs, ros-${ROS_DISTRO}-std-srvs, ros-${ROS_DISTRO}-tf, ${realsense2_description_dep}" \
  "XGC2 AgileX RealSense camera driver"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk" \
  "rslidar_sdk" \
  "libpcap-dev, libpcl-dev, libyaml-cpp-dev, ros-${ROS_DISTRO}-pcl-conversions, ros-${ROS_DISTRO}-pcl-ros, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-roslib, ros-${ROS_DISTRO}-sensor-msgs" \
  "XGC2 AgileX RoboSense LiDAR SDK driver"

build_autostart_deb

find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "ros-${ROS_DISTRO}-xgc2-agilex-*.deb" -print | sort
