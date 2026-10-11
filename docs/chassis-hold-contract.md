# Scout chassis HOLD host

The driver instantiates `ChassisHold` and `UdpEndpoint` from chassis-hold
0.2.0 and serves `xgc2.chassis.hold` over `udp.v1`, bound to `0.0.0.0`.
The library owns the state machine, service methods, authentication,
instance identity and release revisions. See its
[contract](https://github.com/XGC-Team/xgc2-chassis-hold/blob/fcfe8f441ad257b049c27dfc0ea4351bae6733f0/contracts/chassis-hold.md).
The driver links only the `core` and `udp` components, which support Bionic.

| Private ROS parameter | Default | Meaning |
| --- | --- | --- |
| `hold_robot_id` | Required | Registered identity of this one chassis |
| `hold_port` | `19530` | UDP service port, 1..65535 |
| `hold_key_file` | `/etc/xgc2/chassis-hold.key` | Authentication key file |
| `hold_boot_held` | `false` | Start held after each process restart |
| `hold_required` | `true` | Exit with an error when the endpoint cannot start |

Launches require `robot_id` and forward the other four parameters as
arguments with these defaults. Autostart reads the corresponding
`XGC2_CHASSIS_HOLD_*` settings from `/etc/xgc2/agilex/onboard.env`.

The robot setup user-script provisions the key; this package ships no key.
The file contains one `<key_id> <base64 of 32 bytes>` entry per line and is
owned by `agilex:agilex`, the chassis service account (`User=agilex`), mode
`0600`. Its parent directory `/etc/xgc2` is `root:root`, mode `0755`:

```sh
sudo install -d -o root -g root -m 0755 /etc/xgc2
sudo install -o agilex -g agilex -m 0600 <keyfile> /etc/xgc2/chassis-hold.key
```

With `hold_required=true`, an unreadable, missing, empty or malformed key
ends the process non-zero. With false, the driver logs the endpoint error
once and drives without HOLD, including when `hold_boot_held` was requested.

The `/cmd_vel` callback receives a ROS `MessageEvent` and passes its
`getReceiptTime().toNSec()` to `admit` before `SetMotionCommand`. The domain
clock is `ros::Time::now().toNSec()`. Held commands and commands received
before the last release are dropped, including a callback dispatched after
release. Release never replays an old command.

The messenger's existing 50 Hz run loop owns SDK output and calls `tick()`
once per cycle before dispatching queued callbacks. Each held tick calls
`SetMotionCommand(0, 0)` through `HoldZero`, keeping zero CAN frames flowing.
A successful write allows `zero_written`. Feedback is the Scout state
linear and angular velocity the messenger already reads, with the ROS stamp.
Only reported rest after zero output can advance to `stopped`, using the
library defaults of 0.02 m/s, 0.05 rad/s and a continuous 300 ms dwell.
The simulated robot supplies its published simulated velocities as feedback.

SDK exceptions and failed HOLD zero writes end the process non-zero.
Normal shutdown stops the endpoint and library, writes zero and terminates
the SDK worker. The required ROS node ends its launch on exit; the chassis
systemd unit retains `Restart=always` with a five-second delay. Every new
driver process has a new library instance. Real-vehicle acceptance is out
of scope for this fixture.

The driver fixture uses the installed `xgc2-hold`, temporary keys owned by
the test user with mode `0600`, and a private ROS master on a random port in
20000..40000 with its own `ROS_HOME`. It runs `scout_base_node` with
`_simulated_robot:=true`, counts actual command-write debug traces, checks
state feedback and tests missing/unreadable keys. A fixture-only sleep
barrier queues a command before release and verifies its later callback is
dropped with the gate open. Library contract and transport-fault tests stay
in the chassis-hold repository.

```sh
. /path/to/catkin/devel/setup.bash
cmake -S test -B .work/hold-test \
  -DSCOUT_DEVEL_PREFIX=/path/to/catkin/devel \
  -DPYTHON_EXECUTABLE=/usr/bin/python3
cmake --build .work/hold-test --parallel 2
(cd .work/hold-test && ctest --output-on-failure)
```
