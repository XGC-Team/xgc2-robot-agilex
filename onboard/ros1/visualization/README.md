# AgileX ROS1 visualization

Onboard RViz. Camera, LiDAR, and WebRTC compose launches live in
`agilex_onboard_autostart`.

```text
src/agilex_onboard_rviz
```

RViz is fixed on `world`. The current VRPN tracker is only an argument to the
relay, not baked into the `.rviz` file.

```bash
roslaunch agilex_onboard_rviz rviz.launch tracker:=pose_0
```

| Who | Publishes | RViz |
| --- | --- | --- |
| `vrpn_viz_tf` | `/pose_raw` and TF `world` → `base_link` | RobotModel + point cloud follow mocap |
| `static_transform_publisher` | `base_link` → `rslidar` (uncalibrated identity until you set `lidar_*`) | `/rslidar_points` lands in world |
| `estimator_vrpn_ugv_state` | TF `world` → `estimator` | Axes **Estimator** |
| — | — | Axes **Mocap** on `base_link` |

The three image panels are always open:

| Panel | Topic |
| --- | --- |
| Color | `/camera/color/image_raw` |
| Depth | `/camera/depth/image_rect_raw` |
| Infra1 | `/camera/infra1/image_rect_raw` |

Does not publish `/cmd_vel`, `/pose`, or `vision_pose`. Mocap client stays in
`agilex_estimator/mocap.launch`. Robot mesh needs `robot_description` from the
chassis description launch.
