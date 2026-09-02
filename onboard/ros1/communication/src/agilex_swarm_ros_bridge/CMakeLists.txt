cmake_minimum_required(VERSION 3.0.2)
project(agilex_swarm_ros_bridge)

add_compile_options(-std=c++11)

find_package(catkin REQUIRED COMPONENTS
  roscpp
  scout_msgs
  std_msgs
)

catkin_package(
  CATKIN_DEPENDS roscpp scout_msgs std_msgs
)

include_directories(${catkin_INCLUDE_DIRS})

add_executable(scout_status_to_std src/scout_status_to_std.cpp)
target_link_libraries(scout_status_to_std ${catkin_LIBRARIES})
add_dependencies(scout_status_to_std ${catkin_EXPORTED_TARGETS})

install(TARGETS scout_status_to_std
  RUNTIME DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
