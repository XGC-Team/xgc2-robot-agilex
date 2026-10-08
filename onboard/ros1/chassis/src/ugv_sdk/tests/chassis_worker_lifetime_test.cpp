// Uses the real Scout command worker without opening CAN/serial or ROS.
#include "ugv_sdk/scout/scout_base.hpp"
#include <chrono>
#include <iostream>
#include <thread>

int main() {
  for (int run = 0; run != 32; ++run) {
    westonrobot::ScoutBase scout(true);
    scout.SetMotionCommand(0.2, 0.3);
    scout.SetMotionCommand(0.0, 0.0);
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
    if (run % 2 == 0) {
      scout.Terminate();
      scout.Terminate(); // Idempotent shutdown; no abort or join on dead worker.
    }
    // Other iterations test derived destruction before virtual target/state.
  }
  std::cout << "PASS Scout command worker explicit and destructor quiescence\n";
}
