cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_rviz)

find_package(catkin REQUIRED)
catkin_package()

catkin_install_python(PROGRAMS scripts/vrpn_viz_tf
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch rviz
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
