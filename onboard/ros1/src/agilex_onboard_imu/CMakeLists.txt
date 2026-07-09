cmake_minimum_required(VERSION 3.0.2)
project(agilex_onboard_imu)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(catkin REQUIRED COMPONENTS
  roscpp
  sensor_msgs
  serial
)

catkin_package(
  CATKIN_DEPENDS roscpp sensor_msgs serial
)

include_directories(
  src
  ${catkin_INCLUDE_DIRS}
)

add_executable(agilex_onboard_imu_node
  src/serial_imu.cpp
  src/imu_data_decode.c
  src/packet.c
)
target_link_libraries(agilex_onboard_imu_node
  ${catkin_LIBRARIES}
)

install(TARGETS agilex_onboard_imu_node
  RUNTIME DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/launch
  FILES_MATCHING PATTERN "*.launch"
)
