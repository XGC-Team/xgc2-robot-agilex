# AgileX ROS1 communication workspace

Sibling of `onboard/ros1/chassis`, `onboard/ros1/perception`,
`onboard/ros1/sensors`, `onboard/ros1/visualization`, and
`onboard/ros1/autostart`. Vehicle YAML, launch,
and the ScoutStatus-to-std relay (`/PowerVoltage` Float32,
`/scout/chassis_state` UInt32). The bridge binary comes from APT
`swarm_ros_bridge`. systemd lives in `onboard/ros1/autostart`.

```text
src/agilex_swarm_ros_bridge
```
