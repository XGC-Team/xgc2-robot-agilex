# AgileX ROS1 autostart workspace

Owns every onboard systemd unit. Sibling of `chassis`, `communication`,
`perception`, `control`, `sensors`, and `visualization`.

Site identity (rigid body, VRPN server, ROS_IP, CAN) lives in
`/etc/xgc2/agilex/onboard.env`. Units only `EnvironmentFile` that path;
they do not bake `MOCAP_RIGID_BODY` or `ROS_IP`. Copy the packaged
`config/onboard.env` there on first install if missing.

Install-only by default: the package does not enable or start any unit.
Enable **chassis** at boot if the vehicle should always have CAN/TF.
Leave mocap, IMU, camera, lidar, and the swarm bridge disabled. Agent
`process.run-definition` `agilex-mocap-ros1` starts mocap for a Session
with per-run `rigidBody` / `vrpnServer`.

```text
src/agilex_onboard_autostart
  systemd/xgc2-agilex-roscore.service
  systemd/xgc2-agilex-chassis.service
  systemd/xgc2-agilex-imu-hi226.service
  systemd/xgc2-agilex-swarm-ros-bridge.service
  systemd/xgc2-agilex-camera.service
  systemd/xgc2-agilex-lidar-helios16.service
  systemd/xgc2-agilex-mocap.service
  systemd/xgc2-field-panel.service
  systemd/xgc2-agilex-usb-recover@.service
```

`xgc2-agilex-roscore` is the only master. Every other start script
`wait-roscore`, sleeps a 2s-class stagger, then `roslaunch --wait`.
Children must not spawn a master. Chassis `Wants=` roscore.

USB Hub unplug: `scout_base_node` / `HI226` are `required="true"` so the
launch dies and systemd restarts; `can0` add runs `usb-recover@can`
(`setup-can0` + try-restart chassis). HI226 always binds `/dev/imu`.
