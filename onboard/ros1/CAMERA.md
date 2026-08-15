# AgileX camera assembly

This robot does not own the D435 driver. Capture lives in the shared
[`xgc2-camera-d435`](https://github.com/XGC-Team/xgc2-camera-d435)
product (`realsense2_camera` + `xgc_camera_d435`). Other robots reuse
that repository. This tree only includes the launch.

| Role | What to run |
| --- | --- |
| ROS algorithms | `agilex_onboard_sensors/camera.launch` → `xgc_camera_d435/d435i.launch` |
| WebRTC preferred | stop RealSense, then `webrtc.launch` (`xgc_native_v4l2_rtp`) |
| WebRTC last resort | `fallback_webrtc.launch` only while RealSense owns USB |
| Gazebo | `gazebo_sim_camera` native RTP; do not ROS-re-encode |

One physical sensor, one capture owner.
