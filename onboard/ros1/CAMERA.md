# AgileX camera assembly

Autostart names Scout topics and ports. The shared camera driver owns D435
capture for ROS algorithms; Media Edge owns the image pipe and encoder while
a viewer, capture or recording needs the color stream.

| Role | Shared package | Scout launch |
| --- | --- | --- |
| ROS algorithms | `xgc2_camera_driver` V4L2 color | `agilex_onboard_autostart/camera.launch` |
| H.264/RTP and browser fan-out | `xgc2-media-edge` pipeline with `xgc2_ros_image_pipe` | unit `xgc2-agilex-media-edge.service` |
| RViz | — | `agilex_onboard_rviz/rviz.launch` |

`xgc2-agilex-camera.service` starts `camera.launch`, publishing
`/d435/image_raw` as BGR8 at 640x480, 30 Hz, frame `d435_optical_frame`.
The color-only `config/sources.json` roster declares a `pipeline` source at
`127.0.0.1:5004`: `nvv4l2-fdsrc` on Jetson, with template parameter
`format: bgr` and producer `xgc2_ros_image_pipe --topic /d435/image_raw --format bgr8`.
Media Edge starts and stops those children with its leases. The ROS capture
owner remains available to algorithms when nobody watches.

Install `ros-melodic-xgc2-camera-driver` (or the Noetic package) and
`xgc2-media-edge >= 0.7.0-1~bionic` (or `0.7.0-1~focal`), plus
`gstreamer1.0-tools`, `gstreamer1.0-plugins-good` and
`gstreamer1.0-plugins-ugly`. Jetson also needs its `nvv4l2h264enc` plugin.
On a non-Jetson board, copy the roster to a site file, change the template to
`x264-fdsrc` and set `MEDIA_SOURCES` to that file. Keep `format: bgr`; the
software template's optional bitrate parameter is `bitrateKbps`. Noetic
packaging rewrites the producer path to `/opt/ros/noetic/lib/xgc2_camera_driver/`.

The starter sources the ROS setup and exports `ROS_MASTER_URI` and `ROS_IP`
for the producer. `prepare-runtime` creates control, MediaMTX and pipeline
directories below the unit's private 0700 `/run/xgc2/media-edge` directory
(`MEDIA_RUNTIME` overrides it). `XGC2_TARGET_ID` defaults to the hostname.
The media unit is softly ordered after the camera unit; start both for viewing.
Public ICE address comes from `wlan1` unless `MEDIA_PUBLIC_IP` is set.
