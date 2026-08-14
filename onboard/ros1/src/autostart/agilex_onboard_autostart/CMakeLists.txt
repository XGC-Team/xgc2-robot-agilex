cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_autostart)

add_compile_options(-std=c++11)

find_package(catkin REQUIRED COMPONENTS
  geometry_msgs
  roscpp
  scout_msgs
  std_msgs
)

catkin_package(
  CATKIN_DEPENDS geometry_msgs roscpp scout_msgs std_msgs
)

include_directories(${catkin_INCLUDE_DIRS})

add_executable(scout_status_to_std src/scout_status_to_std.cpp)
target_link_libraries(scout_status_to_std ${catkin_LIBRARIES})
add_dependencies(scout_status_to_std ${catkin_EXPORTED_TARGETS})

install(TARGETS scout_status_to_std
  RUNTIME DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

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
