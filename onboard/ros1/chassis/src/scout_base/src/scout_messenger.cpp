/*
 * scout_messenger.cpp
 *
 * Created on: Apr 26, 2019 22:14
 * Description:
 *
 * Copyright (c) 2019 Ruixiang Du (rdu)
 */

#include "scout_base/scout_messenger.hpp"

#include "scout_msgs/ScoutStatus.h"
#include <stdexcept>
#include <limits>

namespace westonrobot
{
  ScoutROSMessenger::ScoutROSMessenger(ros::NodeHandle *nh)
      : scout_(nullptr), nh_(nh) {}

  ScoutROSMessenger::ScoutROSMessenger(ScoutBase *scout, ros::NodeHandle *nh)
      : scout_(scout), nh_(nh) {}

  ScoutROSMessenger::~ScoutROSMessenger() {
    hold_endpoint_.reset();
    hold_.reset();
    std::string ignored;
    (void)write_zero(hold_robot_id_, ignored);
    if (!simulated_robot_ && scout_ != nullptr) scout_->Terminate();
  }

  bool ScoutROSMessenger::write_zero(const std::string &, std::string &error) {
    try {
      if (!simulated_robot_ && scout_ == nullptr)
        throw std::runtime_error("Scout device unavailable");
      HoldZero();
      return true;
    } catch (const std::exception &failure) {
      error = failure.what();
      return false;
    }
  }

  bool ScoutROSMessenger::latest(const std::string &,
                                xgc2::chassis_hold::Feedback &sample) {
    if (!simulated_robot_) {
      ScoutState state;
      std::chrono::steady_clock::time_point received_at;
      std::int64_t stamp_ns = 0;
      auto *tracked = dynamic_cast<MotionTrackedScoutBase *>(scout_);
      const bool valid = tracked != nullptr && tracked->GetMotionState(state, received_at, stamp_ns);
      const auto age = std::chrono::steady_clock::now() - received_at;
      // Missing telemetry is unknown, not rest. Explicit nonfinite evidence
      // also clears an earlier stopped stage and breaks its dwell continuity.
      if (!valid || age < decltype(age)::zero() || age > std::chrono::milliseconds(200)) {
        hold_feedback_available_ = false;
        const double unknown = std::numeric_limits<double>::quiet_NaN();
        sample = {unknown, unknown, hold_->now()};
        return true;
      }
      hold_feedback_ = {state.linear_velocity, state.angular_velocity, stamp_ns};
      hold_feedback_available_ = true;
    }
    sample = hold_feedback_;
    return hold_feedback_available_;
  }

  void ScoutROSMessenger::ControlTick() {
    if (hold_ && hold_->tick().failed != 0)
      throw std::runtime_error("Scout HOLD zero output failed");
  }

  void ScoutROSMessenger::HoldZero() {
    if (!simulated_robot_ && scout_ != nullptr) {
      scout_->SetMotionCommand(0.0, 0.0);
    } else {
      std::lock_guard<std::mutex> guard(twist_mutex_);
      current_twist_ = geometry_msgs::Twist();
    }
    ROS_DEBUG("Scout motion command written: linear=0 angular=0");
  }

