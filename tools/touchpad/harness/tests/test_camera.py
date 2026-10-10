# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the camera drivers (30_camera.lua)
"""Camera.new(E, kind, opts) for the Demo, Q-SYS Camera and VISCA over IP
drivers (spec 3.17). The tests run on the XY Pad build with Mode = Joystick
(a camera mode): the camera module must not depend on any mode file, so the
mode instance is the engine's fallback; the drivers are driven through the
TouchPad.E.camera handle."""
import re

from harness import QSys

PLUGIN = "plugins/.build/NikitaTouchPad-xy.qplug"

# A fake onvif_camera_operative component with the corroborated control names.
NC_CONTROLS = {
    "pan.left": {"Boolean": False}, "pan.right": {"Boolean": False},
    "tilt.up": {"Boolean": False}, "tilt.down": {"Boolean": False},
    "pan.left.tilt.up": {"Boolean": False}, "pan.right.tilt.up": {"Boolean": False},
    "pan.left.tilt.down": {"Boolean": False}, "pan.right.tilt.down": {"Boolean": False},
    "zoom.in": {"Boolean": False}, "zoom.out": {"Boolean": False},
    "setup.pan.speed": {"Value": 0.3, "Min": 0, "Max": 1},
    "setup.tilt.speed": {"Value": 0.2, "Min": 0, "Max": 1},
    "setup.zoom.speed": {"Value": 0.4, "Min": 0, "Max": 1},
    "preset.home.load": {"Boolean": False},
    "ptz.preset": {"String": "12.5, -3.0, 25"},
    "toggle.privacy": {"Boolean": False},
}

# The community plugin convention (PTZOptics / Panasonic style names).
PLUGIN_CONTROLS = {
    "PanTiltDrive-Lt": {"Boolean": False}, "PanTiltDrive-Rt": {"Boolean": False},
    "PanTiltDrive-Up": {"Boolean": False}, "PanTiltDrive-Dn": {"Boolean": False},
    "CAM_Zoom-Z+": {"Boolean": False}, "CAM_Zoom-Z-": {"Boolean": False},
    "CAM_Pan-Speed": {"Value": 12, "Min": 1, "Max": 24},
    "PanTiltDrive-Hm": {"Boolean": False},
}


def boot(camera, extra=None, before_load=None, **kw):
    """A Joystick instance with Camera Control = camera. before_load(q) runs
    after the controls exist and before the runtime starts (fake cameras,
    the CameraIP text)."""
    props = {"Camera Control": camera}
    props.update(extra or {})
    kw.setdefault("picker", "Color_Picker")
    q = QSys(mode="Joystick", props=props, plugin=PLUGIN, runtime=False, **kw)
    if before_load:
        before_load(q)
    q._dispatch("load", q._chunk)
    q.advance(0.2)
    return q


def qsys_cam(name="Cam1", controls=NC_CONTROLS, ctype="onvif_camera_operative"):
    holder = {}

    def add(q):
        holder["cam"] = q.add_component(name, ctype, controls=dict(controls))
    q = boot("Q-SYS Camera", {"Camera Name": name}, before_load=add)
    return q, holder["cam"]


def visca(brand, ip="10.0.0.5", settle=True):
    def set_ip(q):
        q.set_pin("CameraIP", ip)
    q = boot("VISCA over IP", {"VISCA Brand": brand}, before_load=set_ip)
    if settle:
        q.advance(0.05)                                   # the TCP connect latency
    return q


def cam(q, code):
    """Runs Lua with `cam` bound to the driver."""
    return q.run("local cam = TouchPad.E.camera\n" + code)


def cam_status(q):
    return q.pin("CameraStatus")["String"]


def watch(q, comp, names):
    """Logs every change of the named component controls as 'name=value' in order."""
    q.run("CAMLOG = {}")
    for n in names:
        q.run('Component.New(%r)[%r].EventHandler = function(c) CAMLOG[#CAMLOG + 1] = %r .. "=" .. tostring(c.Boolean) end'
              % (comp, n, n))


def log(q):
    out = q.run("return table.concat(CAMLOG, ' ')")
    return out.split() if out else []


def count_writes(q, key):
    """Replaces the driver's control `key` with a proxy that counts Boolean writes."""
    q.run("""
      local d = TouchPad.E.camera
      local real = d.ctl[%r]
      CAMWRITES = 0
      d.ctl[%r] = setmetatable({}, { __index = real,
        __newindex = function(_, k, v) if k == "Boolean" then CAMWRITES = CAMWRITES + 1 end real[k] = v end })
    """ % (key, key))


