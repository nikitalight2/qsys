# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Joystick mode (12_mode_joystick.lua)
"""The Joystick puts the stick where the finger is, measured from the pad's
centre and scaled by the base radius; outputs JoyX / JoyY (-1..1), Magnitude
(0..1) and the four direction LEDs; Deadzone, Curve, Sticky, Home, InvertPan
and InvertTilt shape it; the stick springs back over 0.15 s; a camera driver
is driven at the stick's output; a stuck Panel Touch is released after 30 s.
Runs on the per-mode build plugins/.build/NikitaTouchPad-joystick.qplug."""
import math
import re

from harness import QSys

PLUGIN = "plugins/.build/NikitaTouchPad-joystick.qplug"
CX, CY, R = 250.0, 250.0, 222.0          # 500 x 500 pad: inset 28, base radius 222
KNOB = 28.0
DZ = 0.08
MODE_CONTROLS = ("JoyX", "JoyY", "Magnitude", "DirLeft", "DirRight", "DirUp", "DirDown",
                 "Deadzone", "Curve", "Sticky", "Home", "InvertPan", "InvertTilt")
CAMERA_CONTROLS = ("ZoomIn", "ZoomOut", "MaxSpeed", "ZoomSpeed", "CameraStatus")


def boot(**kw):
    kw.setdefault("mode", "Joystick")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def demo(**kw):
    props = {"Camera Control": "Demo (simulated)"}
    props.update(kw.pop("props", {}))
    return boot(props=props, **kw)


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


def joy(q):
    return q.pin("JoyX")["Value"], q.pin("JoyY")["Value"], q.pin("Magnitude")["Value"]


def leds(q):
    return tuple(q.pin(n)["Boolean"] for n in ("DirLeft", "DirRight", "DirUp", "DirDown"))


def circles(svg):
    """[(cx, cy, r)] of every <circle> in the SVG."""
    out = []
    for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)"', svg):
        out.append(tuple(float(v) for v in m.groups()))
    return out


def shaped(m, dz=DZ):
    """The linear response of a travel m through the deadzone."""
    return 0.0 if m <= dz else (m - dz) / (1 - dz)


def at(frac, deg):
    """Pad point at frac x R from the centre, at deg degrees (0 = right, 90 = up)."""
    return (CX + frac * R * math.cos(math.radians(deg)), CY - frac * R * math.sin(math.radians(deg)))


def layout(q, page_index):
    """Layout keys of a page of the running instance's properties."""
    return q.run("local p = Properties p.page_index.Value = %d local l = GetControlLayout(p) "
                 "local out = {} for k, v in pairs(l) do out[k] = v end return out" % page_index)


# ---------------------------------------------------------------- controls and layout

def test_joystick_controls_pins_and_choices():
    q = boot()
    names = q.control_names()
    assert len(names) == 26 + len(MODE_CONTROLS)
    for n in MODE_CONTROLS:
        assert n in names, n
    for n in CAMERA_CONTROLS:
        assert n not in names, n                         # Camera Control = None
    assert q.run("return TouchPad.E.camera == nil")
    assert q.pin("Curve")["String"] == "Linear"
    assert list(q.pin("Curve")["Choices"]) == ["Linear", "Squared", "Cubed"]   # set at start
    assert near(q.pin("Deadzone")["Value"], 0.08)
    assert joy(q) == (0, 0, 0) and leds(q) == (False, False, False, False)
    outputs = layout(q, 3)                                 # Pad, Setup, Outputs, ...
    assert outputs["JoyX"]["PrettyName"] == "Joystick~Joy X"
    assert outputs["DirLeft"]["PrettyName"] == "Joystick~Dir Left"
    assert outputs["Home"]["PrettyName"] == "Joystick~Home"          # Both: listed as an output
    assert outputs["InvertTilt"]["PrettyName"] == "Joystick~Invert Tilt"
    assert "Deadzone" not in outputs and "Sticky" not in outputs     # inputs are not outputs
    d = demo()
    for n in CAMERA_CONTROLS + ("CameraView",):
        assert d.has_control(n), n
    assert not d.has_control("CameraIP")
    assert d.run("return TouchPad.E.camera.kind") == "demo"
    assert d.pin("CameraStatus")["String"] == "Demo camera ready"


