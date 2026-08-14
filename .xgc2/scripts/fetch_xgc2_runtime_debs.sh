#!/usr/bin/env bash
# Download pinned sibling XGC2 product debs onto the CI host.
# The packaging container only dpkg -i these files. No apt-get inside the image.
set -euo pipefail

ros_distro="${ROS_DISTRO:?set ROS_DISTRO}"
arch="${XGC2_DEB_ARCH:-$(dpkg --print-architecture)}"
out_dir="${1:?output directory}"
base_url="${XGC2_SCOUT_MSGS_APT_BASE_URL:-https://xgc2.apt.xiaokang.ink}"

case "${ros_distro}" in
  melodic) distribution="bionic" ;;
  noetic) distribution="focal" ;;
  *)
    echo "unsupported ROS_DISTRO=${ros_distro}" >&2
    exit 1
    ;;
esac

mkdir -p "${out_dir}"

fetch() {
  local package="$1"
  local version="$2"
  local required="${3:-required}"
  local filename="${package}_${version}_${arch}.deb"
  local url="${base_url%/}/pool/${distribution}/main/r/${package}/${filename}"
  local dest="${out_dir}/${filename}"
  if [[ -f "${dest}" ]]; then
    return 0
  fi
  echo "fetch ${url}"
  if curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
    "${url}" -o "${dest}.partial"; then
    mv "${dest}.partial" "${dest}"
    return 0
  fi
  rm -f "${dest}.partial"
  if [[ "${required}" == "optional" ]]; then
    echo "optional ${package} ${version} is not published for ${distribution}/${arch}" >&2
    return 0
  fi
  echo "failed to fetch ${url}" >&2
  return 1
}

fetch "ros-${ros_distro}-scout-msgs" "0.3.3-10"
if [[ "${ros_distro}" == "melodic" ]]; then
  fetch "ros-${ros_distro}-xgc2-scout-description" "0.4.10-1"
  fetch "ros-${ros_distro}-swarm-ros-bridge" "1.1.0-9"
else
  fetch "ros-${ros_distro}-xgc2-scout-description" "0.4.10-14"
  fetch "ros-${ros_distro}-swarm-ros-bridge" "1.1.0-9" optional
fi

ls -l "${out_dir}"
