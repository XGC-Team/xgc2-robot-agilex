# Onboard ROS1 workspaces

Four sibling workspaces. Sensors stay out of the min-boot compile.

```text
base/src/                chassis stack
  imu/                   serial_imu
  chassis/               wrp_io, ugv_sdk, scout_base
                         (scout_msgs and scout_description come from APT)

communication/src/       agilex_swarm_ros_bridge (YAML+launch+relay)
                         official swarm_ros_bridge from APT

autostart/src/           agilex_onboard_autostart
                         base systemd, udev, compose launches (install only)

sensors/src/             xgc2-agilex-onboard-sensors
  realsense2_camera
  realsense2_description
  rslidar_sdk
  agilex_d435_media
  agilex_onboard_sensors
```

All four units are owned by `autostart`. Min-boot apt installs them all
and enables only `xgc2-agilex-base.service` for the next boot.
