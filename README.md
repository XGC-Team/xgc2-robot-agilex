# XGC2 Robot AgileX

Vehicle-true ROS Melodic runtime for the AgileX Scout Mini onboard computer.

Source of truth is the Xavier copy under `/home/agilex`. This repository keeps
the minimum boot graph only: IMU, chassis, TF/model, ground-station bridge, and
autostart. Camera, LiDAR, YOLO, mapping, and planning stay on the vehicle and
are not packaged here. There are no nested git submodules.

## Vehicle

| Item | Value |
| --- | --- |
| Host | `xavier` |
| Board | NVIDIA Jetson Xavier |
| OS | Ubuntu 18.04 (Bionic) |
| ROS | Melodic |
| Arch | arm64 |

Boot chain recovered from `agilex-auto-launch`. Compose launches live only in
the top-level autostart package:

```text
can0 @ 500000
agilex_onboard_autostart/imu.launch      -> serial_imu  /imu/data_raw
agilex_onboard_autostart/chassis.launch  -> scout_base_node + scout_v2.xacro TF
swarm_ros_bridge/test.launch             -> /imu/data_raw :3001, /scout_status :3002, /cmd_vel in
```

## Packages

| Debian package | ROS package | Role |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-serial-imu` | `serial_imu` | Serial IMU driver, `/dev/imu` |
| `ros-melodic-xgc2-agilex-wrp-io` | `wrp_io` | CAN/serial IO |
| `ros-melodic-xgc2-agilex-ugv-sdk` | `ugv_sdk` | Scout CAN protocol |
| `ros-melodic-xgc2-agilex-scout-msgs` | `scout_msgs` | Chassis messages |
| `ros-melodic-xgc2-agilex-scout-base` | `scout_base` | Chassis node |
| `ros-melodic-xgc2-agilex-scout-description` | `scout_description` | `scout_v2.xacro` + meshes |
| `ros-melodic-xgc2-agilex-swarm-ros-bridge` | `swarm_ros_bridge` | Vehicle bridge binary + YAML |
| `ros-melodic-xgc2-agilex-onboard-autostart` | `agilex_onboard_autostart` | systemd, udev, top-level compose launches |

## APT

Packages are published to `http://xgc2.apt.xiaokang.ink`. A new computer only needs the keyring, a `deb` line, and `apt install`. HTTPS works too.

| Machine | Ubuntu | ROS | `arch=` | `deb` suite | Install |
| --- | --- | --- | --- | --- | --- |
| Vehicle (Xavier) | 18.04 | Melodic | `arm64` | `bionic` | `ros-melodic-xgc2-agilex-onboard-autostart` |
| New workstation / ground station | 20.04 | Noetic | `amd64` | `focal` | `ros-noetic-xgc2-agilex-scout-msgs` (and the bridge if it should talk to the vehicle) |

Fingerprint of `xgc2-archive-keyring.gpg`:

```text
2A8E11B36F56D307ADF626D85E5FDC30979EA43F
```

Add the source (workstation default: Focal / amd64). On Bionic, `gpg` has no `--show-keys`; import the key into a temporary `GNUPGHOME` and read the `fpr:` line the same way.

```bash
APT_BASE_URL=http://xgc2.apt.xiaokang.ink
ARCH="$(dpkg --print-architecture)"
# vehicle: bionic    workstation: focal
SUITE=focal

curl -fsSL "${APT_BASE_URL}/xgc2-archive-keyring.gpg" -o /tmp/xgc2-archive-keyring.gpg

gpg --show-keys --with-fingerprint --with-colons /tmp/xgc2-archive-keyring.gpg 2>&1 \
| grep -q '^fpr:\+2A8E11B36F56D307ADF626D85E5FDC30979EA43F:$' \
&& sudo install -d -m 0755 /etc/apt/keyrings \
&& sudo cp /tmp/xgc2-archive-keyring.gpg /etc/apt/keyrings/xgc2-archive-keyring.gpg \
&& echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] ${APT_BASE_URL} ${SUITE} main" \
| sudo tee /etc/apt/sources.list.d/xgc2.list

sudo apt-get update
```

Ubuntu 18.04 `gpg` 2.2 has no `--show-keys`. Check the fingerprint like this instead:

```bash
GNUPGHOME=$(mktemp -d)
gpg --homedir "$GNUPGHOME" --import /tmp/xgc2-archive-keyring.gpg
gpg --homedir "$GNUPGHOME" --with-colons --fingerprint \
| grep -q '^fpr:\+2A8E11B36F56D307ADF626D85E5FDC30979EA43F:$'
rm -rf "$GNUPGHOME"
```

If another ROS mirror has an expired key and `apt-get update` fails, refresh only this source:

```bash
sudo apt-get update \
  -o Dir::Etc::sourcelist="sources.list.d/xgc2.list" \
  -o Dir::Etc::sourceparts="-" \
  -o APT::Get::List-Cleanup="0"
```

Vehicle:

```bash
sudo apt-get install ros-melodic-xgc2-agilex-onboard-autostart
# postinst enables xgc2-agilex-onboard.target; leave it disabled until you want boot autostart
sudo systemctl start xgc2-agilex-onboard.target
```

Ground station / new PC that only needs to decode chassis status from `tcp://<vehicle>:3002`:

```bash
sudo apt-get install ros-noetic-xgc2-agilex-scout-msgs
```

`/scout_status` is `scout_msgs/ScoutStatus` at 10 Hz on port 3002. `/imu/data_raw` stays on 3001. Point the station at `tcp://<vehicle>:3002` and keep the vehicle YAML `qgc` address on the same subnet. Do not enable the onboard systemd target on a laptop.

## CI

The build matrix covers two Ubuntu/ROS 1 pairs, each on arm64 and amd64. Noble/Jazzy is out until the nodes are ported.

| Name | OS | ROS | Arch |
| --- | --- | --- | --- |
| `arm64-bionic-melodic` | Ubuntu 18.04 | Melodic | arm64 |
| `amd64-bionic-melodic` | Ubuntu 18.04 | Melodic | amd64 |
| `arm64-focal-noetic` | Ubuntu 20.04 | Noetic | arm64 |
| `amd64-focal-noetic` | Ubuntu 20.04 | Noetic | amd64 |

```bash
.xgc2/scripts/build_debs_in_docker.sh --output-dir debs
```

Release branch: `melodic`.
