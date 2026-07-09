# AgileX IMU Autostart

This note summarizes the AgileX onboard IMU startup chain, communication
principle, ROS topic path, and effective data rate.

## Startup Chain

The IMU is started by `handsfree_imu.service`:

```ini
[Unit]
Description=handsfree_imu autostart shdaemon

[Service]
Type=simple
ExecStart=/home/agilex/agilex-auto-launch/handsfree_imu.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

The service runs:

```bash
/home/agilex/agilex-auto-launch/handsfree_imu.sh
```

The script sets up the ROS Melodic environment and starts the IMU launch file:

```bash
source /opt/ros/melodic/setup.bash
source /home/agilex/catkin_ws/devel/setup.bash

sleep 9

roslaunch imu_launch imu_msg.launch
```

In the productized ROS package, the compatibility-only `imu_launch` wrapper is
not kept. Use the real IMU package directly:

```bash
roslaunch agilex_onboard_imu imu_msg.launch
```

The productized IMU package also installs the one-time udev setup script:

```bash
sudo /opt/ros/melodic/share/agilex_onboard_imu/scripts/install_imu_udev_rule.sh
```

The launch file starts two nodes:

```xml
<launch>
  <node pkg="serial_imu" name="HI226" type="serial_imu" />
  <node pkg="serial_imu" name="subscriber_HI226" type="imu_subscriber"
        output="screen" />
</launch>
```

The active runtime node is `serial_imu`. `imu_subscriber` appears to be a debug
helper and does not participate in the main control/bridge path.

`handsfree_imu.sh` is only a startup wrapper. It does not create `/dev/imu`,
configure udev, read the serial port, or decode IMU packets. Those runtime
tasks are handled by `serial_imu`.

## Hardware Device

The IMU is accessed through:

```text
/dev/imu
```

The source code opens the port with:

```text
baudrate: 115200
timeout:  100 ms
```

`/dev/imu` is created by a udev rule for a CP210x USB-to-UART device:

```bash
KERNEL=="ttyUSB*", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE:="0666", GROUP:="dialout", SYMLINK+="imu"
```

The setup script for that rule is:

```bash
catkin_ws/src/imu/initenv.sh
```

`initenv.sh` is a one-time deployment/init script, not part of the boot-time
systemd chain. It is expected to be run manually when setting up the onboard
computer:

```bash
cd /home/agilex/catkin_ws/src/imu
sudo bash initenv.sh
```

After the rule is installed, udev creates `/dev/imu` automatically on boot or
when the matching USB-serial device is plugged in.

## Protocol Principle

`serial_imu` continuously reads bytes from `/dev/imu` and feeds each byte into a
packet decoder state machine.

The binary frame format is:

```text
0x5A
0xA5
payload_len_low
payload_len_high
crc_low
crc_high
payload...
```

The decoder:

1. Waits for `0x5A`.
2. Checks the command/type byte `0xA5`.
3. Reads the payload length.
4. Reads the received CRC16.
5. Reads the payload.
6. Calculates CRC16 over header and payload.
7. Accepts the packet only when CRC matches.

The payload is a tagged field stream. Important tags include:

```text
0x90  device ID
0xA0  acceleration
0xB0  gyroscope
0xB1  gyroscope variant
0xC0  magnetometer
0xD0  Euler angles
0xD1  quaternion
0x91  IMUSOL full solution
0x62  GWSOL gateway/multi-IMU solution
```

Decoded data is stored in:

```text
receive_imusol_packet_t
```

The fields include:

```text
id
times
acc[3]
gyr[3]
mag[3]
eul[3]
quat[4]
```

## ROS Message Conversion

The node publishes `sensor_msgs/Imu`.

Topic:

```text
/imu/data_raw
```

Frame:

```text
imu_link
```

Conversion:

```text
orientation.x = quat[1]
orientation.y = quat[2]
orientation.z = quat[3]
orientation.w = quat[0]

angular_velocity.x = gyr[0] * 0.01745329
angular_velocity.y = gyr[1] * 0.01745329
angular_velocity.z = gyr[2] * 0.01745329