  void ScoutROSMessenger::SetupSubscription()
  {
    ros::NodeHandle private_node("~");
    if (!private_node.getParam("hold_robot_id", hold_robot_id_) ||
        !xgc2::chassis_hold::valid_robot_id(hold_robot_id_))
      throw std::invalid_argument("valid hold_robot_id required");
    xgc2::chassis_hold::HoldOptions options;
    options.robots = {hold_robot_id_};
    options.domain.clock = [] { return ros::Time::now().toNSec(); };
    if (auto *tracked = dynamic_cast<MotionTrackedScoutBase *>(scout_))
      tracked->SetMotionFeedbackClock(options.domain.clock);
    private_node.param<bool>("hold_boot_held", options.domain.boot_held, false);
    options.feedback = this;
    xgc2::chassis_hold::UdpEndpointOptions udp_options;
    int hold_port;
    private_node.param<int>("hold_port", hold_port, 19530);
    if (hold_port < 1 || hold_port > 65535)
      throw std::invalid_argument("hold_port must be in 1..65535");
    udp_options.port = static_cast<std::uint16_t>(hold_port);
    private_node.param<std::string>("hold_key_file", udp_options.key_file,
                                   "/etc/xgc2/chassis-hold.key");
    bool hold_required;
    private_node.param<bool>("hold_required", hold_required, true);
    // Warm the existing native SDK's one command worker before admission.
    HoldZero();
    hold_ = std::make_unique<xgc2::chassis_hold::ChassisHold>(std::move(options),
        static_cast<xgc2::chassis_hold::ZeroSink &>(*this));
    try {
      hold_endpoint_ = std::make_unique<xgc2::chassis_hold::UdpEndpoint>(
          hold_->service(), std::move(udp_options));
    } catch (const std::exception &error) {
      if (hold_required) throw;
      ROS_ERROR("HOLD unavailable; driving without HOLD: %s", error.what());
      hold_.reset();
    }
    status_publisher_ =
        nh_->advertise<scout_msgs::ScoutStatus>("/scout_status", 10);

    // cmd subscriber
    motion_cmd_subscriber_ = nh_->subscribe(
        "/cmd_vel", 5, &ScoutROSMessenger::TwistCmdCallback, this);
    light_cmd_subscriber_ = nh_->subscribe<scout_msgs::ScoutLightCmd>(
        "/scout_light_control", 5, &ScoutROSMessenger::LightCmdCallback, this);
  }

  void ScoutROSMessenger::TwistCmdCallback(
      const ros::MessageEvent<geometry_msgs::Twist const> &event)
  {
    if (hold_ && !hold_->admit(hold_robot_id_, event.getReceiptTime().toNSec())) {
      ROS_DEBUG("Scout motion command dropped: held=%s receipt_ns=%llu",
                hold_->domain().state({hold_robot_id_}).robots[0].held ? "true" : "false",
                static_cast<unsigned long long>(event.getReceiptTime().toNSec()));
      return;
    }
    const auto &msg = event.getMessage();
    if (!simulated_robot_)
    {
      scout_->SetMotionCommand(msg->linear.x, msg->angular.z);
    }
    else
    {
      std::lock_guard<std::mutex> guard(twist_mutex_);
      current_twist_ = *msg.get();
    }
    ROS_DEBUG("Scout motion command written: linear=%.9g angular=%.9g",
              msg->linear.x, msg->angular.z);
  }

  void ScoutROSMessenger::GetCurrentMotionCmdForSim(double &linear,
                                                    double &angular)
  {
    std::lock_guard<std::mutex> guard(twist_mutex_);
    linear = current_twist_.linear.x;
    angular = current_twist_.angular.z;
  }

  void ScoutROSMessenger::LightCmdCallback(
      const scout_msgs::ScoutLightCmd::ConstPtr &msg)
  {
    if (!simulated_robot_)
    {
      if (msg->enable_cmd_light_control)
      {
        ScoutLightCmd cmd;

        switch (msg->front_mode)
        {
        case scout_msgs::ScoutLightCmd::LIGHT_CONST_OFF:
        {
          cmd.front_mode = ScoutLightCmd::LightMode::CONST_OFF;
          break;
        }
        case scout_msgs::ScoutLightCmd::LIGHT_CONST_ON:
        {
          cmd.front_mode = ScoutLightCmd::LightMode::CONST_ON;
          break;
        }
        case scout_msgs::ScoutLightCmd::LIGHT_BREATH:
        {
          cmd.front_mode = ScoutLightCmd::LightMode::BREATH;
          break;
        }
        case scout_msgs::ScoutLightCmd::LIGHT_CUSTOM:
        {
          cmd.front_mode = ScoutLightCmd::LightMode::CUSTOM;
          cmd.front_custom_value = msg->front_custom_value;
          break;
        }
        }

        switch (msg->rear_mode)
        {
        case scout_msgs::ScoutLightCmd::LIGHT_CONST_OFF:
        {
          cmd.rear_mode = ScoutLightCmd::LightMode::CONST_OFF;
          break;
        }
        case scout_msgs::ScoutLightCmd::LIGHT_CONST_ON:
        {
          cmd.rear_mode = ScoutLightCmd::LightMode::CONST_ON;
          break;
        }
        case scout_msgs::ScoutLightCmd::LIGHT_BREATH:
        {
          cmd.rear_mode = ScoutLightCmd::LightMode::BREATH;
          break;
        }
        case scout_msgs::ScoutLightCmd::LIGHT_CUSTOM:
        {
          cmd.rear_mode = ScoutLightCmd::LightMode::CUSTOM;
          cmd.rear_custom_value = msg->rear_custom_value;
          break;
        }
        }

        scout_->SetLightCommand(cmd);
      }
      else
      {
        scout_->DisableLightCmdControl();
      }
    }
    else
    {
      std::cout << "simulated robot received light control cmd" << std::endl;
    }
  }

