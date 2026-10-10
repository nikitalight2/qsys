# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the PTZ Pad mode (13_mode_ptzpad.lua)
"""Drag to aim: Pan and Tilt (0..1 absolute aim, 0.5 = home), PanSpeed and
TiltSpeed (-1..1 while dragging), the direction LEDs, Sensitivity, Home,
the flips, HFOV and OpticalZoom, the camera controls with a camera set.
Double tap = home; a plain tap moves nothing."""
import re

from harness import QSys

PLUGIN = "plugins/.build/NikitaTouchPad-ptzpad.qplug"
DEMO = "Demo (simulated)"

MODE_CONTROLS = ["Pan", "Tilt", "PanSpeed", "TiltSpeed", "DirLeft", "DirRight", "DirUp", "DirDown",
                 "Sensitivity", "Home", "InvertPan", "InvertTilt", "HFOV", "OpticalZoom"]
CAMERA_CONTROLS = ["ZoomIn", "ZoomOut", "MaxSpeed", "ZoomSpeed", "CameraStatus"]


def boot(**kw):
    kw.setdefault("mode", "PTZ Pad")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


def aim(q):
    return q.pin("Pan")["Value"], q.pin("Tilt")["Value"]


def speeds(q):
    return q.pin("PanSpeed")["Value"], q.pin("TiltSpeed")["Value"]


def leds(q):
    return tuple(q.pin(n)["Boolean"] for n in ("DirLeft", "DirRight", "DirUp", "DirDown"))


def view_box(svg):
    """(x, y, w, h) of the stroked view box (the accent rect with rx=3 and no fill)."""
    m = re.search(r'<rect x="([-\d.]+)" y="([-\d.]+)" width="([-\d.]+)" height="([-\d.]+)" rx="3" fill="none"', svg)
    assert m, "no view box in the drawing"
    return tuple(float(v) for v in m.groups())


def cam(q, code):
    return q.run("local cam = TouchPad.E.camera\n" + code)


def right_drag(q, x0=150, y0=250, dx=200, steps=10, seconds=1.0, **kw):
    pts = [(x0 + dx * i / steps, y0) for i in range(steps + 1)]
    return q.drag(pts, seconds=seconds, **kw)


def up_drag(q, x0=250, y0=400, dy=200, steps=10, seconds=1.0, **kw):
    pts = [(x0, y0 - dy * i / steps) for i in range(steps + 1)]
    return q.drag(pts, seconds=seconds, **kw)


def press(q, x, y, **kw):
    """A finger landing on one spot: the engine waits 0.12 s for the second
    axis when only one of them changed from the picker's last value."""
    q.touch([(x, y)], lift=False, **kw)
    q.advance(0.15)


def test_ptz_controls_pins_and_defaults():
    q = boot()
    names = q.control_names()
    for n in MODE_CONTROLS:
        assert n in names, n
    for n in CAMERA_CONTROLS:
        assert n not in names, n                       # Camera Control = None
    assert len(names) == 26 + len(MODE_CONTROLS)
    assert aim(q) == (0.5, 0.5) and speeds(q) == (0, 0) and leds(q) == (False,) * 4
    assert near(q.pin("Sensitivity")["Value"], 1) and near(q.pin("HFOV")["Value"], 60)
    assert near(q.pin("OpticalZoom")["Value"], 12)
    assert q.pin("Gesture")["String"] == "DRAG TO AIM. DOUBLE TAP = HOME"
    assert q.run("return TouchPad.E.camera") is None
    # pins are grouped and named through the layout
    assert q.layout_lint([{}, {"Camera Control": DEMO}, {"Camera Control": "VISCA over IP"},
                          {"Pad Width": 120, "Pad Height": 120}, {"Pad Width": 1600, "Pad Height": 1200}]) == []
    layout = q.run("local l = GetControlLayout({Mode={Value='PTZ Pad'}, page_index={Value=3}}) return l")
    seen = {k: v["PrettyName"] for k, v in layout.items() if k in ("Pan", "PanSpeed", "DirLeft", "Home", "InvertPan")}
    assert seen == {"Pan": "PTZ Pad~Pan", "PanSpeed": "PTZ Pad~Pan Speed", "DirLeft": "PTZ Pad~Dir Left",
                    "Home": "PTZ Pad~Home", "InvertPan": "PTZ Pad~Invert Pan"}
    setup = q.run("local l = GetControlLayout({Mode={Value='PTZ Pad'}, page_index={Value=2}}) return l")
    assert setup["HFOV"]["PrettyName"] == "Camera~HFOV" and setup["OpticalZoom"]["PrettyName"] == "Camera~Optical Zoom"
    with_cam = boot(props={"Camera Control": DEMO})
    for n in CAMERA_CONTROLS + ["CameraView"]:
        assert n in with_cam.control_names(), n
    assert with_cam.run("return TouchPad.E.camera ~= nil") is True


