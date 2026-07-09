# AgileX Real-Vehicle and Gazebo Topic Compatibility

This note records the current compatibility gap between the recovered AgileX
real-vehicle ROS 1 stack and the Scout Gazebo simulator. It is intentionally a
documentation snapshot only; no simulator or onboard package behavior is changed
by this file.

## Scope

Real-vehicle source snapshot:

```text
datasets/agilex/agilex_dirs_20260708_extracted/catkin_ws/src
```

Productized real-vehicle repository:

```text
products/robotics/agilex
```

Gazebo simulator and model packages:

```text
products/ros1/simulator/gazebo-sim/agilex/scout
products/ros1/robot/scout_description
```

The field snapshot is useful for understanding the deployed vehicle behavior.
The productized repository is the packaging boundary for onboard runtime notes
and real-vehicle driver products.

## Overall Summary

The current simulator is command-compatible with the Scout chassis at the
`geometry_msgs/Twist` level, but it is not sensor-compatible with the recovered
vehicle stack.

| Interface | Real vehicle | Gazebo simulator | Current match |
| --- | --- | --- | --- |
| Motion command | `/cmd_vel` | `/ugv1/cmd_vel` by default | Message-compatible, topic differs |
| Motion command type | `geometry_msgs/Twist` | `geometry_msgs/Twist` | Compatible |
| Used command fields | `linear.x`, `angular.z` | `linear.x`, `angular.z` | Compatible |
| Chassis status | `/scout_status` | no equivalent by default | Missing in simulator |
| Odometry | driver parameters exist; recovered code has odom publish disabled | `/odom` or `/ugvX/odom` from Gazebo model state | Source differs |
| TF | real odom-to-base TF path exists but is disabled in recovered code | model-state-based TF plus `robot_state_publisher` | Not equivalent |
| IMU | `/imu/data_raw`, frame `imu_link` | `imu` under robot namespace, frame `imu_link` | Sensor exists, topic differs |
| 3D LiDAR | RoboSense `RSHELIOS_16`, `/rslidar_points`, frame `rslidar` | 2D ray laser `/scan`, frame `laser_link` | Not equivalent |
| Depth/RGB camera | Intel RealSense driver topics under `/camera` | OpenNI/Kinect-style depth camera under `/camera` | Partially topic-compatible |
| Infrared camera | `/infrared_camera/image_raw`, frame `infrared_camera` | no equivalent by default | Missing in simulator |

## Real-Vehicle Sensor Drivers

### RoboSense LiDAR

Recovered package:

```text
catkin_ws/src/rslidar_sdk
```

The configured LiDAR is a RoboSense `RSHELIOS_16` online Ethernet LiDAR. The
driver is configured to publish point clouds and not packet topics:

```text
msg_source: 1
send_point_cloud_ros: true
send_packet_ros: false
lidar_type: RSHELIOS_16
frame_id: rslidar
msop_port: 6699
difop_port: 7788
start_angle: 0
end_angle: 360
min_distance: 0.2
max_distance: 200
ros_send_point_cloud_topic: /rslidar_points
```

Runtime surface:

```text
/rslidar_points  sensor_msgs/PointCloud2  frame_id=rslidar
```

The packet topics `/rslidar_packets` are present in configuration, but packet
publishing is disabled in the recovered config.

### Intel RealSense

Recovered packages:

```text
catkin_ws/src/realsense/realsense-ros/realsense2_camera
catkin_ws/src/realsense/realsense-ros/realsense2_description
```

`realsense2_camera` is the actual driver package. `realsense2_description`
contains URDF/xacro resources and is not itself a runtime driver.

The recovered driver version is `2.2.22` and depends on `librealsense2`.
Default launch files expose color, depth, infrared, point cloud, and aligned
depth features through launch arguments. Important topic families are:

```text
/camera/color/image_raw
/camera/color/camera_info
/camera/depth/image_raw
/camera/depth/camera_info
/camera/aligned_depth_to_color/image_raw
/camera/infra1/image_rect_raw
/camera/infra2/image_rect_raw
/camera/depth/color/points or /camera/depth/points depending on launch/filter
```

The deployed vision stack references RealSense-style frames, for example
`camera_color_frame`.

### Infrared USB Camera Wrapper

Recovered package:

```text
catkin_ws/src/vision
```

