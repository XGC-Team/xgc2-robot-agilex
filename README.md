# XGC2 Robot AgileX

Vehicle-true ROS Melodic runtime for the AgileX Scout Mini onboard computer.

Source of truth is the Xavier copy under `/home/agilex`. This repository keeps
the minimum boot graph only: IMU, chassis, TF/model, ground-station bridge, and
autostart. Camera, LiDAR, YOLO, mapping, and planning stay on the vehicle and
are not packaged here. There are no nested git submodules.

现场核实：[`docs/onboard-truth.md`](docs/onboard-truth.md)。  
相机 / 雷达 / RViz 启动步骤：[`docs/sensor-rviz-bringup.md`](docs/sensor-rviz-bringup.md)。

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
swarm_ros_bridge/test.launch             -> /imu/data_raw out, /cmd_vel in
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

Install on the vehicle:

```bash
sudo apt update
sudo apt install ros-melodic-xgc2-agilex-onboard-autostart
sudo systemctl start xgc2-agilex-onboard.target
```

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
