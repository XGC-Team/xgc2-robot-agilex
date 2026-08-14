cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_sensors)

find_package(catkin REQUIRED)
catkin_package()

install(DIRECTORY launch rviz
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