The infrared camera node is a simple OpenCV wrapper, not a vendor-grade camera
driver. It opens a hard-coded local camera index and publishes a mono image:

```text
cv2.VideoCapture(1)
/infrared_camera/image_raw  sensor_msgs/Image
encoding=mono8
frame_id=infrared_camera
width=384
height=290
```

The launch file remaps the same logical topic through the `pub_image` argument,
but the default remains:

```text
/infrared_camera/image_raw
```

### Serial IMU

Productized package:

```text
onboard/ros1/src/sensors/agilex_onboard_imu
```

Recovered deployment path:

```text
handsfree_imu.service
  -> /home/agilex/agilex-auto-launch/handsfree_imu.sh
  -> roslaunch imu_launch imu_msg.launch
  -> serial_imu
  -> /dev/imu
```

Runtime surface:

```text
/imu/data_raw  sensor_msgs/Imu  frame_id=imu_link
```

The stable `/dev/imu` name is provided by a udev rule matching the CP210x
USB-to-UART device.

## Gazebo Sensor Model

The accurate Scout launch includes `scout_description/launch/mini_description.launch`,
which expands `scout_description/urdf/mini.xacro` and
`scout_description/urdf/scout_mini.gazebo`.

Current sensor link placement in `mini.xacro`:

```text
laser_link   xyz="0 0 0.30"    relative to base_link
camera_link  xyz="0.2 0 0.16"  relative to base_link
imu_link     xyz="0.0 0.0 0.12" relative to base_link
```

### Gazebo IMU

The simulator has an IMU plugin on `imu_link`:

```text
sensor type: imu
plugin: libgazebo_ros_imu_sensor.so
robotNamespace: $(arg ns)
topicName: imu
frameName: $(arg frame_prefix)imu_link
update rate: 100 Hz
```

With the default accurate launch namespace `ugv1`, this is expected to appear as
a namespaced `imu` topic rather than the real vehicle's global `/imu/data_raw`.

### Gazebo 2D Laser

The simulator has a 2D ray laser on `laser_link`:

```text
sensor type: ray
plugin: libgazebo_ros_laser.so
robotNamespace: $(arg sensor_ns)
topicName: scan
frameName: $(arg frame_prefix)laser_link
samples: 720
horizontal FOV: -2.09439504 to 2.09439504 rad
range: 0.05 to 8.0 m
update rate: 8 Hz
```

With the default `sensor_ns=/`, this publishes a global `/scan`.

### Gazebo Depth Camera

The simulator has a depth camera on `camera_link` using the OpenNI/Kinect-style
Gazebo plugin:

```text
sensor type: depth
plugin: libgazebo_ros_openni_kinect.so
robotNamespace: $(arg sensor_ns)
cameraName: camera
imageTopicName: color/image_raw
cameraInfoTopicName: color/camera_info
depthImageTopicName: depth/image_raw
depthImageCameraInfoTopicName: depth/camera_info
pointCloudTopicName: depth/points
frameName: $(arg frame_prefix)camera_link
image size: 640x480
update rate: 10 Hz
point cloud cutoff: 0.5 to 3.0 m
```

With the default `sensor_ns=/`, this yields topic names close to:

```text
/camera/color/image_raw
/camera/color/camera_info
/camera/depth/image_raw
/camera/depth/camera_info
/camera/depth/points
```

These names overlap with a subset of RealSense topics, but the frame tree,
aligned-depth stream, infrared streams, device metadata, and RealSense-specific
runtime behavior are not equivalent.

## Detailed Differences

### Chassis Command

Real vehicle:

```text
/cmd_vel
  -> scout_base_node
  -> ugv_sdk
  -> can0
  -> Scout chassis controller
```

Simulator:

```text
/ugv1/cmd_vel
  -> scout_skid_steer_controller
  -> ros_control velocity controllers
  -> Gazebo wheel joints
```

Both consume `geometry_msgs/Twist` and use `linear.x` plus `angular.z`, but the
default topic namespace and low-level execution semantics differ.

### Chassis Feedback

The real driver publishes `scout_msgs/ScoutStatus` containing chassis state,
battery voltage, fault code, motor state, and light state.

The simulator does not publish `/scout_status` by default. It exposes Gazebo
joint/controller state and odometry instead, which is not a drop-in replacement
for vehicle health monitoring code.

### Odometry

