#!/usr/bin/env python3
"""ROS-independent layout contract for the generic onboard teleop viewer."""
from __future__ import annotations

import ast
import xml.etree.ElementTree as ET
from pathlib import Path

PKG = Path(__file__).resolve().parents[1]
ROOT = PKG
AUTOSTART = (
    PKG.parents[2]
    / "autostart"
    / "src"
    / "agilex_onboard_autostart"
)


def test_package_name() -> None:
    tree = ET.parse(PKG / "package.xml")
    assert tree.findtext("name") == "xgc2_onboard_teleop"
    assert "field_panel" not in (PKG / "package.xml").read_text()
    assert "look_angle" not in (PKG / "package.xml").read_text()
    assert "nmpc" not in (PKG / "package.xml").read_text().lower()


def test_package_xml_has_no_algorithm_depends() -> None:
    tree = ET.parse(PKG / "package.xml")
    forbidden = (
        "look_angle",
        "xgc2_field_panel",
        "agilex_nmpc",
        "agilex_estimator",
        "guidance",
        "acados",
        "realsense",
        "cv_bridge",
        "opencv",
        "scout_msgs",
    )
    texts = []
    for tag in ("depend", "exec_depend", "build_depend", "run_depend"):
        for dep in tree.findall(tag):
            texts.append((dep.text or "").strip())
    joined = " ".join(texts)
    for needle in forbidden:
        assert needle not in joined, needle


def test_node_and_ui_are_teleop_only() -> None:
    ET.parse(PKG / "launch/teleop.launch")
    source = (PKG / "scripts/onboard_teleop_node").read_text()
    ast.parse(source, filename="onboard_teleop_node")
    assert source.splitlines()[1].startswith("# -*- coding: utf-8 -*-")
    assert "def apply_teleop(" in source
    assert "def ros_setup(" in source
    assert "/api/camera/stream" in source
    assert "xgc2_onboard_teleop" in source
    for banned in (
        "guidance_two_stage",
        "guidance_1_new",
        "guidance_2_new",
        "look_angle_shaping",
        "start_stack",
        "start_vrpn",
        "start_perception",
        "start_control",
        "/api/stack",
        "/api/vrpn",
        "nmpc",
        "field_panel_node",
        "roslaunch realsense2_camera",
        "Matlab",
        "data_log",
    ):
        assert banned not in source, banned
    html = (PKG / "web/index.html").read_text()
    assert "bindTeleopHold" in html
    assert "openDrive" in html
    assert "closeDrive" in html
    assert "stick-left" in html
    assert "stick-right" in html
    assert "遥控画面" in html
    assert "十字键遥控" in html
    assert "请横过来握持" in html
    assert "/api/camera/stream" in html
    assert "/api/teleop" in html
    assert "if (isPhone()) openDrive();" in html
    assert "ArrowUp" in html
    assert "启动算法" not in html
    assert "guidance" not in html
    assert "NMPC" not in html
    assert "VRPN" not in html
    assert "前置角" not in html
    launch = (PKG / "launch/teleop.launch").read_text()
    assert 'port" default="8100"' in launch
    assert "xgc2_onboard_teleop" in launch
    assert "look_angle" not in launch
    assert "field_panel" not in launch


def test_autostart_unit_is_optional() -> None:
    unit = AUTOSTART / "systemd" / "xgc2-agilex-onboard-teleop.service"
    script = AUTOSTART / "scripts" / "start-onboard-teleop"
    assert unit.is_file(), unit
    assert script.is_file(), script
    unit_text = unit.read_text()
    script_text = script.read_text()
    assert "WantedBy=multi-user.target" in unit_text
    assert "start-onboard-teleop" in unit_text
    assert "Wants=xgc2-agilex-chassis.service" not in unit_text
    assert "xgc2_onboard_teleop" in script_text
    assert "teleop.launch" in script_text
    assert "port:=\"${ONBOARD_TELEOP_PORT:-8100}\"" in script_text or 'port:="${ONBOARD_TELEOP_PORT:-8100}"' in script_text
    for banned in (
        "look_angle_shaping",
        "guidance_two_stage",
        "xgc2_field_panel",
        "agilex_nmpc",
        "panel.launch",
        "start-field-panel",
    ):
        assert banned not in script_text, banned
        assert banned not in unit_text, banned


def test_config_roundtrip() -> None:
    import importlib.machinery
    import importlib.util
    import tempfile
    import types

    path_src = PKG / "scripts/onboard_teleop_node"
    loader = importlib.machinery.SourceFileLoader("onboard_teleop_node", str(path_src))
    spec = importlib.util.spec_from_loader("onboard_teleop_node", loader)
    if spec is None:
        mod = types.ModuleType("onboard_teleop_node")
        loader.exec_module(mod)
    else:
        mod = importlib.util.module_from_spec(spec)
        loader.exec_module(mod)
    handle = tempfile.NamedTemporaryFile(suffix=".json", delete=False)
    path = handle.name
    handle.close()
    try:
        mod.STATE.speed = 0.55
        assert mod.save_panel_config(path)
        mod.STATE.speed = 0.1
        assert mod.load_panel_config(path)
        assert mod.STATE.speed == 0.55
        ok, _msg = mod.apply_teleop({"button": "forward", "pressed": True})
        assert ok
        assert mod.STATE.teleop_fwd is True
        ok, _msg = mod.apply_teleop({"stick": True, "throttle": 0.9, "yaw": -0.5})
        assert ok
        assert abs(mod.STATE.teleop_v) > 0
        ok, _msg = mod.apply_teleop({"button": "stop"})
        assert ok
        assert mod.STATE.teleop_fwd is False
    finally:
        Path(path).unlink(missing_ok=True)
        Path(path + ".tmp").unlink(missing_ok=True)


if __name__ == "__main__":
    test_package_name()
    test_package_xml_has_no_algorithm_depends()
    test_node_and_ui_are_teleop_only()
    test_autostart_unit_is_optional()
    test_config_roundtrip()
    print("layout ok")
