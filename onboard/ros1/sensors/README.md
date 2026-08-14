# AgileX ROS1 sensors

Optional D435i + Helios 16 + Media Edge assembly.
systemd lives in `autostart`. Not min-boot.

## Video path

```text
preferred  native capture owner
           xgc_native_v4l2_rtp  OR  gazebo_sim_camera
           -> loopback H264/RTP + control socket
           -> xgc-media-edge -> WebRTC

last resort  another process already holds the camera
             ros_fallback_rtp / ros_image_rtp_adapter
             (ROS Image subscribe + re-encode)
```

`camera.launch` still starts `realsense2_camera` for ROS algorithms. That
process owns USB. While it is running, WebRTC must use
`fallback_webrtc*.launch`. To use the native path, stop RealSense first:

```bash
roslaunch agilex_onboard_sensors webrtc.launch
```

Do not run RealSense and `xgc_native_v4l2_rtp` on the same device.
