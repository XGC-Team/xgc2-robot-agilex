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
  - `ros-melodic-xgc2-agilex-scout-msgs`
  - `ros-melodic-xgc2-agilex-scout-description`
  - `ros-melodic-xgc2-agilex-scout-base`
  - `ros-melodic-xgc2-agilex-scout-bringup`
- Source path: `products/robotics/agilex`
- Release branch: `melodic`
- ROS distribution: Melodic

The ROS Debian packages are versioned per ROS package from each package's
`package.xml`, with internal `>=` dependency constraints between split packages.

## Repository Boundary

This repository owns real AgileX onboard-computer runtime notes, startup
services, hardware communication configuration, and vehicle-specific integration
resources.

This repository does not own generated logs, rosbags, or unrelated simulator
assets.
