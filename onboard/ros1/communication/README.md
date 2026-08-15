# AgileX ROS1 communication workspace

Sibling of `onboard/ros1/base`, `onboard/ros1/autostart`, and
`onboard/ros1/sensors`. Vehicle YAML, launch, and the 1 Hz ScoutStatus
relay. The bridge binary comes from APT `swarm_ros_bridge`. systemd lives
in `onboard/ros1/autostart`.

```text
src/agilex_swarm_ros_bridge
src/agilex_mocap                 assembly: tracker Scout1, vision_out off
                                 (logic in xgc2_vrpn_relay)
```
