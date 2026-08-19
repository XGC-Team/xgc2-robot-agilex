cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_autostart)

find_package(catkin REQUIRED)

catkin_package()

install(PROGRAMS
  scripts/apply-host-defaults
  scripts/setup-can0
  scripts/start-roscore
  scripts/wait-roscore
  scripts/usb-recover
  scripts/start-chassis
  scripts/start-imu-hi226
  scripts/start-camera
  scripts/start-swarm-ros-bridge
  scripts/start-mocap
  scripts/start-lidar-helios16
  scripts/start-field-panel
  scripts/wait-device
  scripts/serve_triple_preview
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(DIRECTORY web
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
  OPTIONAL
)

install(FILES
  config/onboard.env
  config/sources.json
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/config
)

install(DIRECTORY systemd
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(DIRECTORY udev
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