def test_joystick_layout_pages_and_lint():
    q = boot()
    pad = layout(q, 1)
    for key, legend in (("Home", "HOME"), ("Sticky", "STICKY"), ("InvertPan", "INVERT PAN"),
                        ("InvertTilt", "INVERT TILT"), ("Lock", "LOCK")):
        assert pad[key]["Legend"] == legend, key
        assert float(pad[key]["Position"][1]) == 16 + 500 + 12          # the side column
    assert pad["Display"]["Size"][1] == 500 and pad["Display"]["Size"][2] == 500
    setup = layout(q, 2)
    assert setup["Deadzone"]["Style"] == "Knob" and setup["Curve"]["Style"] == "ComboBox"
    assert setup["Sticky"]["ButtonStyle"] == "Toggle" and setup["Home"]["ButtonStyle"] == "Trigger"
    assert setup["InvertPan"]["PrettyName"] == "Joystick~Invert Pan"
    demo_pad = layout(demo(), 1)
    assert demo_pad["ZoomIn"]["Legend"] == "ZOOM +" and demo_pad["Home"]["Legend"] == "HOME"
    assert q.layout_lint(matrix=[{}, {"Camera Control": "Demo (simulated)"},
                                 {"Camera Control": "VISCA over IP"}, {"Camera Control": "Q-SYS Camera"},
                                 {"Pad Width": 120, "Pad Height": 120}, {"Pad Width": 1600, "Pad Height": 300},
                                 {"Pad Width": 300, "Pad Height": 1200}]) == []


# ---------------------------------------------------------------- drawing

def test_joystick_idle_drawing_base_knob_readout_and_hint():
    q = boot()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    cs = circles(svg)
    assert (CX, CY, R + 4) in cs and (CX, CY, R) in cs and (CX, CY, R / 2) in cs   # the base
    assert (CX, CY, KNOB) in cs                                                     # the knob at rest
    assert 'r="17.8"' in svg and "stroke-dasharray" in svg                          # the deadzone ring
    assert svg.count('d="M9 5l7 7-7 7"') == 1 and svg.count('d="M15 5l-7 7 7 7"') == 1   # rim chevrons
    assert "X +0.00   Y +0.00" in svg
    assert "Drag the stick. Double tap: home" in svg
    assert q.pin("Gesture")["String"] == "DRAG THE STICK. DOUBLE TAP: HOME"
    assert len(svg) < 4000
    assert "Drag the stick" not in boot(props={"Show Hints": False}).icon()
    light = boot(props={"Theme": "Light"}).icon()
    assert "#E8EAEE" in light and "#2F6FEB" in light                               # well and accent


def test_joystick_drawing_follows_the_stick():
    q = boot()
    q.touch([(CX + R, CY)], lift=False)
    svg = q.icon()
    cs = circles(svg)
    assert (CX + R, CY, KNOB) in cs and (CX + R, CY, KNOB * 1.8) in cs          # finger dot with halo
    assert (CX, CY, KNOB) not in cs
    assert '<line x1="250" y1="250" x2="472" y2="250"' in svg                   # the stem
    assert svg.count('d="M9 5l7 7-7 7"') == 2                                   # right chevron lit
    assert svg.count('d="M15 5l-7 7 7 7"') == 1
    assert "X +1.00   Y +0.00" in svg
    assert "Drag the stick" not in svg
    q.lift()
    svg = q.icon()
    assert (CX, CY, KNOB) in circles(svg) and "<line x1=\"250\" y1=\"250\" x2=" not in svg
    assert "Drag the stick" in svg


# ---------------------------------------------------------------- outputs