def udp_payloads(q, strip=True):
    """Payloads of every UDP datagram (header stripped when strip); the RESET packet included raw."""
    out = []
    for ip, port, data in q.udp_sent:
        out.append(data[8:] if (strip and len(data) > 8) else data)
    return out


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


# ------------------------------------------------------------------ controls

def test_camera_controls_follow_the_kind():
    none = boot("None")
    assert not none.has_control("ZoomIn") and not none.has_control("CameraStatus")
    assert none.run("return TouchPad.E.camera == nil")
    demo = boot("Demo (simulated)")
    for n in ("ZoomIn", "ZoomOut", "MaxSpeed", "ZoomSpeed", "CameraStatus", "CameraView"):
        assert demo.has_control(n), n
    assert not demo.has_control("CameraIP")
    assert demo.run("return TouchPad.E.camera.kind") == "demo"
    v = visca("PTZOptics")
    assert v.has_control("CameraIP") and not v.has_control("CameraView")
    assert v.run("return TouchPad.E.camera.kind") == "visca"
    q, _ = qsys_cam()
    assert not q.has_control("CameraIP") and not q.has_control("CameraView")
    assert q.run("return TouchPad.E.camera.kind") == "qsys"
    # the factory: property texts and short kinds, unknown kinds give nil
    assert demo.run("return Camera.new(TouchPad.E, 'visca', {brand = 'Sony'}).brandName") == "Sony"
    assert demo.run("return Camera.new(TouchPad.E, 'bogus', {}) == nil")
    assert demo.run("local E = {} Camera.install(E) return type(E.cameraFactory)") == "function"
    assert demo.run("local f = TouchPad.E.cameraFactory Camera.install(TouchPad.E) return TouchPad.E.cameraFactory == f")


# ---------------------------------------------------------------------- demo

def test_demo_drive_moves_at_the_commanded_speed_and_stops():
    q = boot("Demo (simulated)")
    assert cam_status(q) == "Demo camera ready"
    cam(q, "cam:drive(1, 0)")
    q.advance(1.0)
    pan = cam(q, "return cam.pan")
    assert 27 <= pan <= 31                              # 60 deg/s x MaxSpeed 50 %
    assert near(cam(q, "return cam.tilt"), 0)
    q.set_pin("MaxSpeed", 100)
    cam(q, "cam:drive(-1, 1)")
    q.advance(0.5)
    pan2, tilt = cam(q, "return cam.pan, cam.tilt")
    assert pan2 < pan - 25 and 18 <= tilt <= 22         # 60 and 40 deg/s at full speed
    cam(q, "cam:drive(0, 0)")
    q.advance(1.0)
    assert cam(q, "return cam.pan, cam.tilt") == (pan2, tilt)   # nothing moves once stopped
    assert cam(q, "return cam.timer == nil")                      # the 20 Hz timer is released
    cam(q, "cam:drive(1, 0)")
    q.advance(8.0)
    assert near(cam(q, "return cam.pan"), 170)                    # clamped at the pan limit
    assert "pan 170" in cam(q, "return cam:status()")


def test_demo_zoom_goto_home_and_position():
    q = boot("Demo (simulated)")
    cam(q, "cam:zoom(1)")
    q.advance(1.0)
    z = cam(q, "return cam.zoomPos")
    assert 0.22 <= z <= 0.28                            # 0.5/s x ZoomSpeed 50 %
    cam(q, "cam:zoom(0)")
    q.advance(0.5)
    assert near(cam(q, "return cam.zoomPos"), z)
    cam(q, "cam:gotoPosition(-20, 10, 0.5)")
    q.advance(3.0)
    p, t, zz = cam(q, "return cam:getPosition()")
    assert near(p, -20) and near(t, 10) and near(zz, 0.5)
    assert cam(q, "return cam.target == nil")
    assert cam(q, "local r = {} cam:getPosition(function(a, b, c) r = {a, b, c} end) return r[1], r[2], r[3]") == (-20, 10, 0.5)
    cam(q, "cam:home()")
    q.advance(3.0)
    assert cam(q, "return cam.pan, cam.tilt, cam.zoomPos") == (0, 0, 0)
    assert cam(q, "return cam:zoomFactor()") == 1
    cam(q, "cam:gotoPosition(999, -999, 2)")             # clamped to the camera's range
    q.advance(10.0)
    assert cam(q, "return cam.pan, cam.tilt, cam.zoomPos") == (170, -30, 1)
    q.budget()


