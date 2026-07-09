# XGC2 Robot AgileX

This repository stores real-vehicle resources for the AgileX UGV platform used
by XGC2.

## Package

- Product family: `xgc2-agilex`
- Active product id: `xgc2-agilex-onboard-ros1`
- Debian packages:
  - `ros-melodic-xgc2-agilex-onboard-imu`
  - `ros-melodic-xgc2-agilex-wrp-io`
  - `ros-melodic-xgc2-agilex-ugv-sdk`
  - `ros-melodic-xgc2-agilex-scout-base`
  - `ros-melodic-xgc2-agilex-scout-bringup`
  - `ros-melodic-xgc2-agilex-swarm-ros-bridge`
  - `ros-melodic-xgc2-agilex-realsense2-camera`
  - `ros-melodic-xgc2-agilex-realsense2-description`
  - `ros-melodic-xgc2-agilex-rslidar-sdk`
- Source path: `products/robotics/agilex`
- Release branch: `melodic`
- ROS distribution: Melodic

The ROS Debian packages are versioned per ROS package from each package's
`package.xml`, with internal `>=` dependency constraints between split packages.
The compatible `scout_msgs` package is consumed from the standalone
`ros-melodic-scout-msgs` product. The recovered real-vehicle
`scout_description` tree is preserved in the `xgc2-scout-description`
repository on branch `melodic-agilex-real-description`; it is not part of the
onboard runtime product because the vehicle core bringup does not require local
visualization assets.

The generic `swarm_ros_bridge` binary is consumed from the standalone
`ros-melodic-swarm-ros-bridge` communication product. This repository only owns
the AgileX-specific bridge YAML and launch wrapper.

Base onboard sensor drivers are grouped under `onboard/ros1/src/sensors`.
Non-core recovered navigation, vision, and voice extension packages are carried
by the separate `xgc2-robot-agilex-extend` repository mounted at
`onboard/ros1/src/extend`.

## Repository Boundary

This repository owns real AgileX onboard-computer runtime notes, startup
services, hardware communication configuration, and vehicle-specific integration
resources.

This repository does not own generated logs, rosbags, or unrelated simulator
assets.

## Runtime Notes

- `docs/boot_autostart.md`: recovered boot-time systemd service chain.
- `docs/chassis_control.md`: real Scout chassis command and feedback path.
- `docs/imu_autostart.md`: onboard serial IMU startup and ROS topic path.
- `docs/simulation_topic_compatibility.md`: real-vehicle and Gazebo Scout topic
  compatibility notes.
