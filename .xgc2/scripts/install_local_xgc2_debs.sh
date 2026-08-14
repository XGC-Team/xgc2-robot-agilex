#!/usr/bin/env bash
# Install already-downloaded sibling XGC2 product debs with dpkg only.
# Never apt-get, never add apt sources. The build image provides ROS/toolchain.
set -euo pipefail

deb_dir="${XGC2_PRODUCT_DEB_DIR:-/workspace/deps}"
if [[ ! -d "${deb_dir}" ]]; then
  echo "XGC2_PRODUCT_DEB_DIR is not a directory: ${deb_dir}" >&2
  exit 1
fi

shopt -s nullglob
debs=("${deb_dir}"/*.deb)
shopt -u nullglob
if [[ "${#debs[@]}" -eq 0 ]]; then
  echo "no sibling product debs mounted at ${deb_dir}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
dpkg -i "${debs[@]}"