def test_demo_view_draws_the_room_through_pan_tilt_zoom():
    q = boot("Demo (simulated)")
    # the engine's Camera View path: a drawCamera hook on the instance
    q.run("TouchPad.inst.drawCamera = function(self, c) TouchPad.E.camera:drawView(c) end")
    q.run("TouchPad.E.invalidate()")
    q.advance(0.1)
    svg = q.camera_view()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 270"')
    assert "DEMO CAM" in svg and "x1.0" in svg and "P 0  T 0" in svg
    assert all(ord(ch) < 127 for ch in svg)
    assert svg.count("<ellipse") == 1                       # the table
    assert svg.count("<circle") == 6                        # six chairs
    assert svg.count("<rect") >= 8                          # walls, window, door, screen, badge
    assert len(svg) < 4000
    # a pan to the right moves the scene left
    m = re.search(r'<ellipse cx="([-\d.]+)"', svg)
    cx0 = float(m.group(1))
    cam(q, "cam.pan = 10 cam:gotoPosition(10, 0, 0)")
    q.advance(0.3)
    svg2 = q.camera_view()
    cx1 = float(re.search(r'<ellipse cx="([-\d.]+)"', svg2).group(1))
    assert cx1 < cx0 - 60 and "P 10" in svg2
    # zoom narrows the field of view: the table grows and the factor reads x6.5
    cam(q, "cam:gotoPosition(10, 0, 0.5)")
    q.advance(3.0)
    svg3 = q.camera_view()
    rx0 = float(re.search(r'<ellipse cx="[-\d.]+" cy="[-\d.]+" rx="([-\d.]+)"', svg2).group(1))
    rx1 = float(re.search(r'<ellipse cx="[-\d.]+" cy="[-\d.]+" rx="([-\d.]+)"', svg3).group(1))
    assert rx1 > rx0 * 5 and "x6.5" in svg3
    b = q.budget()
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000


# ---------------------------------------------------------------- qsys camera

def test_qsys_binds_the_candidate_names_and_reports_status():
    q, _ = qsys_cam()
    assert cam_status(q) == "Camera Cam1: pan/tilt, zoom, home, position"
    names = cam(q, "return cam.names.left, cam.names.upleft, cam.names.zoomin, cam.names.panspeed, cam.names.home, cam.names.position, cam.names.privacy")
    assert names == ("pan.left", "pan.left.tilt.up", "zoom.in", "setup.pan.speed", "preset.home.load", "ptz.preset", "toggle.privacy")
    # the community plugin spelling binds too, and reports the missing position control
    q2, _ = qsys_cam("PTZCam", PLUGIN_CONTROLS, ctype="PTZOptics_Camera")
    assert cam_status(q2) == "Camera PTZCam: pan/tilt, zoom, home; no position control (framing and dial need one)"
    assert cam(q2, "return cam.names.left, cam.names.zoomout, cam.names.panspeed, cam.names.home") == \
        ("PanTiltDrive-Lt", "CAM_Zoom-Z-", "CAM_Pan-Speed", "PanTiltDrive-Hm")
    assert cam(q2, "return cam.ctl.position == nil and cam.ctl.upleft == nil")


def test_qsys_drive_releases_the_old_direction_before_the_new_one():
    q, c = qsys_cam()
    watch(q, "Cam1", ["pan.left", "pan.right", "tilt.up", "tilt.down", "pan.left.tilt.up", "pan.right.tilt.down"])
    cam(q, "cam:drive(1, 0)")
    assert log(q) == ["pan.right=true"]
    cam(q, "cam:drive(1, 0)")                                # a repeat presses nothing again
    assert log(q) == ["pan.right=true"]
    cam(q, "cam:drive(-1, 0)")
    assert log(q) == ["pan.right=true", "pan.right=false", "pan.left=true"]
    cam(q, "cam:drive(-0.5, 0.5)")                           # a diagonal control exists: use it
    assert log(q)[3:] == ["pan.left=false", "pan.left.tilt.up=true"]
    cam(q, "cam:drive(0.3, -0.3)")
    assert log(q)[5:] == ["pan.left.tilt.up=false", "pan.right.tilt.down=true"]
    cam(q, "cam:drive(0, -1)")
    assert log(q)[7:] == ["pan.right.tilt.down=false", "tilt.down=true"]
    assert c.get("tilt.down")["Boolean"] is True and c.get("pan.right")["Boolean"] is False
    # a stop writes false three times on every held direction
    count_writes(q, "down")
    cam(q, "cam:drive(0, 0)")
    assert q.run("return CAMWRITES") == 3
    assert log(q)[9:] == ["tilt.down=false"]
    assert c.get("tilt.down")["Boolean"] is False
    cam(q, "cam:drive(0, 0)")                                # a second stop has nothing to release
    assert q.run("return CAMWRITES") == 3


