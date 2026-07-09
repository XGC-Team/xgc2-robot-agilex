# AgileX Boot Autostart

This note summarizes the boot-time services recovered from the AgileX onboard
computer. The vehicle uses ROS Melodic and systemd services under
`/etc/systemd/system`.

## Service Overview

There are three vehicle-runtime services plus one ROS master service:

```text
roscore.service
handsfree_imu.service
turn_on_wheeltec_robot.service
swarm_ros_bridge.service
```

`roscore.service` starts ROS master. The other three services start the IMU
driver, Scout base driver, and XGC/QGC bridge.

The service files and scripts are stored in:

```text
/home/agilex/agilex-auto-launch/
```

The ROS workspaces used by the scripts are:

```text
/home/agilex/catkin_ws
/home/agilex/swarm_ros_bridge_ws
```

## roscore.service

```ini
[Service]
Type=simple
ExecStart=/bin/bash -i -c "source /opt/ros/melodic/setup.bash; roscore"
Restart=always
RestartSec=1
```

This service starts ROS master. The other runtime scripts wait with fixed
`sleep` delays instead of declaring explicit systemd `After=` dependencies.

## handsfree_imu.service

Service entry:

```ini
[Service]
Type=simple
ExecStart=/home/agilex/agilex-auto-launch/handsfree_imu.sh
Restart=always
RestartSec=3
```

Script:

```bash
source /opt/ros/melodic/setup.bash
source /home/agilex/catkin_ws/devel/setup.bash

sleep 9
roslaunch imu_launch imu_msg.launch
```

The productized package removes the compatibility-only `imu_launch` wrapper.
For packaged deployments, use:

```bash
roslaunch agilex_onboard_imu imu_msg.launch
```

The one-time `/dev/imu` udev setup script is installed as:

```bash
sudo /opt/ros/melodic/share/agilex_onboard_imu/scripts/install_imu_udev_rule.sh
```

Launch file:

```xml
<launch>
  <node pkg="serial_imu" name="HI226" type="serial_imu" />
  <node pkg="serial_imu" name="subscriber_HI226" type="imu_subscriber"
        output="screen" />
</launch>
```

The `serial_imu` node opens:

```text
/dev/imu
```

at:

```text
115200 baud
```

`/dev/imu` is created by a udev rule for a CP210x USB-serial device:

```bash
KERNEL=="ttyUSB*", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE:="0666", GROUP:="dialout", SYMLINK+="imu"
```

The node parses binary IMU packets, converts the decoded values to
`sensor_msgs/Imu`, and publishes:

```text
/imu/data_raw
```

The serial read loop runs at `500 Hz`, but actual message rate depends on the
IMU output frame rate. The bridge limits forwarded IMU messages to `50 Hz`.

## turn_on_wheeltec_robot.service

Service entry:

```ini
[Service]
Type=simple
ExecStart=/home/agilex/agilex-auto-launch/turn_on_wheeltec_robot.sh
Restart=always
RestartSec=3
```

Script:

```bash
source /opt/ros/melodic/setup.bash
source /home/agilex/catkin_ws/devel/setup.bash

sleep 5
ip link set can0 up type can bitrate 500000
sleep 6

roslaunch scout_bringup scout_minimal.launch
```

Launch chain:

```text
scout_bringup scout_minimal.launch
  -> scout_base/launch/scout_mini_base.launch
     -> scout_base_node
  -> scout_description/launch/description.launch
```

The base driver uses:

```text
CAN interface: can0
CAN bitrate:   500000
```

The `scout_base_node` subscribes:

```text
/cmd_vel
```

and sends motion commands to the Scout base through `can0`.

## swarm_ros_bridge.service

Service entry:

```ini
[Service]
Type=simple
ExecStart=/home/agilex/agilex-auto-launch/swarm_ros_bridge.sh
Restart=always
RestartSec=3
```

Script:

```bash
source /opt/ros/melodic/setup.bash
source /home/agilex/swarm_ros_bridge_ws/devel/setup.bash

sleep 3
roslaunch swarm_ros_bridge test.launch
```

Launch file:

```xml
<launch>
  <node pkg="swarm_ros_bridge" type="bridge_node" name="swarm_bridge_node"
        output="screen">
    <rosparam command="load"
              file="$(find swarm_ros_bridge)/config/ros_topics.yaml" />
  </node>
</launch>
```

The effective bridge config is:

```yaml
IP:
  self: '*'
  qgc: 192.168.51.150
  test_local: 127.0.0.1

send_topics:
- topic_name: /imu/data_raw
  msg_type: sensor_msgs/Imu
  max_freq: 50
  srcIP: self
  srcPort: 3001

recv_topics:
- topic_name: /cmd_vel
  msg_type: geometry_msgs/Twist
  srcIP: qgc
  srcPort: 3001
```

The bridge uses ZeroMQ PUB/SUB sockets:

```text
Send path:
  ROS /imu/data_raw
    -> swarm_bridge_node subscribes
    -> ZMQ PUB bind tcp://*:3001
    -> QGC receives IMU

Receive path:
  QGC publishes Twist on tcp://192.168.51.150:3001
    -> swarm_bridge_node ZMQ SUB connects
    -> ROS /cmd_vel
    -> scout_base_node
    -> can0
    -> Scout base
```

## End-To-End Runtime Chain

```text
IMU feedback:
  HI226 IMU
    -> /dev/imu
    -> serial_imu
    -> /imu/data_raw
    -> swarm_bridge_node
    -> QGC

Velocity command:
  QGC
    -> swarm_bridge_node
    -> /cmd_vel
    -> scout_base_node
    -> can0
    -> Scout base
```

## Notes

- The service files do not declare explicit ordering such as `After=roscore.service`.
  Startup sequencing is currently handled by fixed `sleep` delays.
- `imu_subscriber` appears to be a debug helper. It echoes `/IMU_data`, while the
  active IMU driver publishes `/imu/data_raw`.
- `agilex-auto-launch/ros_topics.yaml` may differ from the effective bridge
  config. The launch file loads `swarm_ros_bridge_ws/src/swarm_ros_bridge/config/ros_topics.yaml`.