def test_joystick_absolute_deflection_and_rim_clamp():
    q = boot()
    q.touch([(CX + R, CY)], lift=False)
    jx, jy, mag = joy(q)
    assert near(jx, 1) and near(jy, 0) and near(mag, 1)
    assert leds(q) == (False, True, False, False)
    q.touch([(CX, CY - R / 2)], lift=False)                 # half way up
    jx, jy, mag = joy(q)
    assert near(jx, 0) and near(jy, shaped(0.5)) and near(mag, shaped(0.5))
    assert leds(q) == (False, False, True, False)
    q.touch([(CX - R / 4, CY + R)], lift=False)             # outside the base: clamped to the rim
    jx, jy, mag = joy(q)
    assert near(mag, 1) and near(math.hypot(jx, jy), 1) and jx < 0 and jy < 0
    assert leds(q) == (False, False, False, True)           # 14 deg off straight down: one LED
    q.touch([(CX + 5, CY - 5)], lift=False)                 # inside the deadzone
    assert joy(q) == (0, 0, 0) and leds(q) == (False, False, False, False)
    q.lift()
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1


def test_joystick_deadzone_and_curve():
    q = boot()
    q.set_pin("Deadzone", 0.2)
    q.advance(0.05)                                          # the frame cap
    assert 'r="44.4"' in q.icon()                            # the ring follows the knob
    q.touch([at(0.1, 0)], lift=False)
    assert joy(q) == (0, 0, 0) and leds(q) == (False, False, False, False)
    q.touch([at(0.6, 0)], lift=False)
    assert near(joy(q)[0], 0.5) and near(joy(q)[2], 0.5)    # (0.6 - 0.2) / 0.8
    q.set_pin("Curve", "Squared")
    assert near(joy(q)[0], 0.25)
    q.set_pin("Curve", "Cubed")
    assert near(joy(q)[0], 0.125) and near(joy(q)[2], 0.125)
    q.set_pin("Curve", "Bogus")                              # unknown text: linear
    assert near(joy(q)[0], 0.5)
    q.set_pin("Deadzone", 0)
    assert near(joy(q)[0], 0.6)
    q.advance(0.05)
    assert "stroke-dasharray" not in q.icon()                # no ring without a deadzone
    q.touch([at(0.6, 180)], lift=False)
    assert near(joy(q)[0], -0.6) and leds(q) == (True, False, False, False)
    q.lift()


def test_joystick_direction_leds_are_eight_way():
    q = boot()
    q.touch([at(1, 45)], lift=False)
    jx, jy, mag = joy(q)
    assert near(jx, math.sqrt(0.5)) and near(jy, math.sqrt(0.5)) and near(mag, 1)
    assert leds(q) == (False, True, True, False)
    q.touch([at(1, 20)], lift=False)
    assert leds(q) == (False, True, False, False)
    q.touch([at(1, 70)], lift=False)
    assert leds(q) == (False, False, True, False)
    q.touch([at(0.8, 225)], lift=False)
    assert leds(q) == (True, False, False, True)
    q.touch([at(0.8, 300)], lift=False)
    assert leds(q) == (False, True, False, True)
    q.lift()
    assert leds(q) == (False, False, False, False)


def test_joystick_inverts_flip_the_outputs_and_leds():
    q = boot()
    q.set_pin("InvertPan", True)
    q.touch([(CX + R, CY)], lift=False)
    assert near(joy(q)[0], -1) and leds(q) == (True, False, False, False)
    q.set_pin("InvertPan", False)                            # applies to the stick in hand
    assert near(joy(q)[0], 1) and leds(q) == (False, True, False, False)
    q.touch([(CX, CY - R)], lift=False)
    assert near(joy(q)[1], 1) and leds(q) == (False, False, True, False)
    q.set_pin("InvertTilt", True)
    assert near(joy(q)[1], -1) and leds(q) == (False, False, False, True)
    q.advance(0.05)
    assert "X +0.00   Y -1.00" in q.icon()
    q.lift()
    assert joy(q) == (0, 0, 0)


# ---------------------------------------------------------------- spring, sticky, home