  void ScoutROSMessenger::PublishStateToROS()
  {
    current_time_ = ros::Time::now();

    static bool init_run = true;
    if (init_run)
    {
      last_time_ = current_time_;
      init_run = false;
      return;
    }

    auto state = scout_->GetScoutState();

    // publish scout state message
    scout_msgs::ScoutStatus status_msg;

    status_msg.header.stamp = current_time_;

    status_msg.linear_velocity = state.linear_velocity;
    status_msg.angular_velocity = state.angular_velocity;

    status_msg.base_state = state.base_state;
    status_msg.control_mode = state.control_mode;
    status_msg.fault_code = state.fault_code;
    status_msg.battery_voltage = state.battery_voltage;

    for (int i = 0; i < 4; ++i)
    {
      status_msg.motor_states[i].current = state.actuator_states[i].motor_current;
      status_msg.motor_states[i].rpm = state.actuator_states[i].motor_rpm;
      status_msg.motor_states[i].temperature = state.actuator_states[i].motor_temperature;
    }

    status_msg.light_control_enabled = state.light_control_enabled;
    status_msg.front_light_state.mode = state.front_light_state.mode;
    status_msg.front_light_state.custom_value =
        state.front_light_state.custom_value;
    status_msg.rear_light_state.mode = state.rear_light_state.mode;
    status_msg.rear_light_state.custom_value =
        state.rear_light_state.custom_value;
    status_publisher_.publish(status_msg);

    last_time_ = current_time_;
  }

  void ScoutROSMessenger::PublishSimStateToROS(double linear, double angular)
  {
    current_time_ = ros::Time::now();
    hold_feedback_ = {linear, angular,
                      static_cast<xgc2::chassis_hold::TimeNs>(current_time_.toNSec())};
    hold_feedback_available_ = true;

    static bool init_run = true;
    if (init_run)
    {
      last_time_ = current_time_;
      init_run = false;
      return;
    }

    // publish scout state message
    scout_msgs::ScoutStatus status_msg;

    status_msg.header.stamp = current_time_;

    status_msg.linear_velocity = linear;
    status_msg.angular_velocity = angular;

    status_msg.base_state = 0x00;
    status_msg.control_mode = 0x01;
    status_msg.fault_code = 0x00;
    status_msg.battery_voltage = 29.5;

    // for (int i = 0; i < 4; ++i)
    // {
    //     status_msg.motor_states[i].current = state.motor_states[i].current;
    //     status_msg.motor_states[i].rpm = state.motor_states[i].rpm;
    //     status_msg.motor_states[i].temperature =
    //     state.motor_states[i].temperature;
    // }

    status_msg.light_control_enabled = false;
    // status_msg.front_light_state.mode = state.front_light_state.mode;
    // status_msg.front_light_state.custom_value =
    // state.front_light_state.custom_value; status_msg.rear_light_state.mode =
    // state.rear_light_state.mode; status_msg.rear_light_state.custom_value =
    // state.front_light_state.custom_value;

    status_publisher_.publish(status_msg);

    last_time_ = current_time_;
  }
} // namespace westonrobot
