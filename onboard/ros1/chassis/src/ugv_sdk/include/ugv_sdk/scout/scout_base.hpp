/*
 * scout_base.hpp
 *
 * Created on: Jun 04, 2019 01:22
 * Description:
 *
 * Copyright (c) 2019 Ruixiang Du (rdu)
 */

#ifndef SCOUT_BASE_HPP
#define SCOUT_BASE_HPP

#include <string>
#include <cstdint>
#include <thread>
#include <mutex>
#include <functional>
#include <chrono>

#include "ugv_sdk/mobile_base.hpp"
#include "ugv_sdk/proto/agx_msg_parser.h"
#include "ugv_sdk/scout/scout_types.hpp"

namespace westonrobot {
class ScoutBase : public MobileBase {
 public:
  ScoutBase(bool is_scout_mini = false)
    : MobileBase(),is_scout_mini_(is_scout_mini){};
  // Stop the worker before its virtual target and command state are destroyed.
  ~ScoutBase() override { Terminate(); }

  // get robot state
  ScoutState GetScoutState();

  void EnableCommandedMode();

  // motion control
  void SetMotionCommand(double linear_vel, double angular_vel);

  // light control
  void SetLightCommand(const ScoutLightCmd &cmd);
  void DisableLightCmdControl();

 private:
  friend class MotionTrackedScoutBase;
  bool is_scout_mini_ = false;
  // cmd/status update related variables
  std::mutex scout_state_mutex_;
  std::mutex motion_cmd_mutex_;

  ScoutState scout_state_;
  ScoutMotionCmd current_motion_cmd_;

  // internal functions
  void SendMotionCmd(uint8_t count);
  void SendLightCmd(const ScoutLightCmd &cmd, uint8_t count);


  void SendRobotCmd() override;
  void ParseCANFrame(can_frame *rx_frame) override;

  void NewStatusMsgReceivedCallback(const AgxMessage &msg);
  static void UpdateScoutState(const AgxMessage &status_msg, ScoutState &state);
};

// Explicit opt-in type: the original ScoutBase object layout and virtual table
// remain unchanged for clients already linked to libugv_sdk.so.
class MotionTrackedScoutBase final : public ScoutBase {
 public:
  explicit MotionTrackedScoutBase(bool is_scout_mini = false);
  ~MotionTrackedScoutBase() override;

  // Nanoseconds on the consumer's feedback clock. Changing clocks invalidates
  // cached evidence; only a subsequent complete motion frame makes it valid.
  void SetMotionFeedbackClock(std::function<std::int64_t()> clock);
  bool GetMotionState(ScoutState &state,
                      std::chrono::steady_clock::time_point &received_at,
                      std::int64_t &measurement_stamp_ns);

 private:
  std::mutex feedback_mutex_;
  std::chrono::steady_clock::time_point motion_state_received_at_{};
  std::int64_t motion_state_stamp_ns_ = 0;
  std::function<std::int64_t()> feedback_clock_;
  bool motion_state_valid_ = false;

  void ParseCANFrame(can_frame *rx_frame) override;
};
}  // namespace westonrobot

#endif /* SCOUT_BASE_HPP */