def test_qsys_without_diagonals_presses_both_axes():
    ctls = {k: v for k, v in NC_CONTROLS.items() if ".tilt." not in k}
    q, c = qsys_cam("Cam3", ctls)
    watch(q, "Cam3", ["pan.left", "pan.right", "tilt.up", "tilt.down"])
    cam(q, "cam:drive(-1, 1)")
    assert log(q) == ["pan.left=true", "tilt.up=true"]
    cam(q, "cam:drive(1, 1)")
    assert log(q)[2:] == ["pan.left=false", "pan.right=true"]   # tilt.up stays held
    assert c.get("tilt.up")["Boolean"] is True
    cam(q, "cam:stop()")
    assert log(q)[4:] == ["pan.right=false", "tilt.up=false"]
    assert all(c.get(n)["Boolean"] is False for n in ("pan.left", "pan.right", "tilt.up", "tilt.down"))


def test_qsys_applies_maxspeed_and_restores_the_speed_sliders():
    q, c = qsys_cam()
    cam(q, "cam:drive(1, 0)")
    assert near(c.get("setup.pan.speed")["Value"], 0.5)      # |1| x MaxSpeed 50 %
    assert near(c.get("setup.tilt.speed")["Value"], 0.0)
    q.set_pin("MaxSpeed", 80)
    cam(q, "cam:drive(0.5, -1)")
    assert near(c.get("setup.pan.speed")["Value"], 0.4) and near(c.get("setup.tilt.speed")["Value"], 0.8)
    cam(q, "cam:drive(0, 0)")
    assert near(c.get("setup.pan.speed")["Value"], 0.3)      # the camera's own values come back
    assert near(c.get("setup.tilt.speed")["Value"], 0.2)
    # the community plugin's 1..24 knob gets the same Position
    q2, c2 = qsys_cam("PTZCam", PLUGIN_CONTROLS, ctype="PTZOptics_Camera")
    q2.set_pin("MaxSpeed", 100)
    cam(q2, "cam:drive(1, 0)")
    assert near(c2.get("CAM_Pan-Speed")["Position"], 1.0) and near(c2.get("CAM_Pan-Speed")["Value"], 24)
    cam(q2, "cam:stop()")
    assert near(c2.get("CAM_Pan-Speed")["Value"], 12)


def test_qsys_zoom_home_privacy_and_position():
    q, c = qsys_cam()
    watch(q, "Cam1", ["zoom.in", "zoom.out", "preset.home.load", "toggle.privacy"])
    cam(q, "cam:zoom(1)")
    assert log(q) == ["zoom.in=true"] and near(c.get("setup.zoom.speed")["Value"], 0.5)
    q.set_pin("ZoomSpeed", 20)
    cam(q, "cam:zoom(-0.5)")
    assert log(q)[1:] == ["zoom.in=false", "zoom.out=true"] and near(c.get("setup.zoom.speed")["Value"], 0.1)
    count_writes(q, "zoomout")
    cam(q, "cam:zoom(0)")
    assert log(q)[3:] == ["zoom.out=false"] and q.run("return CAMWRITES") == 3
    assert near(c.get("setup.zoom.speed")["Value"], 0.4)      # restored
    # the ZoomIn / ZoomOut pad buttons through the onControl helper
    q.set_pin("ZoomIn", True)
    assert cam(q, "return cam:onControl('ZoomIn', 1, Controls.ZoomIn)") is True
    assert c.get("zoom.in")["Boolean"] is True
    q.set_pin("ZoomIn", False)
    cam(q, "cam:onControl('ZoomIn', 1, Controls.ZoomIn)")
    assert c.get("zoom.in")["Boolean"] is False
    assert cam(q, "return cam:onControl('Lock', 1, Controls.Lock)") is False
    # home is a trigger, privacy a toggle
    assert cam(q, "return cam:home()") is True
    assert "preset.home.load=true" in log(q) or "preset.home.load=false" in log(q)
    cam(q, "cam:privacy(true)")
    assert c.get("toggle.privacy")["Boolean"] is True
    # position: the first three numbers of ptz.preset are pan, tilt, zoom (25 -> 0.25)
    assert cam(q, "return cam:getPosition()") == (12.5, -3.0, 0.25)
    assert cam(q, "local r cam:getPosition(function(p, t, z) r = p + t + z end) return r") == 9.75
    cam(q, "cam:gotoPosition(-20, 5, 0.5)")
    assert c.get("ptz.preset")["String"] == "-20.0000, 5.0000, 0.5000"   # the read shape is kept
    cam(q, "cam:gotoPosition(1, 2)")
    assert c.get("ptz.preset")["String"] == "1.0000, 2.0000, 0.5000"     # zoom unchanged
    q.budget()


