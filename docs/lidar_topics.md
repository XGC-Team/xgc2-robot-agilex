# AgileX LiDAR Topics

This note records the current onboard RoboSense LiDAR connection, launch path,
and ROS topic surface in `products/robotics/agilex`.

## Hardware

The configured LiDAR is:

```text
RoboSense RSHELIOS_16
```

The driver is configured for an online Ethernet LiDAR:

```yaml
msg_source: 1
lidar_type: RSHELIOS_16
frame_id: rslidar
msop_port: 6699
difop_port: 7788
send_point_cloud_ros: true
send_packet_ros: false
```

Relevant source:

```text
../onboard/ros1/src/sensors/rslidar_sdk/config/config.yaml
```

## Physical Connection

The LiDAR connects to the onboard computer through Ethernet. The computer
network interface must be placed on the LiDAR network according to the LiDAR
user guide.

The current config expects UDP packets on:

| Port | Meaning |
| --- | --- |
| `6699` | MSOP data packets |
| `7788` | DIFOP device/config packets |

The vendor how-to also describes these as the default ports for online ROS
point-cloud publishing.

Relevant source:

```text
../onboard/ros1/src/sensors/rslidar_sdk/doc/howto/how_to_online_send_point_cloud_ros_cn.md
```

## Startup

Start the LiDAR driver with:

```bash
roslaunch rslidar_sdk start.launch
```

The launch file starts:

```text
rslidar_sdk_node
```

Relevant source:

```text
../onboard/ros1/src/sensors/rslidar_sdk/launch/start.launch
```

## Readable ROS Topics

### Active by Default

| Topic | Type | Direction | Notes |
| --- | --- | --- | --- |
| `/rslidar_points` | `sensor_msgs/PointCloud2` | publish | Main 3D point cloud. Header frame is `rslidar`. |

This is the topic consumers should normally subscribe to for perception,
mapping, or visualization.

Example checks:

```bash
rostopic list | grep rslidar
rostopic type /rslidar_points
rostopic hz /rslidar_points
rostopic echo -n 1 /rslidar_points/header
```

Expected type:

```text
sensor_msgs/PointCloud2
```

## Configured but Disabled Topics

The config contains packet topic names, but packet publishing is disabled by
default:

```yaml
send_packet_ros: false
ros_recv_packet_topic: /rslidar_packets
ros_send_packet_topic: /rslidar_packets
```

If packet publishing is enabled later, packet topics are useful for rosbag
recording and offline decoding. In the current checked-in config, do not expect
`/rslidar_packets` to appear during normal online operation.

## Data Content

`/rslidar_points` carries a full 3D point cloud. The current config also sets:

| Field | Value |
| --- | --- |
| `start_angle` | `0` |
| `end_angle` | `360` |
| `min_distance` | `0.2` m |
| `max_distance` | `200` m |
| `use_lidar_clock` | `false`, use host system clock |

## Network Debugging

If ROS has no point cloud, first verify the Ethernet packet flow:

```bash
IFACE=eth0
sudo tcpdump -ni "$IFACE" 'udp port 6699 or udp port 7788'
```

Then check whether the ROS node is running and publishing:

```bash
rosnode list | grep rslidar
rostopic hz /rslidar_points
```
