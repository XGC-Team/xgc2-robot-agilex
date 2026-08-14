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
Maintainer: XGC Team <apt@example.com>
Depends: ${depends}
Description: ${description}
 XGC2 AgileX ROS ${ROS_DISTRO} package taken from the vehicle onboard tree.
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
    "${pkg_root}/etc/xgc2/agilex" \
    "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge" \
    "${pkg_root}/lib/systemd/system"

  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/udev/99-xgc2-agilex-imu.rules" \
    "${pkg_root}/etc/udev/rules.d/99-xgc2-agilex-imu.rules"
  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/config/ros_topics.yaml" \
    "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml"
  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/config/onboard.env" \
    "${pkg_root}/etc/xgc2/agilex/onboard.env"
  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/systemd/"* \
    "${pkg_root}/lib/systemd/system/"
  sed -i \
    -e "s|/opt/ros/melodic|/opt/ros/${ROS_DISTRO}|g" \
    -e "s|ROS_DISTRO=melodic|ROS_DISTRO=${ROS_DISTRO}|g" \
    "${pkg_root}/lib/systemd/system/"* \
    "${pkg_root}/etc/xgc2/agilex/onboard.env"

  write_control \
    "${pkg_root}" \
    "${deb_pkg}" \
    "${version}" \
    "iproute2, systemd, udev, ros-${ROS_DISTRO}-rosgraph, ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-rospy, ros-${ROS_DISTRO}-joint-state-publisher, ros-${ROS_DISTRO}-robot-state-publisher, ros-${ROS_DISTRO}-xacro, ros-${ROS_DISTRO}-xgc2-agilex-serial-imu (>= $(deb_version serial_imu)), ros-${ROS_DISTRO}-xgc2-agilex-wrp-io (>= $(deb_version wrp_io)), ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk (>= $(deb_version ugv_sdk)), ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs (>= $(deb_version scout_msgs)), ros-${ROS_DISTRO}-xgc2-agilex-scout-base (>= $(deb_version scout_base)), ros-${ROS_DISTRO}-xgc2-agilex-scout-description (>= $(deb_version scout_description)), ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge (>= $(deb_version swarm_ros_bridge))" \
    "XGC2 AgileX onboard min-boot systemd (IMU, chassis, TF, bridge; no camera/LiDAR)"
  write_readme "${pkg_root}" "${deb_pkg}" "${ros_pkg}" "${version}"

  cat > "${pkg_root}/DEBIAN/conffiles" <<EOF
/etc/udev/rules.d/99-xgc2-agilex-imu.rules
/etc/xgc2/agilex/onboard.env
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

  if id agilex >/dev/null 2>&1; then
    usermod -aG dialout agilex >/dev/null 2>&1 || true
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    # Keep old unit files on disk; only stop them from racing the new target.
    systemctl disable swarm_ros_bridge.service >/dev/null 2>&1 || true
    systemctl disable handsfree_imu.service >/dev/null 2>&1 || true
    systemctl disable turn_on_wheeltec_robot.service >/dev/null 2>&1 || true
    if id agilex >/dev/null 2>&1; then
      systemctl enable xgc2-agilex-onboard.target >/dev/null 2>&1 || true
    fi
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
  chmod 0644 "${pkg_root}/etc/xgc2/agilex/onboard.env"
  chmod 0644 "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml"

  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${version}_${ARCH}.deb" >/dev/null
}

build_meta_deb() {
  local deb_pkg="ros-${ROS_DISTRO}-xgc2-agilex"
  local version="${PACKAGE_VERSION}"
  local pkg_root="${BUILD_DIR}/${deb_pkg}"

  mkdir -p "${pkg_root}/usr/share/doc/${deb_pkg}"
  write_control \
    "${pkg_root}" \
    "${deb_pkg}" \
    "${version}" \
    "ros-${ROS_DISTRO}-xgc2-agilex-onboard-autostart (>= ${version})" \
    "XGC2 AgileX vehicle min-boot meta package (no camera/LiDAR)"

  cat > "${pkg_root}/usr/share/doc/${deb_pkg}/README" <<EOF
${deb_pkg}

Install this meta package on the vehicle. It pulls the onboard autostart
unit plus IMU, chassis, TF/model, and the ground-station bridge, and the
autostart postinst enables xgc2-agilex-onboard.target.

Camera and LiDAR are a separate product and are not started at boot.

  sudo apt-get install ${deb_pkg}
  sudo reboot
EOF

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control"
  chmod 0644 "${pkg_root}/usr/share/doc/${deb_pkg}/README"

  # Meta package is arch-independent.
  sed -i "s/^Architecture: ${ARCH}$/Architecture: all/" "${pkg_root}/DEBIAN/control"
  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${version}_all.deb" >/dev/null
}

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-serial-imu" \
  "serial_imu" \
  "ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-serial, ros-${ROS_DISTRO}-std-msgs" \
  "AgileX onboard serial IMU driver from the vehicle tree" \
  "lib/serial_imu/serial_imu" \
  "lib/serial_imu/imu_subscriber"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io" \
  "wrp_io" \
  "ros-${ROS_DISTRO}-catkin" \
  "Weston Robot Platform IO library from the vehicle tree" \
  "lib/libwrp_io.*" \
  "include/asio" \
  "include/asio.hpp"

wrp_io_dep="ros-${ROS_DISTRO}-xgc2-agilex-wrp-io (>= $(deb_version wrp_io))"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk" \
  "ugv_sdk" \
  "ros-${ROS_DISTRO}-catkin, ${wrp_io_dep}" \
  "AgileX UGV SDK from the vehicle tree" \
  "lib/libugv_sdk.*"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs" \
  "scout_msgs" \
  "ros-${ROS_DISTRO}-message-runtime, ros-${ROS_DISTRO}-std-msgs" \
  "Scout status and light message definitions from the vehicle tree"

scout_msgs_dep="ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs (>= $(deb_version scout_msgs))"
ugv_sdk_dep="ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk (>= $(deb_version ugv_sdk))"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base" \
  "scout_base" \
  "ros-${ROS_DISTRO}-geometry-msgs, ros-${ROS_DISTRO}-nav-msgs, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-tf, ros-${ROS_DISTRO}-tf2, ros-${ROS_DISTRO}-tf2-ros, ros-${ROS_DISTRO}-topic-tools, ${scout_msgs_dep}, ${ugv_sdk_dep}" \
  "Scout Mini chassis driver from the vehicle tree" \
  "lib/libscout_messenger.*"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-description" \
  "scout_description" \
  "ros-${ROS_DISTRO}-urdf, ros-${ROS_DISTRO}-xacro" \
  "Scout visual/TF model used by the vehicle scout_minimal launch"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge" \
  "swarm_ros_bridge" \
  "libzmqpp-dev, ros-${ROS_DISTRO}-geometry-msgs, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-std-msgs, ros-${ROS_DISTRO}-xgc2-agilex-scout-msgs (>= $(deb_version scout_msgs))" \
  "Vehicle swarm_ros_bridge binary and topic YAML" \
  "lib/swarm_ros_bridge/bridge_node"

build_autostart_deb
build_meta_deb

find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "ros-${ROS_DISTRO}-xgc2-agilex*.deb" -print | sort
