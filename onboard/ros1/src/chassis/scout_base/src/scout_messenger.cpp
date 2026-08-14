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

namespace westonrobot
{
  ScoutROSMessenger::ScoutROSMessenger(ros::NodeHandle *nh)
      : scout_(nullptr), nh_(nh) {}

  ScoutROSMessenger::ScoutROSMessenger(ScoutBase *scout, ros::NodeHandle *nh)
      : scout_(scout), nh_(nh) {}

  void ScoutROSMessenger::SetupSubscription()
  {
    status_publisher_ =
        nh_->advertise<scout_msgs::ScoutStatus>("/scout_status", 10);

    // cmd subscriber
    motion_cmd_subscriber_ = nh_->subscribe<geometry_msgs::Twist>(
        "/cmd_vel", 5, &ScoutROSMessenger::TwistCmdCallback, this);
    light_cmd_subscriber_ = nh_->subscribe<scout_msgs::ScoutLightCmd>(
        "/scout_light_control", 5, &ScoutROSMessenger::LightCmdCallback, this);
  }

  void ScoutROSMessenger::TwistCmdCallback(
      const geometry_msgs::Twist::ConstPtr &msg)
  {
    if (!simulated_robot_)
    {
      scout_->SetMotionCommand(msg->linear.x, msg->angular.z);
    }
    else
    {
      std::lock_guard<std::mutex> guard(twist_mutex_);
      current_twist_ = *msg.get();
    }
    // ROS_INFO("cmd received:%f, %f", msg->linear.x, msg->angular.z);
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