def test_joystick_springs_back_over_150ms():
    q = boot()
    q.touch([(CX + R, CY)], panel_touch=True, lift=False)
    assert near(joy(q)[0], 1) and q.run("return TouchPad.state.animating")
    q.set_pin("PanelTouch", False)                           # the lift: the spring starts
    q.advance(0.05)
    mid = joy(q)[0]
    assert 0.1 < mid < 0.9
    assert (CX + R, CY, KNOB) not in circles(q.icon()) and (CX, CY, KNOB) not in circles(q.icon())
    q.advance(0.05)
    assert 0 < joy(q)[0] < mid
    q.advance(0.1)
    assert joy(q) == (0, 0, 0) and leds(q) == (False, False, False, False)
    assert (CX, CY, KNOB) in circles(q.icon())
    assert not q.run("return TouchPad.state.animating")      # the animation stops itself
    q.reset_pulses()
    q.tap(CX, CY + R / 2, panel_touch=True)                  # a tap nudges and springs back
    assert q.pulses("Tap") == 1 and joy(q) == (0, 0, 0)


def test_joystick_sticky_holds_home_recentres():
    q = boot()
    q.set_pin("Sticky", True)
    q.touch([(CX + R, CY)], panel_touch=True)
    assert near(joy(q)[0], 1) and leds(q) == (False, True, False, False)
    svg = q.icon()
    assert (CX + R, CY, KNOB) in circles(svg) and (CX + R, CY, KNOB * 1.8) not in circles(svg)
    assert "Drag the stick" in svg
    q.reset_pulses()
    q.set_pin("Home", True)                                  # the Home pin (a pulse: true, then false)
    q.set_pin("Home", False)
    assert joy(q) == (0, 0, 0) and leds(q) == (False, False, False, False)
    assert (CX, CY, KNOB) in circles(q.icon())
    q.touch([(CX, CY - R)], panel_touch=True)
    assert near(joy(q)[1], 1)
    q.reset_pulses()
    q.double_tap(CX + 40, CY + 40, panel_touch=True)         # double tap = home, pulsed out
    assert q.pulses("DoubleTap") == 1 and q.pulses("Home") == 1
    assert joy(q) == (0, 0, 0)
    assert q.pin("Gesture")["String"] == "HOME"
    q.touch([(CX - R, CY)], panel_touch=True)
    assert near(joy(q)[0], -1)
    q.set_pin("Sticky", False)                               # off: springs back at once
    q.advance(0.3)
    assert joy(q) == (0, 0, 0)


def test_joystick_lock_returns_to_centre():
    q = boot()
    q.touch([(CX + R, CY)], panel_touch=True, lift=False)
    assert near(joy(q)[0], 1)
    q.set_pin("Lock", True)
    assert joy(q) == (0, 0, 0) and leds(q) == (False, False, False, False)
    q.advance(0.05)
    svg = q.icon()
    assert "Locked" in svg and (CX, CY, KNOB) in circles(svg)
    assert q.pin("Gesture")["String"] == "LOCKED"
    assert not q.run("return TouchPad.state.animating")
    q.lift()
    q.set_pin("Lock", False)
    assert "Locked" not in q.icon()
    q.touch([(CX, CY - R)], panel_touch=True)
    q.advance(0.2)
    assert joy(q) == (0, 0, 0)                               # the pad works again


def test_joystick_resume_after_an_inferred_lift():
    q = boot()
    pts = [(CX + 20 * i, CY) for i in range(1, 9)]           # a drag to (410, 250)
    q.touch(pts, lift=False)
    held = joy(q)[0]
    assert near(held, shaped(160 / R))
    q.advance(0.5)                                           # silence: the lift is inferred
    assert joy(q) == (0, 0, 0) and q.pin("Touching")["Boolean"] is False
    q.touch([(CX + 170, CY)], lift=False)                    # near the last spot: resumed
    q.advance(0.15)                                          # one axis changed: the landing window
    assert q.pin("Touching")["Boolean"] is True
    assert near(joy(q)[0], shaped(170 / R))
    assert (CX + 170, CY, KNOB) in circles(q.icon())
    q.lift()
    assert joy(q) == (0, 0, 0) and q.pulses("Press") == 1 and q.pulses("Release") == 1