linear_acceleration.x = acc[0] * 9.8
linear_acceleration.y = acc[1] * 9.8
linear_acceleration.z = acc[2] * 9.8
```

So:

```text
gyro: deg/s -> rad/s
acc:  G     -> m/s^2
quat: IMU output order WXYZ -> ROS order XYZW
```

The code does not fill covariance fields, and it does not publish magnetometer
or Euler angles as separate ROS topics.

## Communication Chain

Local IMU publishing path:

```text
HI226 IMU
  -> USB-UART device
  -> /dev/imu
  -> serial_imu
  -> sensor_msgs/Imu
  -> /imu/data_raw
```

Responsibility split:

```text
initenv.sh
  -> installs /etc/udev/rules.d/imu.rules once
  -> enables stable /dev/imu naming

handsfree_imu.sh
  -> sources ROS environments
  -> waits for ROS master
  -> launches imu_launch/imu_msg.launch on the recovered vehicle
     or agilex_onboard_imu/imu_msg.launch in the productized package

serial_imu
  -> opens /dev/imu
  -> reads serial bytes
  -> decodes IMU packets
  -> publishes /imu/data_raw
```

Bridge path to QGC/XGC:

```text
/imu/data_raw
  -> swarm_bridge_node
  -> ZMQ PUB tcp://*:3001
  -> QGC/XGC receives IMU data
```

The bridge config limits this topic:

```yaml
send_topics:
- topic_name: /imu/data_raw
  msg_type: sensor_msgs/Imu
  max_freq: 50
  srcIP: self
  srcPort: 3001
```

## Serial Read Loop

The driver loop is configured as:

```text
ros::Rate loop_rate(500)
```

The `500 Hz` loop is only the polling/read loop rate. It is not guaranteed to be
the IMU output rate. Each loop checks `sp.available()`, reads any available
serial bytes, feeds those bytes into `packet_decode()`, and publishes an IMU
message when decoded IMU data is available.

In other words:

```text
500 Hz loop rate != IMU measurement rate
```

It is the maximum cadence at which this process wakes up to drain the serial
buffer.

## Frequency

There are four relevant rates:

```text
Serial baudrate:             115200
serial_imu read loop:        500 Hz
measured /imu/data_raw rate: about 200 Hz
bridge send max_freq:        50 Hz
```

The node measures the actual decoded packet rate with `frame_count`:

```text
frame_rate = frame_count once per second
```

That `Frame Rate` value is printed to the terminal by `dump_data_packet()`.

The measured ROS topic rate on the vehicle was:

```bash
rostopic hz /imu/data_raw
```

Observed output:

```text
subscribed to [/imu/data_raw]
average rate: 200.045
  min: 0.002s max: 0.008s std dev: 0.00112s window: 195
average rate: 200.007
  min: 0.002s max: 0.008s std dev: 0.00109s window: 395
average rate: 200.072
  min: 0.002s max: 0.008s std dev: 0.00106s window: 596
average rate: 200.058
  min: 0.002s max: 0.008s std dev: 0.00121s window: 796
average rate: 200.047
  min: 0.001s max: 0.009s std dev: 0.00170s window: 996
average rate: 199.943
  min: 0.001s max: 0.009s std dev: 0.00180s window: 1197
average rate: 199.943
  min: 0.001s max: 0.009s std dev: 0.00171s window: 1397
average rate: 199.979
  min: 0.001s max: 0.009s std dev: 0.00164s window: 1598
```

So the local ROS IMU topic is effectively:

```text
/imu/data_raw ~= 200 Hz
```

The effective rate seen by the remote QGC/XGC side is capped by
`swarm_ros_bridge`:

```text
remote IMU rate <= 50 Hz
```

The local ROS topic `/imu/data_raw` publishes at about `200 Hz` in the measured
vehicle session, while the bridge forwards that topic to QGC/XGC at no more than
`50 Hz`.

## Debug Notes

Check service state:

```bash
systemctl status handsfree_imu.service
journalctl -u handsfree_imu.service -f
```

Check device:

```bash
ls -l /dev/imu
lsusb | grep -i '10c4'
```

Check ROS topic:

```bash
rostopic hz /imu/data_raw
rostopic echo -n 1 /imu/data_raw
```

Check bridge-side forwarding:

```bash
systemctl status swarm_ros_bridge.service
journalctl -u swarm_ros_bridge.service -f
```

Known quirk:

```text
imu_subscriber echoes /IMU_data, but serial_imu publishes /imu/data_raw.
```

That makes `imu_subscriber` likely a stale debug node rather than a useful
runtime subscriber.
