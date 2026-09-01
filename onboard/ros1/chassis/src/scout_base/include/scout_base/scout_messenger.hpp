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

#include <ros/ros.h>
#include <geometry_msgs/Twist.h>

#include "scout_msgs/ScoutLightCmd.h"
#include "ugv_sdk/scout/scout_base.hpp"
#include "xgc_chassis_hold/udp.hpp"

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
    static void HoldZeroThunk(void *self);

    xgc_chassis_hold::Gate hold_gate_;
};
} // namespace westonrobot

#endif /* SCOUT_MESSENGER_HPP */