def test_ptz_drag_moves_the_aim_relative_to_the_pad():
    q = boot()
    right_drag(q, dx=200)                              # 200 px right on a 480 px card (500 - 2 x 10)
    pan, tilt = aim(q)
    assert near(pan, 0.5 + 200 / 480) and near(tilt, 0.5)
    q.drag([(250, 400), (250, 300), (250, 200)], seconds=0.5)   # 200 px up
    pan, tilt = aim(q)
    assert near(pan, 0.5 + 200 / 480) and near(tilt, 0.5 + 200 / 480)
    # the aim is clamped to the scene
    right_drag(q, x0=50, dx=400)
    assert aim(q)[0] == 1.0
    assert q.pulses("Press") == 3 and q.pulses("Release") == 3 and q.pulses("Tap") == 0
    svg = q.icon()
    assert all(ord(ch) < 127 for ch in svg)
    assert "PAN +170  TILT +75" in svg               # degrees readout: Pan 1 -> +170, Tilt 0.917 -> +75


def test_ptz_plain_tap_moves_nothing():
    q = boot()
    q.tap(300, 300)
    assert q.pulses("Tap") == 1 and aim(q) == (0.5, 0.5)
    q.touch([(300, 300), (305, 303), (308, 306)], dt=0.05)     # jitter under the drag threshold
    assert aim(q) == (0.5, 0.5) and speeds(q) == (0, 0)
    # the whole movement counts once the drag is certain: nothing is lost
    q.touch([(300, 300), (308, 300), (316, 300), (330, 300)], dt=0.05)
    assert near(aim(q)[0], 0.5 + 30 / 480)


def test_ptz_speeds_and_direction_leds_while_dragging():
    q = boot()
    right_drag(q, dx=200, steps=10, seconds=1.0, lift=False)   # 200 px/s on a 480 px card: 200 / (480 x 2)
    ps, ts = speeds(q)
    assert near(ps, 200 / (480 * 2.0), 1e-3) and near(ts, 0, 1e-9)
    assert leds(q) == (False, True, False, False)
    assert q.pin("Touching")["Boolean"] is True
    assert q.pulses("Press") == 1
    q.advance(0.2)                                     # a resting finger: the speeds fall to zero
    assert speeds(q) == (0, 0) and leds(q) == (False,) * 4
    q.touch([(350, 250), (350, 200), (350, 150)], dt=0.1, lift=False)   # 500 px/s up
    ps, ts = speeds(q)
    assert near(ps, 0, 1e-9) and near(ts, 500 / (480 * 2.0), 1e-3)
    assert leds(q) == (False, False, True, False)
    q.lift()
    assert speeds(q) == (0, 0) and leds(q) == (False,) * 4
    assert q.pulses("Release") == 1
    # a fast drag saturates at 1
    press(q, 100, 400)
    q.touch([(400, 400)], dt=0.05, lift=False)
    assert speeds(q)[0] == 1.0
    q.lift()
    press(q, 400, 250)
    q.touch([(100, 250)], dt=0.05, lift=False)
    assert speeds(q)[0] == -1.0 and leds(q) == (True, False, False, False)
    q.lift()


def test_ptz_sensitivity_scales_the_drag():
    q = boot()
    q.set_pin("Sensitivity", 2)
    right_drag(q, dx=100, lift=False)
    assert near(aim(q)[0], 0.5 + 2 * 100 / 480)
    assert near(speeds(q)[0], 2 * 100 / (480 * 2.0), 1e-3)
    q.lift()
    q.set_pin("Sensitivity", 0.2)
    up_drag(q, x0=320, dy=200)                         # both axes change from the last spot
    assert near(aim(q)[1], 0.5 + 0.2 * 200 / 480)


def test_ptz_flips_invert_the_axes():
    q = boot()
    q.set_pin("InvertPan", True)
    right_drag(q, dx=100, lift=False)
    assert near(aim(q)[0], 0.5 - 100 / 480)
    assert speeds(q)[0] < 0 and leds(q) == (True, False, False, False)
    q.lift()
    assert "FLIP PAN" in q.icon() and "FLIP TILT" not in q.icon()
    q.set_pin("InvertTilt", True)
    up_drag(q, x0=320, dy=200, lift=False)
    assert near(aim(q)[1], 0.5 - 200 / 480)
    assert speeds(q)[1] < 0 and leds(q) == (False, False, False, True)
    q.lift()
    assert "FLIP PAN FLIP TILT" in q.icon()
    q.set_pin("InvertPan", False)
    q.set_pin("InvertTilt", False)
    q.advance(0.1)
    assert "FLIP" not in q.icon()


