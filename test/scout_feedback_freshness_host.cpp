// Production Scout messenger + SDK with in-memory CAN ingress only. Never Connect.
#include <scout_base/scout_messenger.hpp>
#include <ugv_sdk/scout/scout_base.hpp>

#include <fstream>
#include <iostream>
#include <stdexcept>

namespace {
// Invoke the existing protected virtual ingress through its base member pointer.
// Access is checked on MobileBase; dispatch still reaches ScoutBase's real parser.
struct MockCAN : westonrobot::MobileBase {
  static void receive(westonrobot::ScoutBase &base, can_frame &frame) {
    const auto callback = &MockCAN::ParseCANFrame;
    (base.*callback)(&frame);
  }
};

can_frame frame_for(const std::string &mode) {
  AgxMessage message{};
  message.type = mode == "system" ? AgxMsgSystemState : AgxMsgMotionState;
  if (mode == "moving") {
    message.body.motion_state_msg.state.linear_velocity.low_byte = 200;
    message.body.motion_state_msg.state.angular_velocity.high_byte = 1;
    message.body.motion_state_msg.state.angular_velocity.low_byte = 44;
  }
  can_frame frame{};
  EncodeCanFrame(&message, &frame);
  if (mode == "short") frame.can_dlc = 2;
  if (mode == "oversized") frame.can_dlc = CAN_MAX_DLEN + 1;
  if (mode == "unknown") frame.can_id = 0x7ff;
  return frame;
}

void check_sdk_receipts() {
  westonrobot::MotionTrackedScoutBase base;
  westonrobot::ScoutState state;
  std::chrono::steady_clock::time_point received;
  std::int64_t stamp_ns = 0;
  if (base.GetMotionState(state, received, stamp_ns))
    throw std::runtime_error("default state was valid motion feedback");
  for (const std::string mode : {"system", "short", "oversized", "unknown"}) {
    auto frame = frame_for(mode);
    MockCAN::receive(base, frame);
    if (base.GetMotionState(state, received, stamp_ns))
      throw std::runtime_error(mode + " created motion feedback");
  }
  const auto before = std::chrono::steady_clock::now();
  auto motion = frame_for("moving");
  MockCAN::receive(base, motion);
  if (!base.GetMotionState(state, received, stamp_ns) || state.linear_velocity != .2 ||
      state.angular_velocity != .3 || received < before ||
      received > std::chrono::steady_clock::now())
    throw std::runtime_error("decoded motion and receipt were not one snapshot");
  const auto original = received;
  const auto original_stamp = stamp_ns;
  for (const std::string mode : {"system", "short", "oversized", "unknown"}) {
    auto frame = frame_for(mode);
    MockCAN::receive(base, frame);
    base.GetScoutState();
    if (!base.GetMotionState(state, received, stamp_ns) || received != original || stamp_ns != original_stamp ||
        state.linear_velocity != .2 || state.angular_velocity != .3)
      throw std::runtime_error(mode + " refreshed or corrupted cached motion feedback");
  }
}
}  // namespace

int main(int argc, char **argv) {
  try {
    check_sdk_receipts();
    ros::init(argc, argv, "scout_feedback_freshness_host");
    ros::NodeHandle node, private_node("~");
    std::string mode_file;
    if (!private_node.getParam("fixture_mode_file", mode_file))
      throw std::runtime_error("fixture_mode_file required");
    bool plain_base = false;
    private_node.param("fixture_plain_base", plain_base, false);
    std::unique_ptr<westonrobot::ScoutBase> base;
    if (plain_base) base = std::make_unique<westonrobot::ScoutBase>();
    else base = std::make_unique<westonrobot::MotionTrackedScoutBase>();
    westonrobot::ScoutROSMessenger messenger(base.get(), &node);
    messenger.SetupSubscription();
    std::cout << "Actual Scout SDK/messenger; no Connect; in-memory mock CAN only" << std::endl;
    ros::WallRate rate(50);
    std::string previous_mode;
    for (int tick = 0; ros::ok() && tick < 2000; ++tick) {
      std::string mode;
      std::ifstream(mode_file) >> mode;
      if (!mode.empty() && mode != "absent" &&
          (mode != "once" || previous_mode != "once")) {
        auto frame = frame_for(mode);
        MockCAN::receive(*base, frame);
      }
      previous_mode = mode;
      messenger.ControlTick();
      messenger.PublishStateToROS();
      ros::spinOnce();
      rate.sleep();
    }
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << std::endl;
    return 1;
  }
}
