# AgileX mocap

Assembly only. The client, quality gate, and relay live in
`xgc2_vrpn_relay` (`XGC-Team/xgc2-vrpn-relay`).

This package names **one** Motive tracker (`pose_0`) and leaves
`vision_out` empty. It does **not** publish `/mavros/vision_pose/pose`.

```bash
roslaunch agilex_mocap mocap.launch tracker:=pose_0
```
