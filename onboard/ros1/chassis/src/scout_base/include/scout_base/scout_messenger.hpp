/* 
 * scout_messenger.hpp
 * 
 * Created on: Jun 14, 2019 10:24
 * Description: 
 * 
 * Copyright (c) 2019 Ruixiang Du (rdu)
 */

#ifndef SCOUT_MESSENGER_HPP
#define SCOUT_MESSENGER_HPP

#include <string>
#include <mutex>
#include <memory>

#include <ros/ros.h>
#include <geometry_msgs/Twist.h>

#include "scout_msgs/ScoutLightCmd.h"
#include "ugv_sdk/scout/scout_base.hpp"
#include <xgc2/chassis_hold/chassis_hold.hpp>
#include <xgc2/chassis_hold/udp_endpoint.hpp>

namespace westonrobot
{
class ScoutROSMessenger : private xgc2::chassis_hold::ZeroSink,
                          private xgc2::chassis_hold::FeedbackSource
{
public:
    explicit ScoutROSMessenger(ros::NodeHandle *nh);
    ScoutROSMessenger(ScoutBase *scout, ros::NodeHandle *nh);
    ~ScoutROSMessenger();

    bool simulated_robot_ = false;
    int sim_control_rate_ = 50;

    void SetupSubscription();
    void ControlTick();

    void PublishStateToROS();
    void PublishSimStateToROS(double linear, double angular);

    void GetCurrentMotionCmdForSim(double &linear, double &angular);

private:
    ScoutBase *scout_;
    ros::NodeHandle *nh_;

    std::mutex twist_mutex_;
    geometry_msgs::Twist current_twist_;

    ros::Publisher status_publisher_;
    ros::Subscriber motion_cmd_subscriber_;
    ros::Subscriber light_cmd_subscriber_;

    ros::Time last_time_;
    ros::Time current_time_;

    void TwistCmdCallback(const ros::MessageEvent<geometry_msgs::Twist const> &event);
    void LightCmdCallback(const scout_msgs::ScoutLightCmd::ConstPtr &msg);
    void HoldZero();
    bool write_zero(const std::string &robot_id, std::string &error) override;
    bool latest(const std::string &robot_id, xgc2::chassis_hold::Feedback &sample) override;
    std::string hold_robot_id_;
    xgc2::chassis_hold::Feedback hold_feedback_;
    bool hold_feedback_available_ = false;
    std::unique_ptr<xgc2::chassis_hold::ChassisHold> hold_;
    std::unique_ptr<xgc2::chassis_hold::UdpEndpoint> hold_endpoint_;
};
} // namespace westonrobot

#endif /* SCOUT_MESSENGER_HPP */
