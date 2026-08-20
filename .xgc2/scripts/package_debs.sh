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
  package_xml="$(find \
    "${REPO_ROOT}/onboard/ros1/chassis/src" \
    "${REPO_ROOT}/onboard/ros1/communication/src" \
    "${REPO_ROOT}/onboard/ros1/perception/src" \
    "${REPO_ROOT}/onboard/ros1/control/src" \
    "${REPO_ROOT}/onboard/ros1/autostart/src" \
    "${REPO_ROOT}/onboard/ros1/teleop/src" \
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
  local recommends="${6:-}"

  mkdir -p "${pkg_root}/DEBIAN"
  {
    cat <<EOF
Package: ${deb_pkg}
Version: ${version}
Section: misc
Priority: optional
Architecture: ${ARCH}
Maintainer: XGC Team <apt@example.com>
Depends: ${depends}
EOF
    if [[ -n "${recommends}" ]]; then
      printf 'Recommends: %s\n' "${recommends}"
    fi
    cat <<EOF
Description: ${description}
 XGC2 AgileX ROS ${ROS_DISTRO} package taken from the vehicle onboard tree.
EOF
  } > "${pkg_root}/DEBIAN/control"
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
    "${pkg_root}/etc/xgc2/agilex" \
    "${pkg_root}/etc/udev/rules.d" \
    "${pkg_root}/lib/systemd/system"

  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/config/onboard.env" \
    "${pkg_root}/etc/xgc2/agilex/onboard.env"
  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/systemd/"* \
    "${pkg_root}/lib/systemd/system/"
  if [[ -f "${PREFIX_ROOT}/share/${ros_pkg}/udev/99-xgc2-agilex-usb-recover.rules" ]]; then
    cp -a "${PREFIX_ROOT}/share/${ros_pkg}/udev/99-xgc2-agilex-usb-recover.rules" \
      "${pkg_root}/etc/udev/rules.d/99-xgc2-agilex-usb-recover.rules"
  fi
  sed -i \
    -e "s|/opt/ros/melodic|/opt/ros/${ROS_DISTRO}|g" \
    -e "s|ROS_DISTRO=melodic|ROS_DISTRO=${ROS_DISTRO}|g" \
    "${pkg_root}/lib/systemd/system/"* \
    "${pkg_root}/etc/xgc2/agilex/onboard.env"

  write_control \
    "${pkg_root}" \
    "${deb_pkg}" \
    "${version}" \
    "iproute2, udev, ros-${ROS_DISTRO}-rosgraph, ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-joint-state-publisher, ros-${ROS_DISTRO}-robot-state-publisher, ros-${ROS_DISTRO}-xgc2-scout-description, ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge (>= $(deb_version agilex_swarm_ros_bridge)), ros-${ROS_DISTRO}-xgc2-agilex-wrp-io (>= $(deb_version wrp_io)), ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk (>= $(deb_version ugv_sdk)), ros-${ROS_DISTRO}-xgc2-agilex-scout-base (>= $(deb_version scout_base))" \
    "Unified AgileX systemd manager (install-only; does not enable or start any unit)" \
    "ros-${ROS_DISTRO}-xgc2-agilex-serial-imu"
  write_readme "${pkg_root}" "${deb_pkg}" "${ros_pkg}" "${version}"

  cat > "${pkg_root}/DEBIAN/conffiles" <<EOF
/etc/xgc2/agilex/onboard.env
EOF

  cat > "${pkg_root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = "configure" ]; then
  if id agilex >/dev/null 2>&1; then
    usermod -aG dialout agilex >/dev/null 2>&1 || true
  fi

  AGILEX_USER=agilex
  if ! id agilex >/dev/null 2>&1; then
    AGILEX_USER=
  fi
  export AGILEX_USER
  if [ -x /opt/ros/ROS_DISTRO_PLACEHOLDER/lib/agilex_onboard_autostart/apply-host-defaults ]; then
    AGILEX_USER="${AGILEX_USER}" /opt/ros/ROS_DISTRO_PLACEHOLDER/lib/agilex_onboard_autostart/apply-host-defaults >/dev/null 2>&1 || true
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    # Keep old unit files on disk. Experiment-time units stay disabled so
    # they cannot race Agent process.run-definition. Chassis is operator-owned.
    systemctl disable swarm_ros_bridge.service >/dev/null 2>&1 || true
    systemctl disable handsfree_imu.service >/dev/null 2>&1 || true
    systemctl disable turn_on_wheeltec_robot.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-onboard.target >/dev/null 2>&1 || true
    systemctl disable xgc2-roscore.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-boot-settle.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-can0.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-base.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-swarm-ros-bridge.service >/dev/null 2>&1 || true
    # Chassis and standalone roscore are operator-owned. Do not disable on upgrade.
    if command -v udevadm >/dev/null 2>&1; then
      udevadm control --reload-rules >/dev/null 2>&1 || true
      udevadm trigger --subsystem-match=net --action=add >/dev/null 2>&1 || true
    fi
    systemctl disable xgc2-agilex-imu.service >/dev/null 2>&1 || true
    # HI226 is operator-owned on vehicles that have the accessory (same as
    # chassis). Do not disable on upgrade; a later apt must not wipe enable.
    systemctl disable xgc2-agilex-communication.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-swarm-ros-bridge.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-camera.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-lidar.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-lidar-helios16.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-mocap.service >/dev/null 2>&1 || true
  fi
