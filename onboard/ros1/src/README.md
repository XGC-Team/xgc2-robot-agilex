# AgileX ROS1 Source Layout

This workspace groups ROS packages by onboard function while keeping normal
catkin package discovery.

- `imu/`: IMU drivers and related device setup.
- `chassis/`: Scout chassis SDK and driver packages.
- `communication/`: Vehicle-specific communication launch/config packages.
- `sensors/`: Base onboard sensor drivers such as RealSense and RoboSense LiDAR.
