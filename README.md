# XGC2 Robot AgileX

Vehicle-true ROS Melodic runtime for the AgileX Scout Mini onboard computer.

Source of truth is the Xavier copy under `/home/agilex`. This repository keeps
the chassis in `onboard/ros1/chassis`, the ground-station bridge in
`onboard/ros1/communication`, mocap in `onboard/ros1/perception`, plus
install-only systemd units in `onboard/ros1/autostart`. IMU, camera, and
LiDAR drivers live in `onboard/ros1/sensors`. RViz and compose launches
live in `onboard/ros1/visualization`. Chassis messages and the Mini visual/TF model come from
the published `xgc2-scout-msgs` and `xgc2-scout-description` packages.

## Vehicle

| Item | Value |
| --- | --- |
| Host | `xavier` |
| Board | NVIDIA Jetson Xavier |
| OS | Ubuntu 18.04 (Bionic) |
| ROS | Melodic |
| Arch | arm64 |

All systemd units live in `agilex_onboard_autostart`.
`apt install ros-melodic-xgc2-agilex` installs chassis, bridge, and
autostart. A fresh install does not enable or start any unit. Later package
upgrades preserve operator-enabled chassis, roscore, and HI226 units. IMU,
camera, and lidar still need the matching sensors packages before those units
can actually start.

```text
xgc2-agilex-roscore.service
  start-roscore: the only ROS master
xgc2-agilex-chassis.service
  Wants roscore; wait-roscore; stagger; settle; wait can0 UP
  ExecStartPre setup-can0 @ 500000
  roslaunch --wait chassis.launch (scout_base_node required)
xgc2-agilex-imu-hi226.service
  wait-roscore; stagger; wait /dev/imu
  roslaunch --wait imu-hi226.launch (HI226 required) -> /imu/data_raw
xgc2-agilex-swarm-ros-bridge.service
  start-swarm-ros-bridge: wait /scout_status; wait /imu/data_raw if present
  agilex_swarm_ros_bridge/swarm.launch
    /imu/data_raw Imu max 20 Hz :3001
    /PowerVoltage Float32 0.5 Hz :3002
    /scout/chassis_state UInt32 1 Hz :3003
    /cmd_vel in from gcs :3001
xgc2-agilex-camera.service
xgc2-agilex-lidar-helios16.service
xgc2-agilex-mocap.service
  start-mocap: VRPN client only, no /pose or /ugv/pose relay
xgc2-agilex-onboard-teleop.service
  optional; not enabled. Web :8100 camera + D-pad / dual-stick.
  Requires ros-*-xgc2-agilex-onboard-teleop. Not field-panel (:8099).
```

## Packages

| Debian package | ROS package | Role |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-wrp-io` | `wrp_io` | CAN/serial IO |
| `ros-melodic-xgc2-agilex-ugv-sdk` | `ugv_sdk` | Scout CAN protocol |
| `ros-melodic-scout-msgs` | `scout_msgs` | Chassis messages from `xgc2-scout-msgs` (not packaged here) |
| `ros-melodic-xgc2-agilex-scout-base` | `scout_base` | Chassis node |
| `ros-melodic-xgc2-scout-description` | `scout_description` | Mini visual/TF from `xgc2-scout-description` (not packaged here) |
| `ros-melodic-swarm-ros-bridge` | `swarm_ros_bridge` | Official XGC2 bridge (APT, not rebuilt here) |
| `ros-melodic-xgc2-agilex-swarm-ros-bridge` | `agilex_swarm_ros_bridge` | Vehicle YAML+launch for the official bridge |
| `ros-melodic-xgc2-agilex` | (meta) | Vehicle chassis + bridge + autostart units; does not enable or start them |
| `ros-melodic-xgc2-agilex-onboard-autostart` | `agilex_onboard_autostart` | standalone roscore + chassis/IMU/comm/camera/lidar/mocap/panel/teleop units; install-only. Site params in `/etc/xgc2/agilex/onboard.env`. Enable chassis (Wants roscore). Mocap for Agent sessions is `agilex-mocap-ros1`. Teleop viewer is optional: `ros-melodic-xgc2-agilex-onboard-teleop` then `xgc2-agilex-onboard-teleop.service`. |

D435 / D435i capture lives in the shared [`xgc2-camera-d435`](https://github.com/XGC-Team/xgc2-camera-d435) product. Scout only names topics in `agilex_onboard_autostart/camera.launch`.

| Debian package | ROS package | Role |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-serial-imu` | `serial_imu` | Optional HI226 driver, `/dev/imu`. Field-effective rate is 100 Hz; Gazebo Scout IMU in `xgc2-gazebo-sim-agilex` must match. |
| `ros-melodic-xgc2-agilex-rslidar-sdk` | `rslidar_sdk` | Helios 16, `/rslidar_points`, frame `rslidar` |
| `ros-melodic-xgc2-agilex-onboard-rviz` | `agilex_onboard_rviz` | Onboard RViz config |
| `ros-melodic-xgc2-agilex-onboard-teleop` | `xgc2_onboard_teleop` | Optional camera + dual-page teleop (D-pad / dual-stick). Not field-panel. Web `:8100`. Unit `xgc2-agilex-onboard-teleop.service` is install-only. |

