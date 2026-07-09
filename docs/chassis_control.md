# AgileX Chassis Control

This note summarizes the recovered Scout/Wheeltec chassis startup chain,
external ROS interfaces, feedback messages, CAN bus path, and current code
limitations.

## Startup Chain

The chassis driver is started by:

```text
turn_on_wheeltec_robot.service
```

The service runs:

```bash
/home/agilex/agilex-auto-launch/turn_on_wheeltec_robot.sh
```

The script performs the following sequence:

```bash
source /opt/ros/melodic/setup.bash
source /home/agilex/catkin_ws/devel/setup.bash

sleep 5

ip link set can0 up type can bitrate 500000

sleep 6 # waiting for roscore

roslaunch scout_bringup scout_minimal.launch
```

`ip link set can0 up type can bitrate 500000` brings up the Linux SocketCAN
interface `can0` as a CAN bus interface at `500 kbit/s`. The Scout base driver
then uses this interface to communicate with the chassis controller.

The ROS launch path is:

```text
scout_bringup/scout_minimal.launch
  -> scout_base/launch/scout_mini_base.launch
      -> scout_base_node
  -> scout_description/launch/description.launch
      -> robot_description
      -> joint_state_publisher
      -> robot_state_publisher
```

## Related Packages

The chassis control path uses four ROS packages and two lower-level SDK/IO
packages.

| Package | Role | Directly required for motion |
| --- | --- | --- |
| `scout_bringup` | Launch entry point. Provides `scout_minimal.launch` and wires the base driver and robot description together. | Yes |
| `scout_base` | Main ROS chassis driver. Starts `scout_base_node`, subscribes `/cmd_vel`, publishes `/scout_status`, and calls the SDK. | Yes |
| `scout_msgs` | Custom ROS messages for chassis status and light control, such as `ScoutStatus` and `ScoutLightCmd`. | Yes |
| `scout_description` | URDF/xacro robot model for RViz, `robot_description`, `robot_state_publisher`, and fixed sensor/body frames. | No, not for basic motion |
| `ugv_sdk` | AgileX/Scout protocol implementation. Encodes velocity commands to CAN frames and decodes chassis feedback. | Yes |
| `wrp_io` | Low-level IO support used by the SDK, including SocketCAN/serial transport wrappers. | Yes |

The practical dependency chain is:

```text
scout_bringup
  -> scout_base
  -> scout_msgs
  -> ugv_sdk
  -> wrp_io
  -> can0
  -> chassis controller
```

`scout_description` runs in parallel with the base driver. It is useful for
visualization, TF structure, and sensor extrinsics, but it does not participate
in `/cmd_vel -> CAN -> chassis` motion command transmission.

## Role

This service is the chassis hardware access layer. It is not a navigation,
planning, or autonomy node.

Its main job is:

```text
/cmd_vel
  -> scout_base_node
  -> ugv_sdk
  -> can0
  -> Scout chassis controller
  -> motor drivers
```

It also decodes chassis feedback from CAN and republishes it to ROS.

## ROS Control Interfaces

### Motion Command

Topic:

```text
/cmd_vel
```

Type:

```text
geometry_msgs/Twist
```

The recovered driver only uses:

```text
linear.x
angular.z
```

Meaning:

```text
linear.x   target forward/backward velocity, m/s
angular.z  target yaw angular velocity, rad/s
```

The other `Twist` fields are ignored by this chassis path:

```text
linear.y
linear.z
angular.x
angular.y
```

This is a body-level velocity interface. It does not expose independent wheel
velocity, wheel current, wheel torque, or acceleration command interfaces.

### Light Command

Topic:

```text
/scout_light_control
```

Type:

```text
scout_msgs/ScoutLightCmd
```

Message definition:

```msg
uint8 LIGHT_CONST_OFF = 0
uint8 LIGHT_CONST_ON = 1
uint8 LIGHT_BREATH = 2
uint8 LIGHT_CUSTOM = 3

bool enable_cmd_light_control
uint8 front_mode
uint8 front_custom_value
uint8 rear_mode
uint8 rear_custom_value
```

This controls the front and rear light modes.

## Command Limits

The ROS callback passes `linear.x` and `angular.z` into the SDK:

```cpp
scout_->SetMotionCommand(msg->linear.x, msg->angular.z);
```

The current recovered SDK clamps motion commands before sending them to CAN:

```text
linear.x   [-1.5, 1.5] m/s
angular.z  [-0.5235, 0.5235] rad/s
```

Important distinction:

```text
ROS topic layer:    /cmd_vel can carry larger values.
Current SDK layer:  larger values are clamped before CAN transmission.
CAN protocol layer: the raw field is int16 scaled by 1000, so the protocol
                    field itself is not the same as this SDK limit.
Firmware layer:     the real accepted range still depends on the chassis
                    firmware and vehicle model.
```

Therefore, with the current `scout_base + ugv_sdk` code, the largest yaw rate
that will be sent to the chassis is `±0.5235 rad/s`, even if a larger
`/cmd_vel.angular.z` value is published.

## Feedback Interfaces

### Scout Status

Topic:

```text
/scout_status
```

Type:

```text
scout_msgs/ScoutStatus
```

Message definition:

```msg
Header header

int8 MOTOR_ID_FRONT_RIGHT = 0
int8 MOTOR_ID_FRONT_LEFT = 1
int8 MOTOR_ID_REAR_RIGHT = 2
int8 MOTOR_ID_REAR_LEFT = 3

int8 LIGHT_ID_FRONT = 0
int8 LIGHT_ID_REAR = 1

float64 linear_velocity
float64 angular_velocity

uint8 base_state
uint8 control_mode
uint16 fault_code
float64 battery_voltage

ScoutMotorState[4] motor_states

bool light_control_enabled
ScoutLightState front_light_state
ScoutLightState rear_light_state
```

Nested motor state:

```msg
float64 current
float64 rpm
float64 temperature
```

Nested light state:

```msg
uint8 mode
uint8 custom_value
```

Practical field meanings:

```text
linear_velocity           chassis feedback linear velocity
angular_velocity          chassis feedback yaw angular velocity
base_state                base state, such as normal, estop, or exception
control_mode              active control mode
fault_code                chassis fault bitfield/code
battery_voltage           battery voltage
motor_states[0..3]        four motor feedback states
front_light_state         front light feedback
rear_light_state          rear light feedback
```

Known `control_mode` values from the SDK protocol:

```text
0x00  RC control
0x01  CAN command control
0x02  UART command control
```

Because this vehicle uses `can0`, ROS command mode should normally report:

```text
control_mode = 1
```

Known fault bits from the recovered protocol header:

```text
0x01  battery low error
0x02  battery low warning
0x04  RC signal loss
```

### Odometry and TF

The driver advertises an odometry publisher using the configured odometry topic
name, usually:

```text
/odom
```

However, in the recovered `scout_messenger.cpp`, both odometry publishing and
TF broadcasting are commented out:

```cpp
// tf_broadcaster_.sendTransform(tf_msg);
// odom_publisher_.publish(odom_msg);
```

So the current recovered code should be treated as:

```text
Motion control: available
Scout status:   available
Odometry:       not effectively published by this recovered code
TF:             not effectively published by this recovered code
```

This is an important limitation if navigation is expected to work.

## CAN Interfaces

The recovered SDK uses the AgileX protocol over SocketCAN.

Important CAN IDs:

```text
0x111  motion command
0x121  light command
0x131  park command
0x421  control mode select
0x441  state reset

0x211  system state feedback
0x221  motion state feedback
0x231  light state feedback
0x241  RC state feedback
0x251  actuator 1 high-speed state
0x252  actuator 2 high-speed state
0x253  actuator 3 high-speed state
0x254  actuator 4 high-speed state
0x261  actuator 1 low-speed state
0x262  actuator 2 low-speed state
0x263  actuator 3 low-speed state
0x264  actuator 4 low-speed state
0x311  odometry feedback
```

Motion command sending path:

```text
scout_base_node
  -> ScoutBase::SetMotionCommand(linear, angular)
  -> clamp command values
  -> ScoutBase::SendRobotCmd()
  -> EnableCommandedMode()
  -> CAN 0x421, CTRL_MODE_CMD_CAN
  -> SendMotionCmd()
  -> CAN 0x111, linear/angular velocity command
```

Feedback path:

```text
Scout chassis controller
  -> CAN status frames
  -> ugv_sdk parser
  -> ScoutState
  -> scout_msgs/ScoutStatus
  -> /scout_status
```

## Capability Summary

Available through the recovered ROS driver:

```text
body-level velocity control through /cmd_vel
front/rear light control through /scout_light_control
chassis status feedback through /scout_status
four motor current/rpm/temperature feedback through /scout_status
```

Not exposed by the recovered ROS driver:

```text
independent four-wheel velocity command
independent wheel current or torque command
direct acceleration command
usable odometry publication in the current recovered code
usable TF publication in the current recovered code
```

If acceleration limiting is required, it should be implemented upstream of
`/cmd_vel` as a velocity ramp or command smoother.
