cmake_minimum_required(VERSION 3.16)
project(ScoutHoldTests LANGUAGES CXX)
include(CTest)
find_package(XgcChassisHold 0.2.0 CONFIG REQUIRED COMPONENTS core udp)
find_package(PythonInterp 3 REQUIRED)
find_program(XGC2_HOLD_CLI xgc2-hold)
if(NOT XGC2_HOLD_CLI)
  message(FATAL_ERROR "The installed xgc2-hold command line tool is required")
endif()

set(SCOUT_DEVEL_PREFIX "" CACHE PATH "Catkin devel space containing the Scout driver")
if(NOT SCOUT_DEVEL_PREFIX)
  message(FATAL_ERROR "SCOUT_DEVEL_PREFIX must name the built catkin devel space")
endif()

add_library(scout_loop_barrier SHARED scout_loop_barrier.cpp)
target_compile_features(scout_loop_barrier PRIVATE cxx_std_17)
target_compile_options(scout_loop_barrier PRIVATE -Wall -Wextra -Werror)
target_link_libraries(scout_loop_barrier PRIVATE ${CMAKE_DL_LIBS})

add_test(NAME scout_hold COMMAND ${PYTHON_EXECUTABLE}
  ${CMAKE_CURRENT_SOURCE_DIR}/ros_device_output_test.py
  --devel ${SCOUT_DEVEL_PREFIX} --helpers ${CMAKE_CURRENT_BINARY_DIR})
set_tests_properties(scout_hold PROPERTIES TIMEOUT 240)

# No device transport is opened: mock CAN frames enter the real SDK parser,
# while a real messenger and UDP caller verify feedback validity and expiry.
file(TO_CMAKE_PATH "$ENV{CMAKE_PREFIX_PATH}" _scout_environment_prefixes)
list(PREPEND CMAKE_PREFIX_PATH "${SCOUT_DEVEL_PREFIX}" ${_scout_environment_prefixes})
find_package(catkin REQUIRED COMPONENTS roscpp scout_base scout_msgs ugv_sdk tf2_ros)
add_executable(scout_feedback_freshness_host scout_feedback_freshness_host.cpp)
target_compile_features(scout_feedback_freshness_host PRIVATE cxx_std_17)
target_compile_options(scout_feedback_freshness_host PRIVATE -Wall -Wextra -Werror)
target_include_directories(scout_feedback_freshness_host SYSTEM PRIVATE ${catkin_INCLUDE_DIRS})
target_link_libraries(scout_feedback_freshness_host PRIVATE ${catkin_LIBRARIES} XgcChassisHold::udp)
add_test(NAME scout_feedback_freshness COMMAND ${PYTHON_EXECUTABLE}
  ${CMAKE_CURRENT_SOURCE_DIR}/scout_feedback_freshness_test.py
  --host $<TARGET_FILE:scout_feedback_freshness_host>)
set_tests_properties(scout_feedback_freshness PROPERTIES TIMEOUT 60)

# Compile allocation/inline lifetime code with the frozen pre-tracking header,
# then exercise the current SDK without connecting a device or starting ROS.
add_executable(scout_sdk_abi_canary abi/scout_sdk_abi_canary.cpp)
target_compile_features(scout_sdk_abi_canary PRIVATE cxx_std_17)
target_include_directories(scout_sdk_abi_canary BEFORE PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/abi/legacy_include)
target_include_directories(scout_sdk_abi_canary SYSTEM PRIVATE ${catkin_INCLUDE_DIRS})
target_link_libraries(scout_sdk_abi_canary PRIVATE ${catkin_LIBRARIES})
add_test(NAME scout_sdk_abi_canary COMMAND scout_sdk_abi_canary)
set_tests_properties(scout_sdk_abi_canary PROPERTIES TIMEOUT 10)
