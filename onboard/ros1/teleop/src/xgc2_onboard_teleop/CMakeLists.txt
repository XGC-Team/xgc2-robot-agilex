cmake_minimum_required(VERSION 3.0.2)
project(xgc2_onboard_teleop)

find_package(catkin REQUIRED)
catkin_package()

catkin_install_python(PROGRAMS
  scripts/onboard_teleop_node
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch web
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
