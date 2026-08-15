# AgileX ROS1 autostart workspace

Owns every onboard systemd unit. Sibling of `chassis`, `communication`,
`perception`, `control`, `sensors`, and `visualization`. Install-only:
does not enable or start any unit.

```text
src/agilex_onboard_autostart
  systemd/xgc2-agilex-chassis.service
  systemd/xgc2-agilex-imu-hi226.service
  systemd/xgc2-agilex-swarm-ros-bridge.service
  systemd/xgc2-agilex-camera.service
  systemd/xgc2-agilex-lidar-helios16.service
  systemd/xgc2-agilex-mocap.service
```
