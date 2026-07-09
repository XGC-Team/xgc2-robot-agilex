# AgileX Camera Topics

This note records the current onboard Intel RealSense camera connection, launch
path, and ROS topic surface in `products/robotics/agilex`.

## Hardware

The runtime camera driver is:

```text
realsense2_camera
```

The package version in this repository is `2.2.22` and depends on
`librealsense2`. The package description covers Intel T265, SR300, and D400
3D cameras. The repository also contains D435-specific launch/model and vision
scripts, so the practical camera assumption for this vehicle is an Intel
RealSense D435/D400-class USB camera unless hardware inspection says otherwise.

Relevant sources:

```text
../onboard/ros1/src/sensors/realsense2_camera/package.xml
../onboard/ros1/src/sensors/realsense2_camera/launch/rs_d435_camera_with_model.launch
../onboard/ros1/src/extend/vision/scripts/detect_node.py
../onboard/ros1/src/extend/vision/scripts/read_d435.py
```

## Physical Connection

RealSense connects to the onboard computer by USB. The default launch file can
select a device by serial number or USB port when more than one RealSense is
connected:

```xml
<arg name="serial_no" default=""/>
<arg name="usb_port_id" default=""/>
<arg name="device_type" default=""/>
```

Relevant source:

```text
../onboard/ros1/src/sensors/realsense2_camera/launch/rs_camera.launch
```

## Startup

Start the default RealSense driver with:

```bash
roslaunch realsense2_camera rs_camera.launch
```

The default namespace is:

```text
/camera
```

Relevant source:

```text
../onboard/ros1/README.md
../onboard/ros1/src/sensors/realsense2_camera/launch/rs_camera.launch
```

## Default Launch Behavior

`rs_camera.launch` enables color and depth by default:

```text
enable_color=true
enable_depth=true
```

The following are disabled by default in `rs_camera.launch`:

```text
enable_infra=false
enable_infra1=false
enable_infra2=false
enable_gyro=false
enable_accel=false
enable_pointcloud=false
align_depth=false
```

This means the default expected readable topics are color and depth image
topics. Point cloud, aligned depth, infrared, and IMU topics require launch
arguments or another launch file.

## Readable ROS Topics

### Active by Default with `rs_camera.launch`

| Topic | Type | Direction | Notes |
| --- | --- | --- | --- |
| `/camera/color/image_raw` | `sensor_msgs/Image` | publish | RGB image stream. |
| `/camera/color/camera_info` | `sensor_msgs/CameraInfo` | publish | Color camera intrinsics. |
| `/camera/depth/image_rect_raw` | `sensor_msgs/Image` | publish | Rectified depth image stream. |
| `/camera/depth/camera_info` | `sensor_msgs/CameraInfo` | publish | Depth camera intrinsics. |
| `/tf_static` | `tf2_msgs/TFMessage` | publish | Static camera frame tree when `publish_tf=true`. |

Image transport plugins may also create derived transport topics such as
`compressed` or `compressedDepth` if those plugins are installed, but consumers
should treat the raw topics above as the stable baseline.

Example checks:

```bash
rostopic list | grep '^/camera'
rostopic type /camera/color/image_raw
rostopic type /camera/depth/image_rect_raw
rostopic hz /camera/color/image_raw
rostopic echo -n 1 /camera/color/camera_info
```

Expected core types:

```text
/camera/color/image_raw        sensor_msgs/Image
/camera/color/camera_info      sensor_msgs/CameraInfo
/camera/depth/image_rect_raw   sensor_msgs/Image
/camera/depth/camera_info      sensor_msgs/CameraInfo
```

## Optional Topics

These topics are supported by the driver, but are not all active in the default
`rs_camera.launch` configuration.

| Topic | Type | Enable condition |
| --- | --- | --- |
| `/camera/infra1/image_rect_raw` | `sensor_msgs/Image` | `enable_infra1=true` |
| `/camera/infra1/camera_info` | `sensor_msgs/CameraInfo` | `enable_infra1=true` |
| `/camera/infra2/image_rect_raw` | `sensor_msgs/Image` | `enable_infra2=true` |
| `/camera/infra2/camera_info` | `sensor_msgs/CameraInfo` | `enable_infra2=true` |
| `/camera/aligned_depth_to_color/image_raw` | `sensor_msgs/Image` | `align_depth=true` and color enabled |
| `/camera/aligned_depth_to_color/camera_info` | `sensor_msgs/CameraInfo` | `align_depth=true` and color enabled |
| `/camera/depth/color/points` | `sensor_msgs/PointCloud2` | `enable_pointcloud=true` |
| `/camera/gyro/sample` | `sensor_msgs/Imu` | `enable_gyro=true`, no unified IMU method |
| `/camera/gyro/imu_info` | `realsense2_camera/IMUInfo` | `enable_gyro=true` |
| `/camera/accel/sample` | `sensor_msgs/Imu` | `enable_accel=true`, no unified IMU method |
| `/camera/accel/imu_info` | `realsense2_camera/IMUInfo` | `enable_accel=true` |
| `/camera/imu` | `sensor_msgs/Imu` | `enable_gyro=true`, `enable_accel=true`, and `unite_imu_method` not `none` |
| `/camera/odom/sample` | `nav_msgs/Odometry` | pose stream enabled, mainly for T265 |

The publisher naming is built in:

```text
../onboard/ros1/src/sensors/realsense2_camera/src/base_realsense_node.cpp
```

## Useful Launch Variants

Default color and depth:

```bash
roslaunch realsense2_camera rs_camera.launch
```

Enable point cloud:

```bash
roslaunch realsense2_camera rs_camera.launch enable_pointcloud:=true
```

Enable aligned depth to color:

```bash
roslaunch realsense2_camera rs_camera.launch align_depth:=true enable_sync:=true
```

D435 launch with model:

```bash
roslaunch realsense2_camera rs_d435_camera_with_model.launch
```

## Frame IDs

With the default camera namespace and TF prefix, frame names follow the
`camera_*` pattern:

```text
camera_link
camera_color_frame
camera_color_optical_frame
camera_depth_frame
camera_depth_optical_frame
camera_aligned_depth_to_color_frame
```

The exact active frame set depends on which streams are enabled.
