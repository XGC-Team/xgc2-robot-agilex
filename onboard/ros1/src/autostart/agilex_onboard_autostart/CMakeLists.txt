cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_autostart)

find_package(catkin REQUIRED)

catkin_package()

install(PROGRAMS
  scripts/setup-can0
  scripts/start-chassis
  scripts/start-imu
  scripts/start-swarm-ros-bridge
  scripts/wait-device
  scripts/wait-ros-master
  scripts/wait-ros-node
  scripts/wait-ros-topic
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(FILES
  config/ros_topics.yaml
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/config
)

install(FILES
  systemd/xgc2-agilex-can0.service
  systemd/xgc2-agilex-chassis.service
  systemd/xgc2-agilex-imu.service
  systemd/xgc2-agilex-onboard.target
  systemd/xgc2-agilex-swarm-ros-bridge.service
  systemd/xgc2-roscore.service
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/systemd
)

install(FILES
  udev/99-xgc2-agilex-imu.rules
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/udev
)
