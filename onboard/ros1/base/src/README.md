# AgileX ROS1 base workspace

Minimum boot graph. Packages keep the ROS names used on the vehicle.

- `imu/`: `serial_imu`
- `chassis/`: Scout SDK and driver; `scout_msgs` and `scout_description` come from APT

Bridge YAML/launch live in `onboard/ros1/communication`. systemd units live
in `onboard/ros1/autostart`. Camera and LiDAR live in `onboard/ros1/sensors`.
