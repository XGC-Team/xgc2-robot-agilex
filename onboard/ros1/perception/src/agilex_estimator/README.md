# AgileX estimator

Perception assembly. `mocap.launch` is the VRPN client only and does
not relay onto `/pose`, `/ugv/pose`, or `vision_pose`.
`estimator.launch` adds the shared rigid-state estimator.
Does not start NMPC or publish `/cmd_vel`.
While `Running`/`Coasting` it also broadcasts `world` → `estimator` for RViz
comparison. It does not move `base_link`; onboard RViz uses VRPN for that.

```bash
roslaunch agilex_estimator mocap.launch tracker:=pose_0
roslaunch agilex_estimator estimator.launch tracker:=pose_0
```
