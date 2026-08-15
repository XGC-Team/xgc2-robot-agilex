# Onboard ROS1 workspaces

Seven sibling workspaces.

```text
chassis/src/             wrp_io, ugv_sdk, scout_base
                         (scout_msgs and scout_description come from APT)

communication/src/       agilex_swarm_ros_bridge (YAML+launch+relay)
                         official swarm_ros_bridge from APT

perception/src/          agilex_estimator
                         (mocap.launch + estimator.launch)

control/src/             agilex_nmpc
                         (shared unicycle NMPC)

sensors/src/             hardware drivers only
  lidar/rslidar_sdk
  imu/serial_imu
                         (D435 driver is shared xgc2-camera-d435)

visualization/src/       agilex_onboard_rviz

autostart/src/           agilex_onboard_autostart
                         chassis/IMU/comm/camera/lidar/mocap/WebRTC compose
                         and units (install only)
```

Autostart owns every unit. Apt installs them and enables none.
