#!/usr/bin/env bash
# Install the published xgc2-scout-description package. The onboard tree does
# not vendor, submodule, or rebuild scout_description.
set -euo pipefail

ros_distro="${ROS_DISTRO:-}"
package="ros-${ros_distro}-xgc2-scout-description"

case "${ros_distro}" in
  melodic)
    distribution="bionic"
    ;;
  noetic)
    distribution="focal"
    ;;
  *)
    echo "unsupported scout_description dependency target: ${ros_distro}" >&2
    exit 1
    ;;
esac

apt_get_update() {
  local attempt
  for attempt in 1 2 3; do
    if apt-get update; then
      return 0
    fi
    [[ "${attempt}" -lt 3 ]] || return 1
    sleep "$((attempt * 5))"
  done
}

export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends ca-certificates curl
install -d -m 0755 /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/xgc2-archive-keyring.gpg ]]; then
  curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 \
    https://xgc2.apt.xiaokang.ink/xgc2-archive-keyring.gpg \
    -o /etc/apt/keyrings/xgc2-archive-keyring.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] https://xgc2.apt.xiaokang.ink ${distribution} main" \
  > /etc/apt/sources.list.d/xgc2.list
if [[ -n "${XGC2_APT_OVERLAY_URL:-}" ]]; then
  echo "deb [signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] ${XGC2_APT_OVERLAY_URL%/} ${distribution} main" \
    > /etc/apt/sources.list.d/00-xgc2-release-train.list
fi
apt_get_update
apt-get install -y "${package}"

prefix="/opt/ros/${ros_distro}"
if [[ ! -f "${prefix}/share/scout_description/urdf/scout_visual.urdf" ]]; then
  echo "installed ${package} is missing scout_visual.urdf" >&2
  exit 1
fi

echo "installed ${package} $(dpkg-query -W -f='${Version}' "${package}")"
