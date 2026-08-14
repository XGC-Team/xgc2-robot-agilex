cmake_minimum_required(VERSION 3.0.2)
project(agilex_d435_media)

find_package(catkin REQUIRED COMPONENTS roscpp sensor_msgs)
find_package(realsense2 QUIET)

catkin_package()

catkin_install_python(PROGRAMS
  scripts/ros_fallback_rtp
  scripts/serve_triple_preview
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION})

install(DIRECTORY launch config web
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
  OPTIONAL)

if(realsense2_FOUND)
  include_directories(${catkin_INCLUDE_DIRS})
  add_executable(d435_parallel_source src/d435_parallel_source.cpp)
  target_link_libraries(d435_parallel_source
    ${catkin_LIBRARIES}
    ${realsense2_LIBRARY}
    realsense2)
endif()
