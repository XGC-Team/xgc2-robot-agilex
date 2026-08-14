cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_sensors)

find_package(catkin REQUIRED)
catkin_package()

install(PROGRAMS scripts/start-native-rtp
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch rviz
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