def test_qsys_missing_camera_warns_and_binds_when_it_appears():
    q = boot("Q-SYS Camera", {"Camera Name": "Cam9"})
    assert cam_status(q) == "No camera component named Cam9"
    cam(q, "cam:drive(1, 0) cam:zoom(1) cam:stop()")         # no camera: nothing to do, no error
    assert cam(q, "return cam:getPosition()") is None
    assert cam(q, "return cam:home()") is False
    c = q.add_component("Cam9", "onvif_camera_operative", controls={
        "pan.left": {"Boolean": False}, "pan.right": {"Boolean": False},
        "tilt.up": {"Boolean": False}, "tilt.down": {"Boolean": False}})
    cam(q, "cam:drive(0, -1)")                                # within a second of the last try: not yet
    assert c.get("tilt.down")["Boolean"] is False
    q.advance(1.1)
    cam(q, "cam:drive(0, -1)")
    assert c.get("tilt.down")["Boolean"] is True
    assert cam_status(q) == "Camera Cam9: pan/tilt; no position control (framing and dial need one)"
    assert cam(q, "return cam:gotoPosition(0, 0, 0)") is False
    blank = boot("Q-SYS Camera", {"Camera Name": ""})
    assert cam_status(blank) == "Q-SYS Camera: set the Camera Name property"
    # a component without any PTZ control is reported as unusable
    def add(qq):
        qq.add_component("Mixer", "mixer", controls={"gain": {"Value": 0}})
    bad = boot("Q-SYS Camera", {"Camera Name": "Mixer"}, before_load=add)
    assert cam_status(bad) == "Camera Mixer: no PTZ controls found (needs Script Access)"


# ---------------------------------------------------------------- VISCA over IP

def test_visca_ptzoptics_raw_tcp_drive_and_stop_three_times():
    q = visca("PTZOptics", "10.0.0.9")
    assert q.tcp_connects == [("10.0.0.9", 5678)] and q.udp_sent == []
    assert cam_status(q) == "VISCA PTZOptics TCP 10.0.0.9:5678"
    cam(q, "cam:drive(1, 0)")
    sent = [d for _, _, d in q.tcp_sent]
    assert sent == [b"\x81\x01\x06\x01\x0c\x01\x02\x03\xff"]     # right, pan 12 of 24 (MaxSpeed 50 %)
    cam(q, "cam:drive(1, 0)")                                     # identical drive: not resent
    assert len(q.tcp_sent) == 1
    q.set_pin("MaxSpeed", 100)
    cam(q, "cam:drive(-1, 1)")
    assert q.tcp_sent[-1][2] == b"\x81\x01\x06\x01\x18\x14\x01\x01\xff"   # up left, 0x18 / tilt max 0x14
    cam(q, "cam:drive(0, -0.25)")
    assert q.tcp_sent[-1][2] == b"\x81\x01\x06\x01\x01\x05\x03\x02\xff"   # down, pan speed floor 1
    cam(q, "cam:drive(0, 0)")
    stops = [d for _, _, d in q.tcp_sent[-3:]]
    assert stops == [b"\x81\x01\x06\x01\x01\x05\x03\x03\xff"] * 3
    assert len(q.tcp_sent) == 6
    cam(q, "cam:home()")
    assert q.tcp_sent[-1][2] == b"\x81\x01\x06\x04\xff"


def test_visca_sony_header_reset_and_sequence_numbers():
    q = visca("Sony")
    assert q.tcp_connects == []
    raw = [d for _, _, d in q.udp_sent]
    assert raw[0] == b"\x02\x00\x00\x01\x00\x00\x00\x00\x01"       # RESET control command first
    assert all(ip == "10.0.0.5" and port == 52381 for ip, port, _ in q.udp_sent)
    cam(q, "cam:drive(0, 1)")
    # up: pan speed floors at 01, tilt 12 of 0x17 (MaxSpeed 50 %); sequence 1 after the RESET
    assert q.udp_sent[-1][2] == b"\x01\x00\x00\x09\x00\x00\x00\x01" + b"\x81\x01\x06\x01\x01\x0c\x03\x01\xff"
    cam(q, "cam:drive(0, 0)")
    seqs = [d[4:8] for _, _, d in q.udp_sent[2:]]
    assert seqs == [b"\x00\x00\x00\x02", b"\x00\x00\x00\x03", b"\x00\x00\x00\x04"]
    assert all(d[:4] == b"\x01\x00\x00\x09" for _, _, d in q.udp_sent[2:])
    assert udp_payloads(q)[-1] == b"\x81\x01\x06\x01\x01\x0c\x03\x03\xff"
    cam(q, "cam:getPosition(function() end)")
    inq = q.udp_sent[-2:]
    assert inq[0][2] == b"\x01\x10\x00\x05\x00\x00\x00\x05\x81\x09\x06\x12\xff"   # inquiry type 01 10
    assert inq[1][2] == b"\x01\x10\x00\x05\x00\x00\x00\x06\x81\x09\x04\x47\xff"
    # Sony tilt speed tops at 0x17
    q.set_pin("MaxSpeed", 100)
    cam(q, "cam:drive(1, -1)")
    assert udp_payloads(q)[-1] == b"\x81\x01\x06\x01\x18\x17\x02\x02\xff"


