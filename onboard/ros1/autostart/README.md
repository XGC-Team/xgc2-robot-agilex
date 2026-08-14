# AgileX ROS1 autostart workspace

Owns every onboard systemd unit. Sibling of `base`, `communication`, and
`sensors`. Enables only `xgc2-agilex-base.service` for the next boot.

```text
src/agilex_onboard_autostart
  systemd/xgc2-agilex-base.service
  systemd/xgc2-agilex-communication.service
  systemd/xgc2-agilex-camera.service
  systemd/xgc2-agilex-lidar.service
```
