cmake_minimum_required(VERSION 2.8.3)
project(scout_bringup)

find_package(catkin REQUIRED)

catkin_package()

install(
  DIRECTORY launch maps param rviz scripts
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
