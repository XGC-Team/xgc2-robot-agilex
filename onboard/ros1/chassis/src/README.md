# AgileX ROS1 chassis workspace

Required motion stack. IMU is optional and lives in `onboard/ros1/sensors`.

- `wrp_io`, `ugv_sdk`, `scout_base`
- `scout_msgs` and `scout_description` come from APT

Bridge YAML/launch live in `onboard/ros1/communication`. systemd units live
in `onboard/ros1/autostart`.
