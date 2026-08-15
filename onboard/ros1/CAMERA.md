# AgileX camera assembly

This robot does not own capture or encode. Autostart names Scout topics
and ports. Shared backends:

| Role | Shared package | Scout launch |
| --- | --- | --- |
| ROS algorithms | `xgc2_camera_d435` | `agilex_onboard_autostart/camera.launch` |
| WebRTC direct capture | `xgc2_camera_driver` `xgc_native_v4l2_rtp` | `agilex_onboard_autostart/webrtc.launch` |
| WebRTC while RealSense owns USB | `xgc2_camera_driver` `xgc_ros_image_rtp` | `agilex_onboard_autostart/fallback_webrtc.launch` |
| RViz | — | `agilex_onboard_rviz/rviz.launch` |

One physical sensor, one capture owner. Stop RealSense before `webrtc.launch`.