fi

exit 0
EOF

  cat > "${pkg_root}/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable xgc2-agilex-chassis.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-roscore.service >/dev/null 2>&1 || true
    systemctl disable xgc2-field-panel.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-onboard-teleop.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-imu.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-imu-hi226.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-base.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-communication.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-swarm-ros-bridge.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-camera.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-lidar.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-lidar-helios16.service >/dev/null 2>&1 || true
    systemctl disable xgc2-agilex-mocap.service >/dev/null 2>&1 || true
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
  sed -i -e "s|ROS_DISTRO_PLACEHOLDER|${ROS_DISTRO}|g" \
    "${pkg_root}/DEBIAN/postinst"
  chmod 0755 "${pkg_root}/DEBIAN/postinst" "${pkg_root}/DEBIAN/prerm" "${pkg_root}/DEBIAN/postrm"
  chmod 0644 "${pkg_root}/usr/share/doc/${deb_pkg}/README"
  find "${pkg_root}/lib/systemd/system" -type f -exec chmod 0644 {} +
  if [[ -f "${pkg_root}/etc/udev/rules.d/99-xgc2-agilex-usb-recover.rules" ]]; then
    chmod 0644 "${pkg_root}/etc/udev/rules.d/99-xgc2-agilex-usb-recover.rules"
  fi
  chmod 0644 "${pkg_root}/etc/xgc2/agilex/onboard.env"

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
    "XGC2 AgileX vehicle min-boot meta package (chassis + bridge; no IMU/camera/LiDAR/estimator/NMPC/teleop)" \
    "ros-${ROS_DISTRO}-xgc2-agilex-serial-imu, ros-${ROS_DISTRO}-xgc2-agilex-rslidar-sdk, ros-${ROS_DISTRO}-xgc2-agilex-onboard-rviz"

  cat > "${pkg_root}/usr/share/doc/${deb_pkg}/README" <<EOF
${deb_pkg}

Install this meta package on the vehicle. Autostart owns the units.
No unit is enabled or started. Enable only the chassis at boot.
Mocap, IMU, camera, lidar, and the swarm bridge stay install-only.

  sudo apt-get install ${deb_pkg}
  sudo systemctl enable xgc2-agilex-chassis.service
  # sudo apt-get install ros-${ROS_DISTRO}-xgc2-agilex-serial-imu
EOF

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control"
  chmod 0644 "${pkg_root}/usr/share/doc/${deb_pkg}/README"

  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${version}_${ARCH}.deb" >/dev/null
}

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

scout_msgs_dep="ros-${ROS_DISTRO}-scout-msgs (>= 0.3.3-11)"
ugv_sdk_dep="ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk (>= $(deb_version ugv_sdk))"

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-scout-base" \
  "scout_base" \
  "ros-${ROS_DISTRO}-geometry-msgs, ros-${ROS_DISTRO}-nav-msgs, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-tf, ros-${ROS_DISTRO}-tf2, ros-${ROS_DISTRO}-tf2-ros, ros-${ROS_DISTRO}-topic-tools, ${scout_msgs_dep}, ${ugv_sdk_dep}" \
  "Scout Mini chassis driver from the vehicle tree" \
  "lib/libscout_messenger.*"