def test_ptz_double_tap_homes_and_pulses_home():
    q = boot()
    right_drag(q, dx=150, panel_touch=True)
    q.drag([(250, 300), (250, 200)], seconds=0.3, panel_touch=True)
    assert aim(q) != (0.5, 0.5)
    q.reset_pulses()
    q.double_tap(200, 200, gap=0.15, panel_touch=True)
    assert q.pulses("DoubleTap") == 1 and q.pulses("Home") == 1
    assert q.pin("Gesture")["String"] == "HOME"
    q.advance(0.5)                                     # the aim glides home over 0.25 s
    assert aim(q) == (0.5, 0.5)
    assert speeds(q) == (0, 0)
    # a single tap long after does not home
    right_drag(q, dx=100, panel_touch=True)
    q.advance(1.0)
    q.tap(300, 300, panel_touch=True)
    q.advance(0.5)
    assert near(aim(q)[0], 0.5 + 100 / 480)


def test_ptz_home_pin_and_button():
    q = boot()
    right_drag(q, dx=100)
    q.reset_pulses()
    q.set_pin("Home", True)                            # an external pulse: true then false
    q.set_pin("Home", False)
    q.advance(0.5)
    assert aim(q) == (0.5, 0.5)
    assert q.pulses("Home") == 1                       # only the external edge; the mode did not pulse again
    right_drag(q, dx=100)
    q.trigger("Home")                                  # the Pad page button: handler with Boolean false
    q.advance(0.5)
    assert aim(q) == (0.5, 0.5)


def test_ptz_view_box_follows_hfov_zoom_and_aim():
    q = boot()
    x, y, w, h = view_box(q.icon())
    assert near(w, round(60 / 340 * 480, 1), 0.06) and near(h, round(60 * 9 / 16 / 180 * 480, 1), 0.06)
    assert near(x + w / 2, 250, 0.1) and near(y + h / 2, 250, 0.1)
    q.set_pin("HFOV", 120)
    q.advance(0.1)
    x, y, w2, h2 = view_box(q.icon())
    assert near(w2, 2 * w, 0.15) and near(h2, 2 * h, 0.15)
    right_drag(q, dx=96)                               # Pan 0.7 -> box centre at 10 + 0.7 x 480
    x, y, w3, h3 = view_box(q.icon())
    assert near(x + w3 / 2, 10 + 0.7 * 480, 0.1) and near(w3, w2, 0.1)
    # without a camera OpticalZoom changes nothing (the zoom is read from the camera)
    q.set_pin("OpticalZoom", 40)
    q.advance(0.1)
    assert near(view_box(q.icon())[2], w2, 0.1)
    assert "ZOOM x" not in q.icon()


def test_ptz_demo_camera_follows_the_aim_and_zooms():
    q = boot(props={"Camera Control": DEMO})
    assert "Demo camera" in q.pin("CameraStatus")["String"]
    assert "DEMO CAM" in q.camera_view()
    assert "ZOOM x1.0" in q.icon()
    right_drag(q, dx=96, lift=False)                   # Pan 0.7 -> +68 deg
    assert cam(q, "return cam.target ~= nil or cam.pan ~= 0") is True
    q.lift()
    q.advance(2.0)                                     # 60 deg/s ramp
    assert near(cam(q, "return cam.pan"), 68, 0.01) and near(cam(q, "return cam.tilt"), 0, 0.01)
    assert "P 68" in q.camera_view()
    q.drag([(250, 300), (250, 260)], seconds=0.2)      # 40 px up -> Tilt 0.583 -> +15 deg
    q.advance(1.0)
    assert near(cam(q, "return cam.tilt"), 15, 0.01)
    # zoom in from the Pad page button: the camera zooms, the view box shrinks
    w_before = view_box(q.icon())[2]
    q.set_pin("ZoomIn", True)
    q.advance(1.0)                                     # 0.5/s x ZoomSpeed 50 % = 0.25
    q.set_pin("ZoomIn", False)
    q.advance(0.3)
    z = cam(q, "return cam.zoomPos")
    assert near(z, 0.25, 0.02)
    svg = q.icon()
    factor = 1 + z * 11
    assert "ZOOM x%.1f" % factor in svg
    assert near(view_box(svg)[2], w_before / factor, 0.3)
    q.set_pin("ZoomOut", True)
    q.advance(2.0)
    q.set_pin("ZoomOut", False)
    q.advance(0.3)
    assert near(cam(q, "return cam.zoomPos"), 0, 1e-6) and "ZOOM x1.0" in q.icon()
    # home sends the camera home too
    q.double_tap(200, 200, gap=0.15, panel_touch=True)
    q.advance(3.0)
    assert aim(q) == (0.5, 0.5)
    assert near(cam(q, "return cam.pan"), 0, 0.01) and near(cam(q, "return cam.tilt"), 0, 0.01)


