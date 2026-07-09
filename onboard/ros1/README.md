# XGC2 AgileX Onboard ROS1

This product packages recovered AgileX onboard ROS Melodic source packages into
independently installable Debian packages.

## Debian Packages

| Debian package | ROS package | Purpose |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-onboard-imu` | `agilex_onboard_imu` | Serial IMU driver and one-time `/dev/imu` udev setup script |
| `ros-melodic-xgc2-agilex-wrp-io` | `wrp_io` | Weston Robot Platform IO support |
| `ros-melodic-xgc2-agilex-ugv-sdk` | `ugv_sdk` | AgileX/Scout CAN protocol SDK |
| `ros-melodic-xgc2-agilex-scout-description` | `scout_description` | URDF/xacro model and robot description assets |
| `ros-melodic-xgc2-agilex-scout-base` | `scout_base` | Scout base driver node |
| `ros-melodic-xgc2-agilex-scout-bringup` | `scout_bringup` | Scout launch entry points |

The packages are split by ROS package so SDK, description, driver, and bringup
can be installed independently. `scout_msgs` is installed from the standalone
`ros-melodic-scout-msgs` package and keeps the original ROS package name.

## Runtime Launch

IMU:

```bash
roslaunch agilex_onboard_imu imu_msg.launch
```

Install the IMU udev rule once on a vehicle:

```bash
sudo /opt/ros/melodic/share/agilex_onboard_imu/scripts/install_imu_udev_rule.sh
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

Internal Debian dependencies use `>=` constraints between XGC2 packages. For
example, `scout_base` requires compatible `ugv_sdk` plus the external
`ros-melodic-scout-msgs` package, and `scout_bringup` requires compatible base
and description package versions.

## Build

Build and install-check the packages locally:

```bash
.xgc2/scripts/build_debs_in_docker.sh --output-dir debs
```

Run that command from the AgileX product repository root.