def test_joystick_stuck_panel_touch_releases_after_30s():
    q = demo()
    q.touch([(CX + R, CY)], panel_touch=True, lift=False)
    assert near(joy(q)[0], 1) and near(q.run("return TouchPad.E.camera.panSpeed"), 0.5)
    q.advance(20)
    assert near(joy(q)[0], 1) and q.pin("Touching")["Boolean"] is True
    q.advance(11)
    assert joy(q) == (0, 0, 0) and leds(q) == (False, False, False, False)
    assert q.pin("Touching")["Boolean"] is False
    assert q.run("return TouchPad.E.camera.panSpeed") == 0 and q.run("return TouchPad.E.camera.timer == nil")
    assert not q.run("return TouchPad.state.animating")
    q.set_pin("PanelTouch", False)
    q.touch([(CX, CY - R)], panel_touch=True, lift=False)   # the next touch works
    assert near(joy(q)[1], 1)
    q.lift()


# ---------------------------------------------------------------- camera

def test_joystick_drives_the_demo_camera():
    q = demo()
    cam = lambda code: q.run("local cam = TouchPad.E.camera " + code)
    q.touch([(CX + R, CY)], panel_touch=True, lift=False)
    assert cam("return cam.panSpeed, cam.tiltSpeed") == (0.5, 0.0)   # MaxSpeed 50 %
    q.advance(1.0)
    pan = cam("return cam.pan")
    assert 28 <= pan <= 32
    q.set_pin("MaxSpeed", 100)                                       # applies to the drive in hand
    assert cam("return cam.panSpeed") == 1.0
    q.touch([(CX, CY - R / 2)], lift=False)
    ps, ts = cam("return cam.panSpeed, cam.tiltSpeed")
    assert near(ps, 0) and near(ts, shaped(0.5))
    q.set_pin("PanelTouch", False)                                   # the lift stops the camera at once
    assert cam("return cam.panSpeed, cam.tiltSpeed") == (0.0, 0.0)
    assert 0 < joy(q)[1] < 1                                         # while the stick still springs
    q.advance(0.5)
    assert cam("return cam.timer == nil")
    view = q.camera_view()
    assert view.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 270"')
    assert "DEMO CAM" in view and all(ord(ch) < 127 for ch in view)
    q.set_pin("Home", True)
    assert cam("return cam.target ~= nil")
    q.advance(4.0)
    assert cam("return cam.pan, cam.tilt") == (0, 0)
    assert "P 0  T 0" in q.camera_view()
    q.set_pin("ZoomIn", True)
    assert cam("return cam.zoomSpeed") == 0.5
    q.set_pin("ZoomIn", False)
    assert cam("return cam.zoomSpeed") == 0
    q.set_pin("ZoomOut", True)
    assert cam("return cam.zoomSpeed") == -0.5
    q.set_pin("ZoomOut", False)
    assert "pan 0 tilt 0" in q.pin("CameraStatus")["String"] or q.pin("CameraStatus")["String"] == "Demo camera ready"
    q.budget()


def test_joystick_camera_stops_on_lock_and_sticky_keeps_driving():
    q = demo()
    cam = lambda code: q.run("local cam = TouchPad.E.camera " + code)
    q.set_pin("Sticky", True)
    q.touch([(CX, CY + R)], panel_touch=True)
    assert cam("return cam.tiltSpeed") == -0.5                       # sticky: still driving after the lift
    q.advance(1.0)
    assert cam("return cam.tilt") < -15
    q.set_pin("Lock", True)
    assert joy(q) == (0, 0, 0) and cam("return cam.tiltSpeed") == 0
    q.set_pin("Lock", False)
    q.set_pin("Sticky", False)
    assert q.status().startswith("OK")


# ---------------------------------------------------------------- budget

def test_joystick_frames_and_handlers_stay_within_budget():
    q = demo(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    pts = [(800 + 500 * math.cos(i / 8), 600 + 500 * math.sin(i / 8)) for i in range(100)]
    q.drag(pts, seconds=2.0)
    q.advance(0.5)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 30000 and b["max_handler"] < 60000
    assert len(q.icon()) < 15000
    assert q.icon_writes("CameraView") >= 10                         # the view followed the drive
    assert q.errors == []