def test_ptz_camera_positions_are_rate_limited_while_dragging():
    q = boot(props={"Camera Control": DEMO})
    q.run("""
      local cam = TouchPad.E.camera
      cam.gotoCount = 0
      local orig = cam.gotoPosition
      cam.gotoPosition = function(self, p, t, z) self.gotoCount = self.gotoCount + 1; return orig(self, p, t, z) end
    """)
    pts = [(100 + 6 * i, 250) for i in range(41)]       # 40 reports in 1.0 s (every 25 ms)
    q.drag(pts, seconds=1.0)
    n = cam(q, "return cam.gotoCount")
    assert 9 <= n <= 13, n                              # about ten a second, plus the final aim at the lift
    assert near(cam(q, "return cam.target and cam.target.pan or cam.pan"), (aim(q)[0] - 0.5) * 340, 0.01)


def test_ptz_lock_stops_the_drag_and_the_camera():
    q = boot(props={"Camera Control": DEMO})
    right_drag(q, dx=100, panel_touch=True, lift=False)
    assert speeds(q)[0] > 0
    q.set_pin("Lock", True)
    q.advance(0.05)
    assert speeds(q) == (0, 0) and leds(q) == (False,) * 4
    assert cam(q, "return cam.target") is None and cam(q, "return cam.panSpeed") == 0
    assert "Locked" in q.icon()
    pan_locked = aim(q)[0]
    assert near(pan_locked, 0.5 + 100 / 480)            # the aim stays where it was
    q.lift()
    q.set_pin("Lock", False)
    q.advance(0.05)
    assert "Locked" not in q.icon() and near(aim(q)[0], pan_locked)
    right_drag(q, dx=48, panel_touch=True)              # the next drag works
    assert near(aim(q)[0], pan_locked + 0.1)


def test_ptz_resume_continues_the_drag_without_a_jump():
    q = boot()
    q.touch([(100, 250), (150, 250), (200, 250)], lift=False)
    q.advance(0.5)                                      # inferred lift
    pan = aim(q)[0]
    assert near(pan, 0.5 + 100 / 480) and speeds(q) == (0, 0)
    press(q, 215, 250)                                  # resumed near the last spot
    assert near(aim(q)[0], pan + 15 / 480)
    q.lift()
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1


def test_ptz_designer_mode_drag():
    q = boot(emulate=True)
    q.drag([(100, 300), (160, 300), (220, 300), (280, 300)], seconds=0.6)
    assert near(aim(q)[0], 0.5 + 180 / 480)
    assert near(aim(q)[1], 0.5)
    assert speeds(q) == (0, 0)


def test_ptz_hints_and_themes():
    q = boot()
    assert "Drag to aim" in q.icon()
    right_drag(q, dx=50, lift=False)
    assert "Drag to aim" not in q.icon()
    q.lift()
    assert "Drag to aim" in q.icon()
    quiet = boot(props={"Show Hints": False})
    assert "Drag to aim" not in quiet.icon()
    assert quiet.pin("Gesture")["String"] == "DRAG TO AIM. DOUBLE TAP = HOME"
    light = boot(props={"Theme": "Light", "Background": "Transparent"})
    svg = light.icon()
    assert "#2F6FEB" in svg and svg.count('<rect x="0" y="0"') == 0
    small = boot(props={"Pad Width": 120, "Pad Height": 120})
    assert 'viewBox="0 0 120 120"' in small.icon() and all(ord(ch) < 127 for ch in small.icon())
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300})
    assert 'viewBox="0 0 1600 300"' in wide.icon()


def test_ptz_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30", "Camera Control": DEMO})
    q.set_pin("ZoomIn", True)
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(100)], seconds=2.0)
    q.set_pin("ZoomIn", False)
    q.advance(1.0)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 15000
    assert len(q.camera_view()) < 20000
