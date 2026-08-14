cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_autostart)

find_package(catkin REQUIRED)

catkin_package()

install(PROGRAMS
  scripts/setup-can0
  scripts/start-boot-settle
  scripts/start-chassis
  scripts/start-imu
  scripts/start-roscore
  scripts/start-swarm-ros-bridge
  scripts/wait-device
  scripts/wait-ros-master
  scripts/wait-ros-node
  scripts/wait-ros-topic
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(FILES
  config/onboard.env
  config/ros_topics.yaml
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/config
)

install(DIRECTORY systemd
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(FILES
  udev/99-xgc2-agilex-imu.rules
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/udev
)
