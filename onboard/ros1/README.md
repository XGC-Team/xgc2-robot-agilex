# XGC2 AgileX Onboard ROS1

This product packages recovered AgileX onboard ROS Melodic source packages into
independently installable Debian packages.

## Debian Packages

| Debian package | ROS package | Purpose |
| --- | --- | --- |
| `ros-melodic-xgc2-agilex-onboard-imu` | `agilex_onboard_imu` | Serial IMU driver and one-time `/dev/imu` udev setup script |
| `ros-melodic-xgc2-agilex-wrp-io` | `wrp_io` | Weston Robot Platform IO support |
| `ros-melodic-xgc2-agilex-ugv-sdk` | `ugv_sdk` | AgileX/Scout CAN protocol SDK |
| `ros-melodic-xgc2-agilex-scout-base` | `scout_base` | Scout base driver node |
| `ros-melodic-xgc2-agilex-scout-bringup` | `scout_bringup` | Scout launch entry points |
| `ros-melodic-xgc2-agilex-swarm-ros-bridge` | `agilex_swarm_ros_bridge` | AgileX topic/IP configuration for `swarm_ros_bridge` |
| `ros-melodic-xgc2-agilex-realsense2-camera` | `realsense2_camera` | Intel RealSense camera driver |
| `ros-melodic-xgc2-agilex-realsense2-description` | `realsense2_description` | RealSense URDF, meshes, launch, and RViz assets |
| `ros-melodic-xgc2-agilex-rslidar-sdk` | `rslidar_sdk` | RoboSense LiDAR ROS1 driver |
| `ros-melodic-xgc2-agilex-onboard-autostart` | `agilex_onboard_autostart` | Systemd autostart, udev, and vehicle runtime configuration |

The packages are split by ROS package so SDK, driver, and bringup can be
installed independently. `scout_msgs` is installed from the standalone
`ros-melodic-scout-msgs` package and keeps the original ROS package name. The
recovered real-vehicle `scout_description` tree is preserved in
`xgc2-scout-description` on branch `melodic-agilex-real-description`, but it is
not packaged in this onboard product. The generic `swarm_ros_bridge` binary is
installed from the standalone `ros-melodic-swarm-ros-bridge` communication
product; this product only packages the AgileX-specific YAML and launch wrapper.
Base onboard sensor drivers live under `onboard/ros1/src/sensors` and are split
into independent packages so camera and LiDAR support can be installed
separately.

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

For a namespaced XGC2 robot, start the chassis and bridge in the same namespace:

```bash
roslaunch scout_bringup scout_minimal.launch robot_namespace:=/ugv1
roslaunch agilex_swarm_ros_bridge agilex_swarm_ros_bridge.launch robot_namespace:=/ugv1
```

The Scout driver uses relative `cmd_vel`, `scout_status`, and light-control
topics. The default namespace remains `/`, preserving the existing onboard
topic names. Each ground-station bridge sender must bind that robot's
`/<namespace>/cmd_vel` to a distinct network port; sharing one command port
between vehicles would broadcast the same command to all of them.
For systemd autostart, set the same `XGC2_ROBOT_NAMESPACE=/ugv1` override on
both `xgc2-agilex-chassis.service` and
`xgc2-agilex-swarm-ros-bridge.service`; their packaged default remains `/`.

The recovered onboard product is ROS Melodic on Ubuntu 18.04, while the XGC2
Scout Robot Adapter is currently packaged for ROS Noetic on Ubuntu 20.04. Run
that Adapter on a compatible target which can reach the vehicle ROS graph, or
provide a per-robot bridge/sidecar; the Noetic package is not directly
installable into this Melodic image.

The chassis launch expects the vehicle CAN interface to be available as:

```text
can0
```

with the recovered runtime configuration:

```bash
ip link set can0 up type can bitrate 500000
```

Swarm bridge:

```bash
roslaunch agilex_swarm_ros_bridge agilex_swarm_ros_bridge.launch
```

The default bridge configuration sends `/imu/data_raw` to the configured QGC
peer and receives `/cmd_vel` from that peer.

RealSense:

```bash
roslaunch realsense2_camera rs_camera.launch
```

RoboSense LiDAR:

```bash
roslaunch rslidar_sdk start.launch
```

The optional autostart package installs `xgc2-agilex-onboard.target` plus
service units for roscore, IMU, CAN setup, Scout chassis, and swarm bridge. It
uses lightweight ROS XML-RPC/topic probes instead of `rosnode list` or
`rostopic list`, installs the `/dev/imu` udev rule, and places the bridge YAML
under `/etc/xgc2/agilex/swarm_ros_bridge/ros_topics.yaml`.

Install it on the vehicle with:

```bash
sudo apt install ros-melodic-xgc2-agilex-onboard-autostart
```

The package enables `xgc2-agilex-onboard.target` for the next boot but does not
start it during installation. Start it explicitly when the vehicle is safe to
bring online:

```bash
sudo systemctl start xgc2-agilex-onboard.target
```

Internal Debian dependencies use `>=` constraints between XGC2 packages. For
example, `scout_base` requires compatible `ugv_sdk` plus the external
`ros-melodic-scout-msgs` package, and `scout_bringup` requires a compatible
base package version.

## Build

Build and install-check the packages locally:

```bash
.xgc2/scripts/build_debs_in_docker.sh --output-dir debs
```

Run that command from the AgileX product repository root.
