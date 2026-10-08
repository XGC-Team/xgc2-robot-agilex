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
#include <xgc2/chassis_hold/provider.hpp>

namespace westonrobot
{
class ScoutROSMessenger
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

    void TwistCmdCallback(const geometry_msgs::Twist::ConstPtr &msg);
    void LightCmdCallback(const scout_msgs::ScoutLightCmd::ConstPtr &msg);
    void HoldZero();
    static bool ApplyHoldZero(void *self, std::size_t robot) noexcept;
    std::unique_ptr<xgc2::chassis_hold::Provider> hold_provider_;
};
} // namespace westonrobot

#endif /* SCOUT_MESSENGER_HPP */
