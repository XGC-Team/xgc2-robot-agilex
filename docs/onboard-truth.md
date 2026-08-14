# AgileX 机载真相

活页。和本目录旧笔记打架时以本页为准。

**最近核实：** 2026-08-14 22:15 CST（本轮已启动相机 + 雷达做实测）  
**快照：** [2026-08-14-sensors.md](./2026-08-14-sensors.md)  
**方式：** 底盘/IMU 仍只观察。用户授权后启动了 RealSense 与 rslidar；给 `eth0` 临时加了雷达网段地址。未 pub `/cmd_vel`，未改 systemd，未永久改 NetworkManager。

## 1. 身份 / 操作系统 / 指令集

| 项 | 值 |
| --- | --- |
| SSH | 用户 `agilex`，地址 `192.168.100.76`（密码登录；密码不写在此） |
| 主机名 | `xavier` |
| 板型 | Jetson AGX，L4T R32.4.4 |
| 发行版 | Ubuntu 18.04.5 LTS |
| 内核 | `Linux 4.9.140-tegra` |
| 指令集 | aarch64，8 核 |
| 用户 | `agilex` uid 1000 |
| 底盘自报 | `Working as scout mini: 1` |

运行的是家目录 `catkin_ws` overlay，不是产品 deb。

## 2–5. 文件系统 / 磁盘 / 内存 / CPU（摘要）

根盘 `mmcblk0p1` **ext4** 28 G，约 **91%**。内存 31 G，传感起来后 used 约 2.5 G，仍然宽裕。Swap 0。GPU `GR3D_FREQ 0%`（相机/雷达都走 CPU）。

传感双开后 tegrastats 各核约 9–35% @ 1190 MHz，未顶满。

## 6. 网卡身份

| 接口 | 状态 | 地址 | 角色 |
| --- | --- | --- | --- |
| `wlan1` | UP | `192.168.100.76/24` | 现场 Wi-Fi，默认路由 |
| `eth0` | UP，千兆全双工 | **本轮临时** `192.168.1.102/24` | 雷达网。重启后会丢 |
| `can0` | UP 500 kbit/s | — | 底盘 |
| `lo` | UP | 127.0.0.1/8 | 本机 ROS |

雷达自己是 `192.168.1.200`，一直在 ARP 询问 `192.168.1.102`。没给主机配这个地址时，`eth0` 上看不到 MSOP，只有 ARP。

## 7. 网卡流量（双传感在跑，5 s）

| 接口 | 窗内 RX | 窗内 TX | 含义 |
| --- | --- | --- | --- |
| `eth0` | **936 KiB/s，751 pps** | 0 | 雷达 UDP 入站，约 7.5 Mb/s，相对千兆很轻 |
| `lo` | **约 20 MiB/s** 双向 | 同左 | 本机订了点云+图像时的 ROS 拷贝，比 eth0 重得多 |
| `can0` | 3.1 KiB/s，397 pps | 0 | 底盘小包 |
| `wlan1` | 可忽略 | 可忽略 | SSH |

## 8–10. ROS / 服务 / 开机

Melodic。开机仍是桥 + IMU + 底盘三件套，**没有**相机/雷达 unit。

本轮手动（用户 `agilex` 的 roslaunch，不是 systemd）：

- `roslaunch realsense2_camera rs_camera.launch`
- `roslaunch rslidar_sdk start.launch`

## 11–12. 传感拓扑、频率、Δt

```text
D435 USB3 --> librealsense + realsense2_camera nodelet
           --> /camera/color/image_raw          ~30 Hz
           --> /camera/depth/image_rect_raw     ~30 Hz

Helios 网口 --> eth0 UDP 6699/7788 --> rslidar_sdk_node
           --> /rslidar_points                  ~10 Hz
```

| 话题 | 类型 | 发布 | n | Hz | mean Δt | std(Δt) | 稳不稳 |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| `/camera/color/image_raw` | `sensor_msgs/Image` | `/camera/realsense2_camera_manager` | 80 | 29.99 | 33.3 ms | 1.78 ms | 稳 |
| `/camera/depth/image_rect_raw` | `sensor_msgs/Image` | 同上 | 80 | 30.00 | 33.3 ms | 1.76 ms | 稳 |
| `/rslidar_points` | `sensor_msgs/PointCloud2` | `/rslidar_sdk_node` | 40 | 10.00 | 100.0 ms | 1.96 ms | 稳 |

