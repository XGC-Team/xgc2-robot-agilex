cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_autostart)

find_package(catkin REQUIRED)

catkin_package()

install(PROGRAMS
  scripts/apply-host-defaults
  scripts/setup-can0
  scripts/start-base
  scripts/start-camera
  scripts/start-communication
  scripts/start-lidar
  scripts/wait-device
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(FILES
  config/onboard.env
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/config
)

install(DIRECTORY systemd
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(FILES
  udev/99-xgc2-agilex-imu.rules
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/udev
)