The recovered real driver has odometry parameters and integration code, but its
`PublishOdometryToROS` path has odom publication and odom TF sending disabled.

The simulator publishes odometry from Gazebo ground-truth model state:

```text
/gazebo/model_states
  -> gazebo_model_odom
  -> /odom or /ugvX/odom
  -> /tf
```

This is useful for simulation, but it is not equivalent to real wheel encoder or
CAN odometry.

### IMU

Real vehicle:

```text
/imu/data_raw  frame_id=imu_link
```

Simulator:

```text
$(arg ns)/imu or /imu depending on namespace handling
frame_id=$(arg frame_prefix)imu_link
```

The simulator has an IMU model, so the gap is smaller than a missing sensor. The
main mismatch is topic naming and, potentially, the noise/calibration model.

### LiDAR

Real vehicle:

```text
/rslidar_points  sensor_msgs/PointCloud2
frame_id=rslidar
model=RSHELIOS_16
horizontal coverage=360 deg
range=0.2 to 200 m
```

Simulator:

```text
/scan  sensor_msgs/LaserScan
frame_id=laser_link
horizontal coverage about 240 deg
range=0.05 to 8.0 m
```

This is the largest sensor mismatch. The simulator currently models a planar
laser scanner, while the real stack expects a 3D RoboSense point cloud.
Downstream code that consumes `/rslidar_points` cannot run against the current
simulator without a converter, synthetic point cloud source, or model change.

### RGB-D / RealSense

Real vehicle:

```text
RealSense driver, librealsense2, RealSense frame tree
/camera/color/image_raw
/camera/depth/image_raw
/camera/aligned_depth_to_color/image_raw
optional infrared and point cloud streams
```

Simulator:

```text
OpenNI/Kinect-style Gazebo plugin
/camera/color/image_raw
/camera/depth/image_raw
/camera/depth/points
frame_id=camera_link
```

There is partial topic overlap for color and depth images, but RealSense
aligned-depth topics and RealSense optical frames are missing by default.
Algorithms that only need RGB and raw depth may be easier to remap; algorithms
that use `aligned_depth_to_color`, infrared streams, RealSense frame IDs, or
device-specific parameters need explicit compatibility work.

### Infrared Camera

Real vehicle:

```text
/infrared_camera/image_raw  sensor_msgs/Image mono8
frame_id=infrared_camera
```

Simulator:

```text
no dedicated infrared camera model by default
```

The recovered infrared stack is separate from RealSense infrared streams. It is
published by `vision/src/infrared_camera.py`, which opens a local OpenCV camera
index. Any simulator workflow that depends on `/infrared_camera/image_raw`
needs a synthetic mono camera topic or a remap from another simulated image.

## Recommended Compatibility Contract

For a single real robot, the current recovered field convention is mostly
global:

```text
/cmd_vel
/imu/data_raw
/rslidar_points
/camera/color/image_raw
/camera/depth/image_raw
/camera/aligned_depth_to_color/image_raw
/infrared_camera/image_raw
/scout_status
```

For multi-robot simulation, the Gazebo packages already lean toward namespaced
control and odometry:

```text
/ugv1/cmd_vel
/ugv1/odom
/ugv1/imu
/ugv2/cmd_vel
/ugv2/odom
/ugv2/imu
```

Before changing code, choose whether the shared application contract should be a
global single-robot interface or a namespaced multi-robot interface. The
simulator and vehicle can then be aligned through launch remaps, bridge nodes,
or simulator model changes.

## Future Alignment Priority

1. Decide the shared topic namespace policy for single-robot and multi-robot
   workflows.
2. Remap or parameterize simulator command and IMU topics to match the selected
   policy.
3. Add a simulator compatibility source for `/scout_status` if upper layers
   monitor chassis health.
4. Decide whether `/scan` is only a navigation convenience topic or whether the
   simulator must provide a RoboSense-style `/rslidar_points` point cloud.
5. Add RealSense-compatible aligned depth and frame naming if RGB-D algorithms
   require RealSense semantics.
6. Add or synthesize `/infrared_camera/image_raw` if infrared workflows are part
   of the product surface.

The strongest compatibility point today is chassis command semantics. Sensor
topics, sensor message types, frames, ranges, and namespaces are not yet aligned
well enough to treat Gazebo as a drop-in replacement for the recovered
real-vehicle sensor stack.