点云：`frame_id=rslidar`，16×1800，字段 `x y z intensity`，每帧 921600 B。  
彩色：640×480（launch 写了 1920×1080，设备落到可用模式）。深度：848×480。

## 13. 硬件在 vs 软件在跑

| 硬件 | Linux 里长什么样 | 驱动源码（车上） | 现在 |
| --- | --- | --- | --- |
| RealSense D435 | USB3 `8086:0b07`，5 Gb/s，路径 `usb2-1.1.2`；**不是文件系统挂载**。内核 `uvcvideo` 出 `/dev/video0` `/dev/video1` `/dev/video2`，真正取流走 librealsense | `~/catkin_ws/src/realsense/realsense-ros/realsense2_camera` v2.2.22，产物 `devel/lib/librealsense2_camera.so` | **已启动** |
| RoboSense Helios 16 | 网线进板载 `eth0`（千兆）。**不是块设备、不挂载**。雷达 `192.168.1.200` → 主机 `192.168.1.102`，UDP 6699/7788 | `~/catkin_ws/src/rslidar_sdk` v1.3.2，产物 `devel/lib/rslidar_sdk/rslidar_sdk_node`；参数 `config/config.yaml` | **已启动** |
| 红外 `vision` 包 | 另一套 OpenCV 开本地 camera index | `~/catkin_ws/src/vision` | 未测 |

### 参数怎么配

相机：`rs_camera.launch`。本车默认 `enable_color/depth=true`，`enable_pointcloud/align_depth/infra/gyro=false`，`color_width/height=1920/1080`（实际 640×480）。命名空间 `/camera`。

雷达：`start.launch` 空 `config_path`，读包内 `config.yaml`：`msg_source=1`（在线雷达），`lidar_type=RSHELIOS_16`，`send_point_cloud_ros=true`，`send_packet_ros=false`，距离 0.2–200 m，`use_lidar_clock=false`。

主机侧雷达网必须是 `192.168.1.102/24`。本轮用 `sudo ip addr add`，**没写入 NM，重启即无**。

## 14. 与旧文档 / README 的差别

仓库 README 写「相机雷达留在车上、不打包」——属实。但车上驱动是齐的，只是默认不开。  
旧笔记把话题面写全了；上电并不会自动出现这些话题。

## 15. 评估与建议

### 负担

- **不算重。** 内存几乎没动；GPU 空闲。
- CPU：RealSense nodelet 约 **20%**，`rslidar_sdk_node` 约 **15%**，加上原有 IMU/桥大约再 15%。双开后总负载中等，Xavier 还撑得住。
- 网：雷达占 `eth0` ~0.9 MiB/s，轻松。真正重的是 **本机 `lo`**：谁订 `/rslidar_points`（每秒约 9 MiB）再加两路图像，loopback 会到十几 MiB/s。不要在车上再开 RViz/多路 bag 除非有意。
- 相机 Asic 温度读数无效（librealsense 刷 ERROR），流本身稳定。

### 建议（未执行）

1. 若要开机就有传感：给 `eth0` 做一条 NM 静态 `192.168.1.102/24`（不要当默认路由），再加两个 systemd，**需你点头**。
2. 颜色若需要 1080p，改 launch 并复测 CPU；默认实际是 640×480@30。
3. 点云订阅者要按 10 Hz × 0.9 MiB 预算带宽。

### 本轮做过 / 没做

做过：起 `rs_camera.launch`、给 `eth0` 临时地址、起 `rslidar_sdk start.launch`、被动订话题测 hz。  
没做：`/cmd_vel`、改 systemd、永久改网、iperf、关驱动。

## 16. 未决问题

1. `eth0` 临时地址是否改成开机常驻？
2. 红外 `vision` 包是否还要测？
3. 默认 640×480 是否就是产品面，还是要锁 1080p？

## 17. 最近核实

2026-08-14 22:15 CST。驱动现仍由本次 SSH 会话的 roslaunch 挂着，不是开机自启。
