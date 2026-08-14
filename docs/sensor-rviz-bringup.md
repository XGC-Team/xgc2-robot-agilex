# 相机 / 雷达 / RViz 启动链

在机载 `agilex@xavier` 上执行。默认开机只有底盘 + IMU + 桥；相机和雷达要按下面手动拉。

不发 `/cmd_vel`。`eth0` 的地址是临时的，重启会丢。

## 0. 环境

```bash
source /opt/ros/melodic/setup.bash
source /home/agilex/catkin_ws/devel/setup.bash
export ROS_MASTER_URI=http://localhost:11311
```

RViz 要画在车载桌面（Unity `:0`）：

```bash
export DISPLAY=:0
export XAUTHORITY=/run/user/1000/gdm/Xauthority
```

配置文件：本仓库 `docs/rviz/xgc2_sensors.rviz`。拷到车上例如 `/tmp/xgc2_sensors.rviz`。

## 1. 雷达网（必须先做）

雷达 `192.168.1.200` 只给主机 `192.168.1.102` 发 UDP（6699 / 7788）。没这个地址时 `eth0` 上只有 ARP，没有点云。

```bash
# 临时地址，不改默认路由（SSH 仍走 wlan1）
sudo ip addr add 192.168.1.102/24 dev eth0
sudo ip link set eth0 up
ping -c 2 -W 1 192.168.1.200
```

已加过会报 `File exists`，可忽略。

## 2. 相机

```bash
roslaunch realsense2_camera rs_camera.launch
```

源码：`~/catkin_ws/src/realsense/realsense-ros/realsense2_camera`  
默认开 color + depth；实际分辨率约 640×480 / 848×480 @ 30 Hz。

## 3. 雷达

另开一个终端（同样先 source）：

```bash
roslaunch rslidar_sdk start.launch
```

源码：`~/catkin_ws/src/rslidar_sdk`  
参数：包内 `config/config.yaml`（`RSHELIOS_16`，话题 `/rslidar_points`，约 10 Hz）。

## 4. RViz（只要彩色图、深度图、点云）

再开终端：

```bash
export DISPLAY=:0
export XAUTHORITY=/run/user/1000/gdm/Xauthority
source /opt/ros/melodic/setup.bash
source /home/agilex/catkin_ws/devel/setup.bash
export ROS_MASTER_URI=http://localhost:11311
rviz -d /tmp/xgc2_sensors.rviz
```

画面：

| 位置 | 内容 | 话题 |
| --- | --- | --- |
| 左上 Color | D435 彩色 | `/camera/color/image_raw` |
| 左下 Depth | D435 深度 | `/camera/depth/image_rect_raw` |
| 右侧 | Helios 点云 | `/rslidar_points` |

Fixed Frame：`rslidar`。没有 Displays / Views / Time 面板。

## 5. 一键后台（可选）

已 source、已配好 `eth0` 之后：

```bash
roslaunch realsense2_camera rs_camera.launch &
roslaunch rslidar_sdk start.launch &
sleep 5
DISPLAY=:0 XAUTHORITY=/run/user/1000/gdm/Xauthority \
  rviz -d /tmp/xgc2_sensors.rviz
```

## 6. 关掉

```bash
# 只关画面
pkill -x rviz

# 连驱动一起停（不要误杀 rosmaster / 底盘）
pkill -x rviz
pkill -f realsense2_camera
pkill -f rslidar_sdk_node
```

`eth0` 上的 `192.168.1.102/24` 若要撤掉：

```bash
sudo ip addr del 192.168.1.102/24 dev eth0
```

## 核对

```bash
rostopic hz /camera/color/image_raw
rostopic hz /camera/depth/image_rect_raw
rostopic hz /rslidar_points
```

期望大约 30 / 30 / 10 Hz。