def test_visca_zoom_only_changes_send_only_zoom():
    q = visca("AVer")
    n0 = len(q.udp_sent)
    cam(q, "cam:zoom(1)")
    assert udp_payloads(q)[n0:] == [b"\x81\x01\x04\x07\x24\xff"]          # tele, p = 4 of 7 at 50 %
    cam(q, "cam:zoom(1)")
    assert len(q.udp_sent) == n0 + 1                                       # not resent
    cam(q, "cam:zoom(-0.5)")
    assert udp_payloads(q)[-1] == b"\x81\x01\x04\x07\x32\xff"              # wide, p = 2
    q.set_pin("ZoomSpeed", 100)
    cam(q, "cam:zoom(-1)")
    assert udp_payloads(q)[-1] == b"\x81\x01\x04\x07\x37\xff"
    cam(q, "cam:zoom(0)")
    assert udp_payloads(q)[-3:] == [b"\x81\x01\x04\x07\x00\xff"] * 3       # zoom stop three times
    assert all(p[:4] != b"\x81\x01\x06\x01" for p in udp_payloads(q)[n0:])  # no pan/tilt packet at all
    # the pad's ZoomOut button through the helper
    q.set_pin("ZoomOut", True)
    cam(q, "cam:onControl('ZoomOut', 1, Controls.ZoomOut)")
    assert udp_payloads(q)[-1] == b"\x81\x01\x04\x07\x37\xff"
    q.set_pin("ZoomOut", False)
    cam(q, "cam:onControl('ZoomOut', 1, Controls.ZoomOut)")
    assert udp_payloads(q)[-1] == b"\x81\x01\x04\x07\x00\xff"


def test_visca_absolute_position_uses_the_brand_scale():
    q = visca("Sony")
    cam(q, "cam:gotoPosition(170, -20, 1)")
    p = udp_payloads(q)
    assert p[-2] == b"\x81\x01\x06\x02\x0c\x0c" + b"\x02\x02\x00\x00" + b"\x0f\x0c\x00\x00" + b"\xff"
    assert p[-1] == b"\x81\x01\x04\x47\x04\x00\x00\x00\xff"                 # zoom direct 0x4000
    cam(q, "cam:gotoPosition(-85, 45)")                                      # no zoom argument: no zoom packet
    assert udp_payloads(q)[-1] == b"\x81\x01\x06\x02\x0c\x0c" + b"\x0e\x0f\x00\x00" + b"\x00\x09\x00\x00" + b"\xff"
    cam(q, "cam:gotoPosition(0, 0, 0.5)")
    assert udp_payloads(q)[-1] == b"\x81\x01\x04\x47\x02\x00\x00\x00\xff"
    t = visca("PTZOptics", "10.0.0.9")
    t.set_pin("MaxSpeed", 100)
    cam(t, "cam:gotoPosition(10, 10, 0)")
    # 10 degrees = 0x0200 units: nibbles 00 02 00 00; speeds 0x18 / 0x14 at MaxSpeed 100 %
    assert t.tcp_sent[-2][2] == b"\x81\x01\x06\x02\x18\x14" + b"\x00\x02\x00\x00" + b"\x00\x02\x00\x00" + b"\xff"
    assert t.tcp_sent[-1][2] == b"\x81\x01\x04\x47\x00\x00\x00\x00\xff"
    cam(t, "cam:home()")
    assert t.tcp_sent[-1][2] == b"\x81\x01\x06\x04\xff"


