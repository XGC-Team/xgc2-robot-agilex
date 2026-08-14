# AgileX camera assembly

This robot does not own a camera driver. It parameterizes the common stack.

| Role | What to run |
| --- | --- |
| ROS algorithms | `realsense2_camera` via `agilex_onboard_sensors/camera.launch` |
| WebRTC preferred | stop RealSense, then `webrtc.launch` (`xgc_native_v4l2_rtp`) |
| WebRTC last resort | `fallback_webrtc.launch` only while RealSense owns USB |
| Gazebo | `gazebo_sim_camera` native RTP; do not ROS-re-encode |

One physical sensor, one capture owner.
