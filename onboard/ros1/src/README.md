# AgileX ROS1 source layout

Packages keep the ROS names used on the vehicle.

- `imu/`: `serial_imu`
- `chassis/`: Scout SDK, driver, messages, and `scout_description` (submodule, `melodic` branch)
- `communication/`: empty; the generic `swarm_ros_bridge` comes from APT
- `autostart/`: systemd units and the only compose launches