def test_visca_inquiries_are_answered_per_reply():
    q = visca("Sony")
    cam(q, "POS = 'none' cam:getPosition(function(p, t, z) POS = {p, t, z} end)")
    # the reply carries the same header shape (01 11), one message per datagram
    q.inject_udp(b"\x01\x11\x00\x0b\x00\x00\x00\x05" + b"\x90\x50" + b"\x01\x01\x00\x00" + b"\x0f\x0e\x00\x00" + b"\xff")
    assert q.run("return POS") == "none"                                    # zoom still missing
    q.inject_udp(b"\x01\x11\x00\x07\x00\x00\x00\x06" + b"\x90\x50\x02\x00\x00\x00\xff")
    p, t, z = q.run("return POS[1], POS[2], POS[3]")
    assert near(p, 0x1100 / (0x2200 / 170)) and near(t, -0x200 / (0x2200 / 170)) and near(z, 0.5)
    assert near(p, 85) and near(t, -10)
    assert cam(q, "return cam.pending == nil and cam.posReplies == 1")
    # ACK / completion / 20-bit replies are parsed too; an error reply shows on CameraStatus
    q.inject_udp(b"\x01\x11\x00\x03\x00\x00\x00\x07\x90\x41\xff")
    q.inject_udp(b"\x01\x11\x00\x0c\x00\x00\x00\x08" + b"\x90\x50" + b"\x01\x05\x04\x00\x00" + b"\x00\x00\x00\x00" + b"\xff")
    assert near(cam(q, "return cam.pan"), 170) and near(cam(q, "return cam.tilt"), 0)
    q.inject_udp(b"\x01\x11\x00\x04\x00\x00\x00\x09\x90\x60\x02\xff")
    assert cam_status(q) == "VISCA Sony UDP 10.0.0.5:52381: camera error 02"
    # a later complete answer clears the warning
    cam(q, "cam:getPosition(function(p, t, z) POS = {p, t, z} end)")
    q.inject_udp(b"\x01\x11\x00\x0b\x00\x00\x00\x0a" + b"\x90\x50" + b"\x00\x00\x00\x00" + b"\x00\x00\x00\x00" + b"\xff")
    q.inject_udp(b"\x01\x11\x00\x07\x00\x00\x00\x0b" + b"\x90\x50\x00\x00\x00\x00\xff")
    assert q.run("return POS[1], POS[2], POS[3]") == (0, 0, 0)
    assert cam_status(q) == "VISCA Sony UDP 10.0.0.5:52381: OK"
    # raw TCP: replies arrive as a stream, split on FF, even across two reads
    t = visca("PTZOptics", "10.0.0.9")
    cam(t, "POS = 'none' cam:getPosition(function(p, tt, z) POS = {p, tt, z} end)")
    assert [d for _, _, d in t.tcp_sent[-2:]] == [b"\x81\x09\x06\x12\xff", b"\x81\x09\x04\x47\xff"]
    t.inject_tcp(b"\x90\x50" + b"\x0f\x0e\x00\x00" + b"\x01\x01\x00\x00" + b"\xff" + b"\x90\x50\x01")
    assert t.run("return POS") == "none"
    t.inject_tcp(b"\x00\x00\x00\xff")
    p, tt, z = t.run("return POS[1], POS[2], POS[3]")
    assert near(p, -10) and near(tt, 85) and near(z, 0.25)


def test_visca_camera_that_never_answers_sets_a_warning():
    q = visca("Lumens")
    for i in range(3):
        cam(q, "CB = 'pending' cam:getPosition(function(p) CB = (p == nil) and 'nil' or 'value' end)")
        q.advance(1.1)
        assert q.run("return CB") == "nil"                                   # the timeout answers nil
        if i < 2:
            assert "no answer" not in cam_status(q)
    assert cam_status(q) == "VISCA Lumens UDP 10.0.0.5:52381: no answer to position inquiries (framing and dial need them)"
    assert cam(q, "return cam.misses") == 3
    # a newer inquiry replaces a pending one (the older caller gets nil)
    cam(q, "A = 'wait' B = 'wait' cam:getPosition(function(p) A = tostring(p) end) cam:getPosition(function(p) B = tostring(p) end)")
    assert q.run("return A, B") == ("nil", "wait")
    q.advance(1.1)
    assert q.run("return B") == "nil"