```bash
sudo apt-get install ros-melodic-xgc2-agilex-onboard-rviz
roslaunch agilex_onboard_rviz rviz.launch
roslaunch agilex_onboard_autostart camera.launch
roslaunch agilex_onboard_autostart lidar.launch
```

Onboard RViz is `agilex_onboard_rviz/rviz/viz.rviz`. Camera runtime also needs the vehicle `librealsense2` (on Xavier it is `/usr/local/lib`).

`docs/` in this product only keeps the vendor manual PDF. Field notes live in the main repo `docs/field/agilex/`.

## APT

Packages are published to `http://xgc2.apt.xiaokang.ink`. A new computer only needs the keyring, a `deb` line, and `apt install`. HTTPS works too.

| Machine | Ubuntu | ROS | `arch=` | `deb` suite | Install |
| --- | --- | --- | --- | --- | --- |
| Vehicle (Xavier, optional IMU) | 18.04 | Melodic | `arm64` | `bionic` | `ros-melodic-xgc2-agilex` |
| Vehicle (Orin / Noetic, chassis) | 20.04 | Noetic | `arm64` | `focal` | `ros-noetic-xgc2-agilex-chassis` |
| New workstation / ground station | 20.04 | Noetic | `amd64` | `focal` | `ros-noetic-scout-msgs` (and the bridge if it should talk to the vehicle) |

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

Vehicle chassis (Xavier / Melodic). IMU is optional:

```bash
sudo apt-get install ros-melodic-xgc2-agilex
# postinst does not enable or start any unit.
sudo systemctl enable xgc2-agilex-chassis.service
# Site identity (rigid body, VRPN, ROS_IP) is /etc/xgc2/agilex/onboard.env.
# Do not enable mocap / IMU / camera / lidar / swarm-ros-bridge at boot.
# Agent process.run-definition agilex-mocap-ros1 starts mocap for a Session.
# sudo apt-get install ros-melodic-xgc2-agilex-serial-imu
# sudo apt-get install ros-melodic-xgc2-agilex-onboard-rviz
# Optional camera+teleop viewer (does not enable at boot; port 8100, not 8099):
# sudo apt-get install ros-melodic-xgc2-agilex-onboard-teleop
# sudo systemctl enable --now xgc2-agilex-onboard-teleop.service
```

Vehicle without IMU (Orin NX / Noetic chassis only):

```bash
sudo apt-get install ros-noetic-xgc2-agilex-chassis
sudo apt-get install ros-noetic-xgc2-agilex-onboard-autostart
sudo systemctl enable xgc2-agilex-chassis.service
```

Chassis still publishes `/scout_status` locally and is not sent across the official bridge. A relay copies voltage onto `/PowerVoltage` (`std_msgs/Float32`, 0.5 Hz, port 3002) — same name and type as the Wheeltec MCU — and packed `control_mode`/`base_state`/`fault_code` onto `/scout/chassis_state` (`std_msgs/UInt32`, 1 Hz, port 3003). HI226 publishes raw IMU on `/imu/data_raw`; `/imu/data` is reserved for a later fused estimate. The official bridge sends `/imu/data_raw` at most 20 Hz on 3001 and receives `/cmd_vel` from `gcs` on that car's GCS bind port (3001 for the first car). Point the station at those ports and keep the vehicle YAML `gcs` address on the same subnet. Do not enable the onboard systemd target on a laptop.

## CI

Packaging runs inside XGC2 layered images (`base` → `dev` → `ros` → `full`).
The container is offline and does not `apt-get`. Official ROS/toolchain come
from the image; sibling XGC2 debs are fetched on the runner and `dpkg -i`.

| Name | OS | ROS | Arch | Image layer |
| --- | --- | --- | --- | --- |
| `arm64-bionic-melodic` | Ubuntu 18.04 | Melodic | arm64 | `xgc2-build-bionic-ros-melodic` |
| `amd64-bionic-melodic` | Ubuntu 18.04 | Melodic | amd64 | `xgc2-build-bionic-ros-melodic` |
| `arm64-focal-noetic` | Ubuntu 20.04 | Noetic | arm64 | `xgc2-build-focal-ros-noetic` |
| `amd64-focal-noetic` | Ubuntu 20.04 | Noetic | amd64 | `xgc2-build-focal-ros-noetic` |

Sensor debs use the `full` layer (PCL / OpenCV already in the image).

```bash
.xgc2/scripts/build_debs_in_docker.sh --output-dir debs
```

Release branch: `melodic`.
