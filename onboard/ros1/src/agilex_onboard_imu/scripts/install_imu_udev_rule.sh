#!/usr/bin/env bash
set -euo pipefail

RULE_FILE="/etc/udev/rules.d/99-xgc2-agilex-imu.rules"
RULE='KERNEL=="ttyUSB*", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE:="0666", GROUP:="dialout", SYMLINK+="imu"'

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script installs a udev rule and must run as root." >&2
  echo "Try: sudo $0" >&2
  exit 1
fi

printf '%s\n' "${RULE}" > "${RULE_FILE}"
udevadm control --reload-rules
udevadm trigger --subsystem-match=tty || true

echo "Installed ${RULE_FILE}"
echo "Reconnect the IMU USB-serial adapter if /dev/imu does not appear."
