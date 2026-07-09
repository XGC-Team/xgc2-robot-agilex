# XGC2 AgileX Onboard ROS1 IMU

This product packages the recovered AgileX onboard serial IMU driver as one
ROS Melodic Debian package.

- ROS package: `agilex_onboard_imu`
- Compatibility launch package: `imu_launch`
- Debian package: `ros-melodic-xgc2-agilex-onboard-imu`
- Default serial port: `/dev/imu`
- Default baud rate: `115200`
- Default topic: `/imu/data_raw`

Runtime launch:

```bash
roslaunch agilex_onboard_imu imu_msg.launch
```

Recovered vehicle autostart compatibility:

```bash
roslaunch imu_launch imu_msg.launch
```

Build the package locally:

```bash
.xgc2/scripts/build_debs_in_docker.sh --output-dir debs
```

Run that command from the AgileX product repository root.
