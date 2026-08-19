# xgc2_onboard_teleop

车上通用「看图像 + 手动遥控」服务。从 `look_angle_shaping` 只抽出十字键页、双手握持全屏页、相机 MJPEG。**不是** field-panel，不含制导 / NMPC / 动捕 / 轨迹。

## 包名

| 层 | 名字 |
| --- | --- |
| ROS | `xgc2_onboard_teleop` |
| Debian (Melodic) | `ros-melodic-xgc2-agilex-onboard-teleop` |
| Debian (Noetic) | `ros-noetic-xgc2-agilex-onboard-teleop` |
| systemd | `xgc2-agilex-onboard-teleop.service` |
| 浏览器 | `http://<车上IP>:8100/` |

默认 **不** 随 `ros-*-xgc2-agilex` 元包装上，也 **不** enable。不要和 field-panel `:8099` 抢端口。

## 车上安装（生产 APT，禁止手拷）

```bash
sudo apt-get update
sudo apt-get install ros-melodic-xgc2-agilex-onboard-teleop
# 可选开机：需要已有 roscore（底盘 enable 时会 Wants roscore）
sudo systemctl enable --now xgc2-agilex-onboard-teleop.service
```

看画面还要相机话题（本包不 Depend、也不自动 launch 相机）：

```bash
sudo apt-get install ros-melodic-xgc2-camera-d435   # 若车上还没有 D435 驱动
sudo systemctl start xgc2-agilex-camera.service     # 不要默认 enable 除非你要开机出图
```

停用：

```bash
sudo systemctl disable --now xgc2-agilex-onboard-teleop.service
```

手工启动（已 source ROS）：

```bash
roslaunch xgc2_onboard_teleop teleop.launch port:=8100
```
