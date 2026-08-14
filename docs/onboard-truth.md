# AgileX 机载真相

活页。传感器 + RViz 启动步骤见 [sensor-rviz-bringup.md](./sensor-rviz-bringup.md)。

**最近核实：** 2026-08-14 22:35 CST  
**方式：** 底盘/IMU 只观察。已授权启动过 RealSense、rslidar、RViz；`eth0` 临时 `192.168.1.102/24`。未 pub `/cmd_vel`，未改 systemd。

## 启动链（现场）

```text
1. source Melodic + catkin_ws
2. sudo ip addr add 192.168.1.102/24 dev eth0     # 雷达网，重启丢失
3. roslaunch realsense2_camera rs_camera.launch   # USB3 D435
4. roslaunch rslidar_sdk start.launch             # eth0 Helios
5. DISPLAY=:0 rviz -d …/xgc2_sensors.rviz         # Color + Depth + 点云
```

完整命令：[sensor-rviz-bringup.md](./sensor-rviz-bringup.md)。配置：[rviz/xgc2_sensors.rviz](./rviz/xgc2_sensors.rviz)。

## 传感摘要

| | 相机 | 雷达 |
| --- | --- | --- |
| 物理 | USB3 `8086:0b07`，`/dev/video0-2`（uvcvideo）；ROS 走 librealsense | 网线 `eth0` 千兆；雷达 `192.168.1.200` → 主机 `192.168.1.102` |
| Linux | 不是文件系统挂载 | 不是块设备、不挂载 |
| 源码 | `~/catkin_ws/src/realsense/realsense-ros/realsense2_camera` 2.2.22 | `~/catkin_ws/src/rslidar_sdk` 1.3.2 |
| 话题 | `/camera/color/image_raw`、`/camera/depth/image_rect_raw` ~30 Hz | `/rslidar_points` ~10 Hz |
| 负担 | nodelet ~20% CPU | 驱动 ~15% CPU；eth0 ~0.9 MiB/s；订点云时 `lo` 更重 |

开机自启仍只有桥 + IMU + 底盘。相机/雷达/RViz 都是手动链。

USB 产品名是 **D435**（无 IMU 流）。RViz 只开彩色、深度、点云。
