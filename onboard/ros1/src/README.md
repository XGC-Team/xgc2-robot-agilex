# AgileX ROS1 source layout

Packages keep the ROS names used on the vehicle.

- `imu/`: `serial_imu`
- `chassis/`: Scout SDK, driver, messages, and `scout_description` (submodule, `melodic` branch)
- `communication/`: vehicle `swarm_ros_bridge`
- `autostart/`: systemd units and the only compose launches
