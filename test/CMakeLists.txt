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
