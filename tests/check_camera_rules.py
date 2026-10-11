#!/usr/bin/env python3
"""Static AgileX native camera gate; the ROS driver owns the D435 device."""

import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def check(root):
    onboard = root / "onboard/ros1"
    autostart = onboard / "autostart/src/agilex_onboard_autostart"
    camera = autostart / "launch/camera.launch"
    owners = []
    for path in onboard.rglob("*.launch"):
        launch = ET.parse(path).getroot()
        for include in launch.iter("include"):
            file = include.get("file", "")
            if "$(find xgc2_camera_driver)" in file:
                owners.append(path)
                args = {arg.get("name"): arg.get("value") for arg in include.findall("arg")}
                assert path == camera and file.endswith("/launch/camera.launch"), path
                assert args.get("source_kind") == "v4l2" and "backend" not in args, path
                assert args.get("video_device") == "$(arg video_device)", path
                assert args.get("raw_publish_mode") == "always", path
            else:
                assert not re.search(r"realsense2_camera|usb_cam|gscam|camera_ros", file), path
        for node in launch.iter("node"):
            assert not re.search(r"camera|usb_cam|gscam", node.get("pkg", "")), (path, "second device owner")
    assert owners == [camera], "exactly one launch includes the ROS camera owner"
    config = (autostart / "config/d435.yaml").read_text()
    assert "source_kind: v4l2" in config and not re.search(r"^backend:", config, re.M)
    (source,) = json.loads((autostart / "config/sources.json").read_text())["sources"]
    assert source["kind"] == "pipeline" and "controlSocket" not in source
    pipeline = source["pipeline"]
    assert re.fullmatch(r"(?:x264|nvv4l2|mpp)-fdsrc", pipeline["template"])
    assert "device" not in pipeline.get("parameters", {})
    producer = pipeline["producer"]
    assert Path(producer[0]).name == "xgc2_ros_image_pipe"
    assert producer[1:] == ["--topic", "/d435/image_raw", "--format", "bgr8"]
    assert not any("/dev/" in argument for argument in producer)
    for path in onboard.rglob("*"):
        if not path.is_file() or (path.suffix not in (".cpp", ".hpp", ".h", ".py") and "scripts" not in path.parts):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        assert not re.search(r"v4l2src|VideoCapture|VIDIOC_|xgc2_camera_driver_node|xgc_(?:native_v4l2_rtp|ros_image_rtp)", text), path
    script = (autostart / "scripts/start-media-edge").read_text()
    assert 'exec "${EDGE}" "${ARGS[@]}"' in script and "--sources-config" in script
    assert "start-camera" not in script and "roslaunch" not in script
    unit = (autostart / "systemd/xgc2-agilex-media-edge.service").read_text()
    assert "RuntimeDirectoryMode=0700" in unit and "ExecStartPre=" not in unit
    definition = json.loads((root / "process-definitions/agilex-mocap-ros1.json").read_text())["definitions"][0]
    command = definition["command"]
    assert command["executable"] == "roslaunch" and command["args"][:3] == ["--wait", "agilex_estimator", "mocap.launch"]
    assert not re.search(r"camera|/dev/video|v4l2", json.dumps(command)), "mocap must not own a camera"


if __name__ == "__main__":
    check(Path(__file__).resolve().parents[1])
    print("AgileX native camera checks passed")
