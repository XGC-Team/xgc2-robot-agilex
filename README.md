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
  - `ros-melodic-xgc2-agilex-scout-description`
  - `ros-melodic-xgc2-agilex-scout-base`
  - `ros-melodic-xgc2-agilex-scout-bringup`
- Source path: `products/robotics/agilex`
- Release branch: `melodic`
- ROS distribution: Melodic

The ROS Debian packages are versioned per ROS package from each package's
`package.xml`, with internal `>=` dependency constraints between split packages.
The compatible `scout_msgs` package is consumed from the standalone
`ros-melodic-scout-msgs` product.

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
