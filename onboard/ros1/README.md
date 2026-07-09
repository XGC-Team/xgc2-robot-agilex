# XGC2 AgileX Onboard ROS1

This product packages recovered AgileX onboard ROS Melodic source packages into
independently installable Debian packages.

## Debian Packages

| Debian package | ROS package | Purpose |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-onboard-imu` | `agilex_onboard_imu`, `imu_launch` | Serial IMU driver and compatibility launch package |
| `ros-melodic-xgc2-agilex-wrp-io` | `wrp_io` | Weston Robot Platform IO support |
| `ros-melodic-xgc2-agilex-ugv-sdk` | `ugv_sdk` | AgileX/Scout CAN protocol SDK |
| `ros-melodic-xgc2-agilex-scout-msgs` | `scout_msgs` | Scout status and command message definitions |
| `ros-melodic-xgc2-agilex-scout-description` | `scout_description` | URDF/xacro model and robot description assets |
| `ros-melodic-xgc2-agilex-scout-base` | `scout_base` | Scout base driver node |
| `ros-melodic-xgc2-agilex-scout-bringup` | `scout_bringup` | Scout launch entry points |

The packages are split by ROS package so SDK, messages, description, driver,
and bringup can be installed independently.

## Runtime Launch

IMU:

```bash
roslaunch agilex_onboard_imu imu_msg.launch
```

Recovered IMU autostart compatibility:

```bash
roslaunch imu_launch imu_msg.launch
```

Scout chassis:

```bash
roslaunch scout_bringup scout_minimal.launch
```

The chassis launch expects the vehicle CAN interface to be available as:

```text
can0
```

with the recovered runtime configuration:

```bash
ip link set can0 up type can bitrate 500000
```

Systemd autostart files are intentionally not packaged in this product batch.

## Build

Build and install-check the packages locally:

```bash
.xgc2/scripts/build_debs_in_docker.sh --output-dir debs
```

Run that command from the AgileX product repository root.
