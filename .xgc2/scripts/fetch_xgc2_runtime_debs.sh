#!/usr/bin/env bash
# Download pinned sibling XGC2 product debs onto the CI host.
# The packaging container only dpkg -i these files. No apt-get inside the image.
set -euo pipefail

ros_distro="${ROS_DISTRO:?set ROS_DISTRO}"
arch="${XGC2_DEB_ARCH:-$(dpkg --print-architecture)}"
out_dir="${1:?output directory}"
base_url="${XGC2_APT_OVERLAY_URL:-${XGC2_SCOUT_MSGS_APT_BASE_URL:-https://xgc2.apt.xiaokang.ink}}"
[[ "${base_url}" == https://* && "${base_url}" != *[[:space:]]* ]]

case "${ros_distro}" in
  melodic) distribution="bionic" ;;
  noetic) distribution="focal" ;;
  *)
    echo "unsupported ROS_DISTRO=${ros_distro}" >&2
    exit 1
    ;;
esac

mkdir -p "${out_dir}"

# Resolve exact package identities from a signed, isolated APT view. Pool
# prefixes and Architecture: all filenames belong to the repository index.
apt_state="$(mktemp -d)"
trap 'rm -rf "${apt_state}"' EXIT
mkdir -p "${apt_state}/lists/partial" "${apt_state}/cache/archives/partial" "${apt_state}/empty"
touch "${apt_state}/status" "${apt_state}/empty.conf"
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
  https://xgc2.apt.xiaokang.ink/xgc2-archive-keyring.gpg -o "${apt_state}/keyring.gpg"
printf '%s  %s\n' 8dfe063f8ac11b6d2b224a86abb4f7fa3da2e3ccc95a27d57279313f532c8510 \
  "${apt_state}/keyring.gpg" | sha256sum --check --status
printf 'deb [arch=%s signed-by=%s/keyring.gpg] %s %s main\n' \
  "${arch}" "${apt_state}" "${base_url%/}" "${distribution}" > "${apt_state}/sources.list"
cat > "${apt_state}/apt.conf" <<EOF
Dir::Etc::sourcelist "${apt_state}/sources.list";
Dir::Etc::sourceparts "${apt_state}/empty";
Dir::Etc::parts "${apt_state}/empty";
Dir::Etc::main "${apt_state}/empty.conf";
Dir::State "${apt_state}";
Dir::State::lists "${apt_state}/lists";
Dir::State::status "${apt_state}/status";
Dir::Cache "${apt_state}/cache";
APT::Architecture "${arch}";
APT::Architectures { "${arch}"; };
APT::Sandbox::User "$(id -un)";
Acquire::Languages "none";
EOF
APT_CONFIG="${apt_state}/apt.conf" apt-get -o APT::Update::Error-Mode=any update

fetch() {
  # APT uses the authenticated Filename/SHA256, including Architecture: all,
  # and verifies package bytes rather than trusting an existing cache file.
  (cd "${out_dir}" && APT_CONFIG="${apt_state}/apt.conf" apt-get download "${1}:${arch}=${2}")
}

# Native HOLD link dependencies, including their SDK inputs, are installed
# from the same distribution as the driver. No cross-distribution fallback.
fetch "libxgc2-chassis-hold0" "0.1.0-1~${distribution}"
fetch "libxgc2-chassis-hold-dev" "0.1.0-1~${distribution}"
fetch "libxgc2-xrpc1" "0.1.0-2~${distribution}"
fetch "libxgc2-xrpc-dev" "0.1.0-2~${distribution}"
fetch "libxgc2-state-machine-dev" "0.1.3-12~${distribution}"
fetch "ros-${ros_distro}-scout-msgs" "0.3.3-11"
if [[ "${ros_distro}" == "melodic" ]]; then
  fetch "ros-${ros_distro}-xgc2-scout-description" "0.4.10-3"
  fetch "ros-${ros_distro}-swarm-ros-bridge" "1.1.0-12"
else
  fetch "ros-${ros_distro}-xgc2-scout-description" "0.4.10-16"
  fetch "ros-${ros_distro}-swarm-ros-bridge" "1.1.0-12"
fi

ls -l "${out_dir}"
