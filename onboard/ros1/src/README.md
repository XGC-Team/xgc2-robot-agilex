# AgileX ROS1 source layout

Packages keep the ROS names used on the vehicle.

- `imu/`: `serial_imu`
- `chassis/`: Scout SDK and driver; `scout_msgs` and `scout_description` come from APT
- `communication/`: empty; the generic `swarm_ros_bridge` comes from APT
- `autostart/`: systemd units and the only compose launches
