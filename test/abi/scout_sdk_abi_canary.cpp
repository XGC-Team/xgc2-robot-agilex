#include <ugv_sdk/scout/scout_base.hpp>
#include <algorithm>
#include <array>
#include <cstdio>
#include <new>
struct Allocation {
  alignas(westonrobot::ScoutBase) unsigned char object[sizeof(westonrobot::ScoutBase)];
  std::array<unsigned char, 64> canary;
};
int main() {
  Allocation allocation{};
  allocation.canary.fill(0xa5);
  auto *base = new (allocation.object) westonrobot::ScoutBase;
  // No Connect and no transport exists: SendRobotCmd sees can_connected_==false.
  base->SetMotionCommand(0.2, 0.3);
  base->Terminate();
  const auto changed = std::count_if(allocation.canary.begin(), allocation.canary.end(),
                                    [](unsigned char x){return x!=0xa5;});
  base->~ScoutBase();
  std::printf("old allocation=%zu; trailing canary bytes overwritten=%ld\n",
              sizeof(westonrobot::ScoutBase), static_cast<long>(changed));
  return changed ? 1 : 0;
}