build_communication_deb() {
  local deb_pkg="ros-${ROS_DISTRO}-xgc2-agilex-swarm-ros-bridge"
  local ros_pkg="agilex_swarm_ros_bridge"
  local version
  local pkg_root="${BUILD_DIR}/${deb_pkg}"
  version="$(deb_version "${ros_pkg}")"

  mkdir -p "${pkg_root}"
  copy_ros_package_paths "${ros_pkg}" "${pkg_root}"

  if [[ ! -e "${pkg_root}${PREFIX}/share/${ros_pkg}/package.xml" ]]; then
    echo "missing installed package.xml for ${ros_pkg}" >&2
    exit 1
  fi
  if [[ ! -e "${PREFIX_ROOT}/share/${ros_pkg}/config/ros_topics.yaml" ]]; then
    echo "missing vehicle swarm YAML from ${ros_pkg}" >&2
    exit 1
  fi

  mkdir -p "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge"
  cp -a "${PREFIX_ROOT}/share/${ros_pkg}/config/ros_topics.yaml" \
    "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml"

  # Official swarm-ros-bridge is published for Melodic only. Noetic CI must
  # still configure this YAML/launch package; the vehicle pulls the official
  # bridge from APT when that distro is published.
  local comm_depends="ros-${ROS_DISTRO}-geometry-msgs, ros-${ROS_DISTRO}-roscpp, ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-std-msgs, ${scout_msgs_dep}"
  if [[ "${ROS_DISTRO}" == "melodic" ]]; then
    comm_depends="${comm_depends}, ros-${ROS_DISTRO}-swarm-ros-bridge"
  fi

  write_control \
    "${pkg_root}" \
    "${deb_pkg}" \
    "${version}" \
    "${comm_depends}" \
    "Vehicle YAML, launch, and ScoutStatus relay for the official swarm_ros_bridge"
  write_readme "${pkg_root}" "${deb_pkg}" "${ros_pkg}" "${version}"

  cat > "${pkg_root}/DEBIAN/conffiles" <<EOF
/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml
EOF

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control" "${pkg_root}/DEBIAN/conffiles"
  chmod 0644 "${pkg_root}/usr/share/doc/${deb_pkg}/README"
  chmod 0644 "${pkg_root}/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml"

  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${version}_${ARCH}.deb" >/dev/null
}

build_chassis_deb() {
  local deb_pkg="ros-${ROS_DISTRO}-xgc2-agilex-chassis"
  local version="${PACKAGE_VERSION}"
  local pkg_root="${BUILD_DIR}/${deb_pkg}"

  mkdir -p "${pkg_root}/usr/share/doc/${deb_pkg}"
  write_control \
    "${pkg_root}" \
    "${deb_pkg}" \
    "${version}" \
    "ros-${ROS_DISTRO}-xgc2-agilex-wrp-io (>= $(deb_version wrp_io)), ros-${ROS_DISTRO}-xgc2-agilex-ugv-sdk (>= $(deb_version ugv_sdk)), ros-${ROS_DISTRO}-xgc2-agilex-scout-base (>= $(deb_version scout_base)), ros-${ROS_DISTRO}-xgc2-scout-description" \
    "XGC2 AgileX chassis-only meta (no IMU, camera, or LiDAR)"

  cat > "${pkg_root}/usr/share/doc/${deb_pkg}/README" <<EOF
${deb_pkg}

Chassis stack. Does not pull serial_imu. Autostart stays install-only.

  sudo apt-get install ${deb_pkg}
  sudo apt-get install ros-${ROS_DISTRO}-xgc2-agilex-onboard-autostart
  # sudo systemctl enable xgc2-agilex-chassis.service
EOF

  find "${pkg_root}" -type d -exec chmod 0755 {} +
  chmod 0755 "${pkg_root}/DEBIAN"
  chmod 0644 "${pkg_root}/DEBIAN/control"
  chmod 0644 "${pkg_root}/usr/share/doc/${deb_pkg}/README"

  fakeroot dpkg-deb --build "${pkg_root}" "${OUTPUT_DIR}/${deb_pkg}_${version}_${ARCH}.deb" >/dev/null
}

build_communication_deb
build_autostart_deb
build_chassis_deb
build_meta_deb

build_deb \
  "ros-${ROS_DISTRO}-xgc2-agilex-onboard-teleop" \
  "xgc2_onboard_teleop" \
  "ros-${ROS_DISTRO}-geometry-msgs, ros-${ROS_DISTRO}-roslaunch, ros-${ROS_DISTRO}-rospy, ros-${ROS_DISTRO}-sensor-msgs, ros-${ROS_DISTRO}-std-msgs" \
  "Optional onboard camera viewer and dual-page teleop (not field-panel)"

find "${OUTPUT_DIR}" -maxdepth 1 -type f -name "ros-${ROS_DISTRO}-xgc2-agilex*.deb" -print | sort
