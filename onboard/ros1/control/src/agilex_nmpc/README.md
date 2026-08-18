# AgileX NMPC

Control assembly. Starts the perception estimator, then the shared
unicycle reference and NMPC controller.

```bash
roslaunch agilex_nmpc nmpc.launch tracker:=pose_0
# optional Y-axis shuttle, no U-turn:
# roslaunch agilex_nmpc nmpc.launch tracker:=pose_0 shuttle:=true \
#   shuttle_x:=0.0 shuttle_y_min:=-2.0 shuttle_y_max:=2.0 shuttle_speed:=0.5
```
