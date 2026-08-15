# XGC2 Robot AgileX

Vehicle-true ROS Melodic runtime for the AgileX Scout Mini onboard computer.

Source of truth is the Xavier copy under `/home/agilex`. This repository keeps
the minimum boot graph only: IMU and chassis in `onboard/ros1/base`,
the ground-station bridge in `onboard/ros1/communication`, plus
install-only systemd units in `onboard/ros1/autostart`. Camera and LiDAR
are a fourth workspace, `onboard/ros1/sensors`. Chassis messages and the Mini visual/TF model come from
the published `xgc2-scout-msgs` and `xgc2-scout-description` packages.

## Vehicle

| Item | Value |
| --- | --- |
| Host | `xavier` |
| Board | NVIDIA Jetson Xavier |
| OS | Ubuntu 18.04 (Bionic) |
| ROS | Melodic |
| Arch | arm64 |

All four systemd units live in `agilex_onboard_autostart`.
`apt install ros-melodic-xgc2-agilex` installs them all. On the vehicle,
base is enabled for the next boot. Communication, camera, and lidar stay
install-only until an operator enables them. Camera/lidar still need the
sensors package before those two units can actually start.

```text
xgc2-agilex-base.service
  start-base: settle, wait /dev/imu, wait can0 UP
  ExecStartPre setup-can0 @ 500000
  agilex_onboard_autostart/base.launch
    imu.launch      -> serial_imu  /imu/data
    chassis.launch  -> scout_base_node + scout_visual.urdf TF
xgc2-agilex-communication.service
  start-communication: wait /imu/data and /scout_status
  agilex_swarm_ros_bridge/swarm.launch
    /imu/data Imu 30 Hz :3001
    /scout/twist Twist 1 Hz :3002
    /scout/status_text String 1 Hz :3003
    /cmd_vel in from gcs :3001
xgc2-agilex-camera.service
xgc2-agilex-lidar.service
```

## Packages

| Debian package | ROS package | Role |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-serial-imu` | `serial_imu` | Serial IMU driver, `/dev/imu` |
| `ros-melodic-xgc2-agilex-wrp-io` | `wrp_io` | CAN/serial IO |
| `ros-melodic-xgc2-agilex-ugv-sdk` | `ugv_sdk` | Scout CAN protocol |
| `ros-melodic-scout-msgs` | `scout_msgs` | Chassis messages from `xgc2-scout-msgs` (not packaged here) |
| `ros-melodic-xgc2-agilex-scout-base` | `scout_base` | Chassis node |
| `ros-melodic-xgc2-scout-description` | `scout_description` | Mini visual/TF from `xgc2-scout-description` (not packaged here) |
| `ros-melodic-swarm-ros-bridge` | `swarm_ros_bridge` | Official XGC2 bridge (APT, not rebuilt here) |
| `ros-melodic-xgc2-agilex-swarm-ros-bridge` | `agilex_swarm_ros_bridge` | Vehicle YAML+launch for the official bridge |
| `ros-melodic-xgc2-agilex` | (meta) | Vehicle min-boot: pulls the packages below; does not enable or start them |
| `ros-melodic-xgc2-agilex-onboard-autostart` | `agilex_onboard_autostart` | all four systemd units; enables base at boot |

D435 / D435i capture lives in the shared [`xgc2-camera-d435`](https://github.com/XGC-Team/xgc2-camera-d435) product (`realsense2_camera`, `realsense2_description`, `xgc2_camera_d435`). This vehicle only includes `camera.launch`. Other robots clone that repository into their workspace and run `roslaunch xgc2_camera_d435 d435.launch`. Camera and LiDAR compose on Scout is a **separate** product (`xgc2-agilex-onboard-sensors`) with two install-only services.

| Debian package | ROS package | Role |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-rslidar-sdk` | `rslidar_sdk` | Helios 16, `/rslidar_points`, frame `rslidar` |
| `ros-melodic-xgc2-agilex-onboard-sensors` | `agilex_onboard_sensors` | `camera.launch`, `lidar.launch`, onboard RViz |

```bash
sudo apt-get install ros-melodic-xgc2-agilex-onboard-sensors
# do not stop a running catkin_ws driver; these land in /opt/ros/melodic
roslaunch agilex_onboard_sensors camera.launch
roslaunch agilex_onboard_sensors lidar.launch
roslaunch agilex_onboard_sensors rviz.launch
```

Onboard RViz is `agilex_onboard_sensors/rviz/sensors.rviz` (fixed frame `rslidar`, `/rslidar_points`, color, depth). Camera runtime also needs the vehicle `librealsense2` (on Xavier it is `/usr/local/lib`).

`docs/` in this product only keeps the vendor manual PDF. Field notes live in the main repo `docs/field/agilex/`.

## APT

Packages are published to `http://xgc2.apt.xiaokang.ink`. A new computer only needs the keyring, a `deb` line, and `apt install`. HTTPS works too.

| Machine | Ubuntu | ROS | `arch=` | `deb` suite | Install |
| --- | --- | --- | --- | --- | --- |
| Vehicle (Xavier) | 18.04 | Melodic | `arm64` | `bionic` | `ros-melodic-xgc2-agilex` |
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

Vehicle:

```bash
sudo apt-get install xgc2-utils-linux-timezone
sudo apt-get install ros-melodic-xgc2-agilex
# postinst enables xgc2-agilex-base.service for the next boot.
# It does not start it now, and does not enable communication.
# sudo systemctl enable --now xgc2-agilex-communication.service
# sudo apt-get install ros-melodic-xgc2-agilex-onboard-sensors
# sudo systemctl enable --now xgc2-agilex-camera.service
# sudo systemctl enable --now xgc2-agilex-lidar.service
```

Ground station / new PC that only needs to decode chassis status from `tcp://<vehicle>:3002`:

```bash
sudo apt-get install ros-noetic-scout-msgs
```

Chassis still publishes `/scout_status` locally. A 1 Hz relay copies only bag-validated fields onto standard topics the official bridge already carries: `/scout/twist` (`geometry_msgs/Twist`) on port 3002 and `/scout/status_text` (`std_msgs/String`) on 3003. `/imu/data` stays on 3001. `/cmd_vel` comes back from `gcs` on its own port 3001. Point the station at those ports and keep the vehicle YAML `gcs` address on the same subnet. Do not enable the onboard systemd target on a laptop.

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
