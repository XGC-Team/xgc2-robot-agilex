#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT=""
OUTPUT_DIR=""
ROS_DISTRO="${ROS_DISTRO:-melodic}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PACKAGE_VERSION="$(awk -F': *' '/^version:/ {print $2; exit}' "${REPO_ROOT}/.xgc2/product.yml")"

ros_package_xml() {
  local ros_pkg="$1"
  local package_xml
  package_xml="$(find \
    "${REPO_ROOT}/onboard/ros1/sensors/src" \
    "${REPO_ROOT}/onboard/ros1/visualization/src" \
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
  "${OUTPUT_DIR}/ros-${ROS_DISTRO}-xgc2-agilex-onboard-rviz_"*.deb \
  "${OUTPUT_DIR}/ros-${ROS_DISTRO}-xgc2-agilex-serial-imu_"*.deb

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

if [[ ! -x "${PREFIX_ROOT}/lib/serial_imu/serial_imu" ]]; then
  echo "missing installed serial_imu binary" >&2
  exit 1
fi
if [[ ! -x "${PREFIX_ROOT}/lib/rslidar_sdk/rslidar_sdk_node" ]]; then
  echo "missing installed rslidar_sdk_node" >&2
  exit 1
fi

if [[ -x "${PREFIX_ROOT}/lib/serial_imu/serial_imu" ]]; then
  imu_pkg="ros-${ROS_DISTRO}-xgc2-agilex-serial-imu"
  imu_root="${BUILD_DIR}/${imu_pkg}"
  mkdir -p "${imu_root}/etc/udev/rules.d"
  copy_path "${PREFIX_ROOT}/share/serial_imu" "${imu_root}"
  copy_path "${PREFIX_ROOT}/lib/serial_imu" "${imu_root}"
  if [[ -f "${PREFIX_ROOT}/share/serial_imu/udev/99-xgc2-agilex-imu.rules" ]]; then
    cp -a "${PREFIX_ROOT}/share/serial_imu/udev/99-xgc2-agilex-imu.rules" \
      "${imu_root}/etc/udev/rules.d/99-xgc2-agilex-imu.rules"
  fi
  write_control \
    "${imu_root}" \
    "${imu_pkg}" \
    "${PACKAGE_VERSION}" \
    "ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-serial, ros-${ROS_DISTRO}-std-msgs, udev" \
    "Optional AgileX serial IMU driver (/dev/imu)"
  mkdir -p "${imu_root}/usr/share/doc/${imu_pkg}"
  echo "${imu_pkg} serial_imu ${PACKAGE_VERSION}" > "${imu_root}/usr/share/doc/${imu_pkg}/README"
  cat > "${imu_root}/DEBIAN/conffiles" <<EOF
/etc/udev/rules.d/99-xgc2-agilex-imu.rules
EOF
  cat > "${imu_root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules >/dev/null 2>&1 || true
    udevadm trigger --subsystem-match=tty >/dev/null 2>&1 || true
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-imu.service >/dev/null 2>&1 || true
    # Do not disable xgc2-agilex-imu-hi226: operator-owned on HI226 hosts.
  fi
fi
exit 0
EOF
  cat > "${imu_root}/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable xgc2-agilex-imu.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-imu-hi226.service >/dev/null 2>&1 || true
  fi
fi
exit 0
EOF
  find "${imu_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${imu_root}/DEBIAN"
  chmod 0644 "${imu_root}/DEBIAN/control" "${imu_root}/DEBIAN/conffiles"
  chmod 0755 "${imu_root}/DEBIAN/postinst" "${imu_root}/DEBIAN/prerm"
  chmod 0644 "${imu_root}/etc/udev/rules.d/99-xgc2-agilex-imu.rules"
  fakeroot dpkg-deb --build "${imu_root}" "${OUTPUT_DIR}/${imu_pkg}_${PACKAGE_VERSION}_${ARCH}.deb" >/dev/null
fi

if [[ -x "${PREFIX_ROOT}/lib/rslidar_sdk/rslidar_sdk_node" ]]; then
  build_deb \
    "ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk" \
    "rslidar_sdk" \
    "libpcap0.8, libyaml-cpp0.5v5 | libyaml-cpp0.6, ros-${ROS_DISTRO}-pcl-conversions, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs" \
    "RoboSense Helios 16 driver from the vehicle tree" \
    "lib/rslidar_sdk/rslidar_sdk_node"
fi

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-rviz" \
  "agilex_onboard_rviz" \
  "ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-rviz" \
  "AgileX onboard RViz config"

find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "ros-${ROS_DISTRO}-xgc2-agilex-*.deb" -print | sort