def test_visca_brand_table_and_ip_changes():
    expect = {"PTZOptics": ("tcp", 5678), "Sony": ("udp", 52381), "AVer": ("udp", 52381), "Lumens": ("udp", 52381),
              "Marshall": ("udp", 52381), "BirdDog": ("udp", 52381), "Avonic": ("udp", 52381),
              "Generic Sony header": ("udp", 52381), "Generic raw TCP": ("tcp", 5678)}
    for brand, (transport, port) in expect.items():
        q = visca(brand, "192.168.1.20")
        if transport == "tcp":
            assert q.tcp_connects == [("192.168.1.20", port)] and q.udp_sent == [], brand
            cam(q, "cam:drive(1, 0)")
            assert q.tcp_sent[-1][2][:1] == b"\x81", brand                  # raw, no header
        else:
            assert q.tcp_connects == [] and q.udp_sent[0][:2] == ("192.168.1.20", port), brand
            assert q.udp_sent[0][2] == b"\x02\x00\x00\x01\x00\x00\x00\x00\x01", brand
            cam(q, "cam:drive(1, 0)")
            assert q.udp_sent[-1][2][:2] == b"\x01\x00", brand
        assert cam_status(q) == "VISCA %s %s 192.168.1.20:%d" % (brand, transport.upper(), port)
    # BirdDog speed limits 0x15 / 0x12
    b = visca("BirdDog")
    b.set_pin("MaxSpeed", 100)
    cam(b, "cam:drive(1, 1)")
    assert udp_payloads(b)[-1] == b"\x81\x01\x06\x01\x15\x12\x02\x01\xff"
    # ip:port in the CameraIP text, and a change of IP reconnects (the old socket is closed)
    p = visca("PTZOptics", "10.1.1.1:1259")
    assert p.tcp_connects == [("10.1.1.1", 1259)]
    p.set_pin("CameraIP", "10.1.1.2")
    assert cam(p, "return cam:onControl('CameraIP', 1, Controls.CameraIP)") is True
    p.advance(0.05)
    assert p.tcp_connects == [("10.1.1.1", 1259), ("10.1.1.2", 5678)]
    cam(p, "cam:drive(0, 1)")
    assert p.tcp_sent[-1][:2] == ("10.1.1.2", 5678)
    # a blank IP: nothing is sent, the status asks for it; writes before a TCP connect are queued
    blank = boot("VISCA over IP", {"VISCA Brand": "Sony"})
    assert cam_status(blank) == "VISCA Sony: enter the camera IP on the Setup page" and blank.udp_sent == []
    cam(blank, "cam:drive(1, 0)")
    assert blank.udp_sent == []
    early = QSys(mode="Joystick", props={"Camera Control": "VISCA over IP", "VISCA Brand": "PTZOptics"},
                 plugin=PLUGIN, picker="Color_Picker", runtime=False)
    early.set_pin("CameraIP", "10.0.0.9")
    early._dispatch("load", early._chunk)
    cam(early, "cam:drive(1, 0)")                                 # before the connect completed
    assert early.tcp_connects == [("10.0.0.9", 5678)] and early.tcp_sent == []
    early.advance(0.2)
    assert [d for _, _, d in early.tcp_sent] == [b"\x81\x01\x06\x01\x0c\x01\x02\x03\xff"]
    cam(early, "cam:close()")                                     # close stops pan/tilt (x3) and zoom (x3) first
    assert early.tcp_sent[-6][2] == b"\x81\x01\x06\x01\x0c\x01\x03\x03\xff"
    assert early.tcp_sent[-1][2] == b"\x81\x01\x04\x07\x00\xff"
    assert cam(early, "return cam.sock == nil")


def test_camera_drivers_stay_within_the_budget():
    # the loops run inside an E.after callback so the harness counts them as one handler
    v = visca("Sony")
    v.run("""
      TouchPad.E.after(0.01, function()
        local cam = TouchPad.E.camera
        for i = 1, 40 do                       -- two seconds of 20 Hz reports in one handler
          cam:drive((i % 7) / 3 - 1, (i % 5) / 2 - 1)
          cam:zoom((i % 3) - 1)
          if i % 10 == 0 then cam:getPosition(function() end) end
        end
        cam:stop()
      end)
    """)
    v.advance(0.02)
    assert len(v.udp_sent) > 60
    for _ in range(20):
        v.inject_udp(b"\x01\x11\x00\x0b\x00\x00\x00\x05" + b"\x90\x50" + b"\x01\x01\x00\x00" + b"\x0f\x0e\x00\x00" + b"\xff")
        v.inject_udp(b"\x01\x11\x00\x07\x00\x00\x00\x06" + b"\x90\x50\x02\x00\x00\x00\xff")
    b = v.budget()
    assert 1000 < b["handlers"]["callafter"] < 60000 and b["max_handler"] < 120000   # under 750 per call
    q, _ = qsys_cam()
    q.run("""
      TouchPad.E.after(0.01, function()
        local cam = TouchPad.E.camera
        for i = 1, 40 do
          cam:drive((i % 7) / 3 - 1, (i % 5) / 2 - 1)
          cam:zoom((i % 3) - 1)
          cam:getPosition(function() end)
        end
        cam:stop()
      end)
    """)
    q.advance(0.02)
    b = q.budget()
    assert 1000 < b["handlers"]["callafter"] < 60000 and b["max_handler"] < 120000   # under 500 per call
    d = boot("Demo (simulated)", {"Max Frame Rate": "30"})
    d.run("TouchPad.inst.drawCamera = function(self, c) TouchPad.E.camera:drawView(c) end")
    d.set_pin("MaxSpeed", 100)
    cam(d, "cam:drive(0.7, -0.4) cam:zoom(1)")
    d.advance(3.0)
    b = d.budget()
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert d.icon_writes("CameraView") >= 30                       # the view follows the motion
