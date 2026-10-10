# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Dial mode (15_mode_dial.lua)
"""An endless jog wheel with a dead centre (the inner 30 % does nothing) and
detents: DialValue (0..1, Both) rises with clockwise turns and is bounded,
Turns sets how many turns cover the range, each detent pulses StepUp or
StepDown, the first 8 degrees of a touch are settling, DialTarget drives a
control position-wise and is followed, a level changed elsewhere while a
finger rests is followed, and with a camera the level drives its zoom and
the wheel shows the zoom factor read back. The last tests are regressions
for review findings (zoom buttons, late camera answers, quantised targets,
notch style, status text, restored levels, step debt, small pads, binding
with a camera)."""
import math
import os
import re

from harness import QSys, DEFAULT_PLUGIN

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
MODE_BUILD = os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-dial.qplug")
PLUGIN = os.environ.get("TOUCHPAD_PLUGIN") or (MODE_BUILD if os.path.exists(MODE_BUILD) else DEFAULT_PLUGIN)
DEMO = "Demo (simulated)"

MODE_CONTROLS = ["DialValue", "StepUp", "StepDown", "Turns", "Detents", "DialTarget"]
CAMERA_CONTROLS = ["ZoomIn", "ZoomOut", "MaxSpeed", "ZoomSpeed", "CameraStatus", "OpticalZoom"]


def boot(**kw):
    kw.setdefault("mode", "Dial")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


def settle(q):
    """Lets the engine's 1.5 s resume window after a lift pass, so the next
    touch is a new one even when it starts where the last one ended."""
    q.advance(1.6)


def geometry(q):
    cx, cy, R, Rdead, Rtrack = q.run("local g = TouchPad.inst.geometry return g.cx, g.cy, g.R, g.Rdead, g.Rtrack")
    return {"cx": cx, "cy": cy, "R": R, "Rdead": Rdead, "Rtrack": Rtrack}


def polar(g, r, deg):
    """Pad pixels (y down) at radius r and canvas angle deg (0 = right, 90 = up)."""
    a = math.radians(deg)
    return (g["cx"] + r * math.cos(a), g["cy"] - r * math.sin(a))


def arc_points(g, r, a0, degrees, steps=None):
    """A finger path around the centre: clockwise for positive degrees."""
    steps = steps or max(2, int(abs(degrees) / 5))
    return [polar(g, r, a0 - degrees * i / steps) for i in range(steps + 1)]


def turn(q, degrees, r=None, a0=90, seconds=None, **kw):
    """A fresh touch that turns the wheel by `degrees` (clockwise positive)."""
    g = geometry(q)
    r = r or g["R"] * 0.7
    pts = arc_points(g, r, a0, degrees)
    return q.drag(pts, seconds=seconds or max(0.3, abs(degrees) / 180), **kw)


def level(q):
    return q.pin("DialValue")["Value"]


def notches(svg):
    """(rotation, count) of the wheel's notch group: the plain notches are one
    path of M..L segments plus one index line."""
    m = re.search(r'<g transform="rotate\(([-\d.]+) [-\d.]+ [-\d.]+\)">(.*?)</g>', svg)
    assert m, "no notch group in the drawing"
    body = m.group(2)
    return float(m.group(1)), body.count("M") + body.count("<line")


def test_dial_controls_pins_defaults_and_layout():
    q = boot()
    names = q.control_names()
    for n in MODE_CONTROLS:
        assert n in names, n
    for n in CAMERA_CONTROLS:
        assert n not in names, n                        # Camera Control = None
    assert len(names) == 26 + len(MODE_CONTROLS)
    assert level(q) == 0 and q.pin("Turns")["Value"] == 2 and q.pin("Detents")["Value"] == 24
    assert q.run("return TouchPad.E.camera") is None
    assert q.pin("Gesture")["String"] == "TURN THE WHEEL. THE CENTRE DOES NOTHING"
    assert q.layout_lint([{}, {"Camera Control": DEMO}, {"Camera Control": "VISCA over IP"},
                          {"Camera Control": "Q-SYS Camera"}, {"Show Hints": False},
                          {"Pad Width": 120, "Pad Height": 120}, {"Pad Width": 1600, "Pad Height": 300}]) == []
    with_cam = boot(props={"Camera Control": DEMO})
    names = with_cam.control_names()
    for n in CAMERA_CONTROLS + ["CameraView"]:
        assert n in names, n
    assert with_cam.run("return TouchPad.E.camera ~= nil") is True
    assert with_cam.pin("OpticalZoom")["Value"] == 12


def test_dial_idle_drawing_wheel_dead_centre_readout_and_hint():
    q = boot()
    g = geometry(q)
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    assert near(g["R"], 200) and near(g["Rdead"], 60) and g["cy"] == 239  # room for the hint line
    assert f'<circle cx="250" cy="239" r="200"' in svg                      # the wheel
    assert f'<circle cx="250" cy="239" r="60"' in svg                       # the dead centre
    assert notches(svg) == (0.0, 24)                                        # 24 detent marks, not turned
    assert ">0%<" in svg and "Turn the wheel" in svg
    assert "ZOOM" not in svg                                                 # no camera: no zoom readout
    no_hint = boot(props={"Show Hints": False})
    assert "Turn the wheel" not in no_hint.icon()
    assert geometry(no_hint)["cy"] == 250


def test_dial_clockwise_turn_raises_the_level_by_degrees_over_turns():
    q = boot()
    # 98 degrees clockwise: 8 settle, 90 count; Turns = 2 -> 90 / 720 = 0.125
    turn(q, 98)
    assert near(level(q), 0.125, 1e-6)
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1
    assert ">12%<" in q.icon() or ">13%<" in q.icon()
    assert 'transform="rotate(90 250 239)"' in q.icon()  # the notches turned with the finger
    settle(q)
    turn(q, -98, a0=-8)                                  # back the same way
    assert near(level(q), 0, 1e-6)
    assert q.errors == []


def test_dial_settling_ignores_the_first_eight_degrees():
    q = boot()
    turn(q, 6)                                           # inside the settling angle: nothing
    assert level(q) == 0 and q.pulses("StepUp") == 0
    settle(q)
    turn(q, 8)                                           # exactly the settling angle: still nothing
    assert level(q) == 0
    settle(q)
    turn(q, 20)                                          # 12 degrees count: 12 / 720
    assert near(level(q), 12 / 720, 1e-6)
    settle(q)
    # a slow wobble that never leaves the settling angle moves nothing
    g = geometry(q)
    pts = [polar(g, g["R"] * 0.7, 90 - a) for a in (0, 3, -3, 5, -5, 2, 0)]
    q.drag(pts, seconds=0.7)
    assert near(level(q), 12 / 720, 1e-6)


def test_dial_dead_centre_does_nothing():
    q = boot()
    g = geometry(q)
    r = g["Rdead"] * 0.8
    pts = arc_points(g, r, 90, 180)                      # half a turn inside the dead centre
    q.drag(pts, seconds=1.0)
    assert level(q) == 0 and q.pulses("StepUp") == 0 and q.pulses("StepDown") == 0
    svg = q.icon()
    assert ">0%<" in svg
    settle(q)
    # a finger that slides from the centre onto the wheel turns from where it lands
    pts = [polar(g, g["Rdead"] * 0.5, 90), polar(g, g["R"] * 0.7, 90)] + arc_points(g, g["R"] * 0.7, 90, 38)[1:]
    q.drag(pts, seconds=0.6)
    assert near(level(q), 30 / 720, 1e-6)
    assert q.errors == []


def test_dial_level_is_bounded_but_the_wheel_is_endless():
    q = boot()
    q.set_pin("Detents", 0)
    q.set_pin("Turns", 0.5)                              # half a turn covers the range
    turn(q, 188)                                         # 180 counted: full range
    assert near(level(q), 1, 1e-6)
    settle(q)
    turn(q, 188, a0=-98)                                 # another half turn: stays at 1
    assert near(level(q), 1, 1e-6)
    w = q.run("return TouchPad.inst.wheel")              # two half turns: the wheel is back at 0
    assert w < 1e-6 or w > 360 - 1e-6
    settle(q)
    turn(q, -98, a0=74)                                  # 90 back: 1 - 90 / 180
    assert near(level(q), 0.5, 1e-6)
    settle(q)
    turn(q, -368, a0=172)                                # a full turn back: bounded at 0
    assert near(level(q), 0, 1e-6)
    assert q.errors == []


def test_dial_detents_pulse_one_step_each_way():
    q = boot()
    turn(q, 98)                                          # 90 counted at 15 degrees per detent: 6 clicks
    assert q.pulses("StepUp") == 6 and q.pulses("StepDown") == 0
    assert q.pin("Gesture")["String"] == "STEP UP"
    settle(q)
    turn(q, -98, a0=-8)
    assert q.pulses("StepUp") == 6 and q.pulses("StepDown") == 6
    assert q.pin("Gesture")["String"] == "STEP DOWN"
    # the steps keep coming at the end of the range: the wheel is endless
    settle(q)
    q.set_pin("Turns", 0.5)
    q.reset_pulses()
    g = geometry(q)
    q.touch(arc_points(g, g["R"] * 0.7, -106, -98), dt=0.03, lift=False)
    assert level(q) == 0 and q.pulses("StepDown") == 6
    # a step is drawn briefly (text and a minus icon inside the wheel), then the cue goes away
    svg = q.icon()
    assert "STEP -" in svg and q.run("return TouchPad.state.animating")
    q.lift()
    q.advance(1.0)
    assert "STEP -" not in q.icon() and not q.run("return TouchPad.state.animating")


def test_dial_detents_count_and_zero_detents():
    q = boot()
    q.set_pin("Detents", 0)
    turn(q, 188)                                         # no detents: no steps, 180 counted
    assert q.pulses("StepUp") == 0 and near(level(q), 0.25, 1e-6)
    assert notches(q.icon()) == (180.0, 12)              # faint marks still show the wheel turning
    settle(q)
    q.set_pin("Detents", 4)                              # 90 degrees per detent
    q.reset_pulses()
    turn(q, 188, a0=-98)                                 # 180 counted: clicks at 45 and 135
    assert q.pulses("StepUp") == 2
    settle(q)
    q.set_pin("Detents", 72)                             # 5 degrees per detent
    q.reset_pulses()
    turn(q, 98, a0=74)                                   # 90 counted: 18 clicks
    assert q.pulses("StepUp") == 18
    assert q.errors == []


def test_dial_turns_scale_the_range():
    q = boot()
    q.set_pin("Turns", 10)
    turn(q, 98)                                          # 90 / 3600
    assert near(level(q), 0.025, 1e-6)
    settle(q)
    q.set_pin("Turns", 1)
    turn(q, 98, a0=-8)                                   # 90 / 360 more
    assert near(level(q), 0.275, 1e-6)


def test_dial_level_written_elsewhere_is_followed_even_under_a_resting_finger():
    q = boot()
    g = geometry(q)
    q.set_pin("DialValue", 0.5)
    assert near(level(q), 0.5) and ">50%<" in q.icon()
    # a resting finger on the wheel
    q.touch([polar(g, g["R"] * 0.7, 90)], lift=False)
    q.advance(0.15)
    assert q.run("return TouchPad.inst.down") is True
    q.set_pin("DialValue", 0.75)
    assert near(level(q), 0.75) and near(q.run("return TouchPad.inst.v"), 0.75)
    q.advance(0.05)
    assert ">75%<" in q.icon()
    # the turn goes on from the new level (settling applies to the touch once)
    pts = arc_points(g, g["R"] * 0.7, 90, 98)
    q.touch(pts[1:], dt=0.05, lift=False)
    assert near(level(q), 0.875, 1e-6)
    q.lift()
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1
    assert q.errors == []


def test_dial_target_is_driven_position_wise_and_followed():
    q = boot()
    g = geometry(q)
    gain = q.add_component("Amp", "gain", controls={"gain": {"Value": -100, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Amp~gain")
    assert q.status().startswith("Dial target OK: Amp~gain")
    assert near(level(q), 0)                             # starts from the target's level
    turn(q, 98)                                          # 0.125
    assert near(gain.get("gain")["Position"], 0.125) and near(gain.get("gain")["Value"], -85)
    q.set_pin("DialValue", 0.25)                         # pins drive the target too
    assert near(gain.get("gain")["Position"], 0.25)
    gain.set("gain", 20)                                 # changed elsewhere: followed
    assert near(level(q), 1)
    settle(q)
    q.touch([polar(g, g["R"] * 0.7, 90)], lift=False)    # a resting finger does not own the wheel
    q.advance(0.15)
    gain.set("gain", -40)
    assert near(level(q), 0.5)
    q.lift()
    settle(q)
    q.set_pin("DialTarget", "")                          # unbound: changes no longer follow
    gain.set("gain", 20)
    assert near(level(q), 0.5)
    assert q.errors == []


def test_dial_bad_target_warns_and_keeps_working():
    q = boot()
    q.set_pin("DialTarget", "Nope~gain")
    assert "no component named Nope" in q.status()
    q.add_component("Amp", "gain", controls={"gain": {"Value": 0, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Amp~level")
    assert "has no control level" in q.status()
    q.set_pin("DialTarget", "Amp")
    assert "use CodeName~control" in q.status()
    turn(q, 98)
    assert near(level(q), 0.125, 1e-6)
    assert q.errors == []
    q.set_pin("DialTarget", "Amp~gain")
    assert q.status().startswith("Dial target OK")
    assert near(level(q), 100 / 120)                     # the target's level wins on binding


def test_dial_resume_continues_the_turn_without_a_second_settling():
    q = boot()
    g = geometry(q)
    pts = arc_points(g, g["R"] * 0.7, 90, 48)            # 40 counted
    q.touch(pts, dt=0.05, lift=False)
    assert near(level(q), 40 / 720, 1e-6)
    q.advance(0.5)                                       # inferred lift
    assert q.run("return TouchPad.inst.down") is False
    # Resumed 2 degrees from the last spot (an identical report never fires), then 30 more: no settling.
    more = arc_points(g, g["R"] * 0.7, 90 - 48 - 2, 30)
    q.touch(more, dt=0.05, lift=False)
    assert q.run("return TouchPad.inst.down") is True
    assert near(level(q), 70 / 720, 1e-6)
    q.lift()
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1


def test_dial_tap_and_lock():
    q = boot()
    g = geometry(q)
    q.tap(*polar(g, g["R"] * 0.7, 0))
    assert q.pulses("Tap") == 1 and level(q) == 0        # a tap turns nothing
    settle(q)
    q.touch([polar(g, g["R"] * 0.7, 90)], panel_touch=True, lift=False)
    assert q.run("return TouchPad.inst.down") is True
    q.set_pin("Lock", True)
    q.advance(0.05)
    assert "Locked" in q.icon() and q.run("return TouchPad.inst.down") is False
    q.lift()
    pts = arc_points(g, g["R"] * 0.7, 90, 98)
    q.touch(pts, dt=0.05, panel_touch=True)
    assert level(q) == 0                                 # swallowed while locked
    q.set_pin("Lock", False)
    q.touch(pts, dt=0.05, panel_touch=True)
    assert near(level(q), 0.125, 1e-6)
    assert "Locked" not in q.icon()


def test_dial_drives_the_demo_camera_zoom_and_shows_its_factor():
    q = boot(props={"Camera Control": DEMO})
    assert "Demo camera" in q.pin("CameraStatus")["String"]
    assert "DEMO CAM" in q.camera_view()
    assert "ZOOM x1.0" in q.icon()
    g = geometry(q)
    pts = arc_points(g, g["R"] * 0.7, 90, 98)
    q.touch(pts, dt=0.05, lift=False)                    # level 0.125 -> zoom position 0.125
    assert near(level(q), 0.125, 1e-6)
    assert near(q.run("return TouchPad.E.camera.target.zoom"), 0.125, 1e-6)
    assert near(q.run("return TouchPad.E.camera.target.pan"), 0) and near(q.run("return TouchPad.E.camera.target.tilt"), 0)
    q.lift()
    q.advance(1.5)                                       # the demo ramps at 0.25 / s
    assert q.run("return TouchPad.E.camera.target") is None
    assert near(q.run("return TouchPad.E.camera.zoomPos"), 0.125, 1e-6)
    assert near(q.run("return TouchPad.inst.camZoom"), 0.125, 1e-6)
    assert "ZOOM x2.4" in q.icon()                       # 1 + 0.125 x 11
    assert "x2.4" in q.camera_view()
    assert near(level(q), 0.125, 1e-6)                   # the level is not pulled by the ramp
    q.advance(4.0)
    assert not q.run("return TouchPad.state.animating")  # the readings stop by themselves
    q.set_pin("OpticalZoom", 20)
    q.advance(0.05)
    assert "ZOOM x3.4" in q.icon()                       # 1 + 0.125 x 19 = 3.375
    q.set_pin("DialValue", 1)                            # the pin drives the zoom too
    assert near(q.run("return TouchPad.E.camera.target.zoom"), 1)
    assert q.errors == []


def test_dial_follows_zoom_in_and_out_made_elsewhere():
    q = boot(props={"Camera Control": DEMO})
    q.set_pin("ZoomIn", True)                            # held: 0.5 / s x ZoomSpeed 50 % = 0.25 / s
    q.advance(1.0)
    assert q.run("return TouchPad.E.camera.zoomSpeed") > 0
    z = q.run("return TouchPad.E.camera.zoomPos")
    assert 0.2 < z <= 0.26 and near(level(q), z, 0.06)   # the level follows within a reading
    q.set_pin("ZoomIn", False)
    q.advance(0.5)
    z = q.run("return TouchPad.E.camera.zoomPos")
    assert q.run("return TouchPad.E.camera.zoomSpeed") == 0
    assert near(level(q), z, 1e-6)                       # one last reading after the stop
    assert "ZOOM x%.1f" % (1 + z * 11) in q.icon()
    q.set_pin("ZoomOut", True)
    q.advance(2.0)
    q.set_pin("ZoomOut", False)
    q.advance(0.5)
    assert near(level(q), 0, 1e-6) and ">0%<" in q.icon()
    settle(q)
    turn(q, 98)                                          # the dial still drives the zoom afterwards
    q.advance(1.0)
    assert near(q.run("return TouchPad.E.camera.zoomPos"), 0.125, 1e-6)
    assert q.errors == []


def test_dial_camera_without_a_known_position_gets_speed_bursts():
    q = boot(props={"Camera Control": DEMO})
    q.run("""
      local cam = TouchPad.E.camera
      cam.gotoPosition = nil
      cam.getPosition = function(self, cb) if cb then cb(nil) end end
      TouchPad.inst.camPan, TouchPad.inst.camTilt = nil, nil
    """)
    g = geometry(q)
    q.touch(arc_points(g, g["R"] * 0.7, 90, 98), dt=0.03, lift=False)
    assert q.run("return TouchPad.E.camera.zoomSpeed") > 0  # a burst in the turn's direction
    assert q.run("return TouchPad.E.camera.target") is None  # no position: no absolute move
    q.advance(0.5)                                       # the last send (0.1 s) plus the burst (0.25 s)
    assert q.run("return TouchPad.E.camera.zoomSpeed") == 0  # ...that ends by itself
    q.lift()
    settle(q)
    q.touch(arc_points(g, g["R"] * 0.7, -8, -98), dt=0.03, lift=False)
    assert q.run("return TouchPad.E.camera.zoomSpeed") < 0
    q.advance(0.5)
    assert q.run("return TouchPad.E.camera.zoomSpeed") == 0
    q.lift()
    assert q.errors == []


def test_dial_frames_and_handlers_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30",
                    "Camera Control": DEMO})
    q.set_pin("Detents", 72)
    g = geometry(q)
    pts = arc_points(g, g["R"] * 0.7, 90, 720, steps=120)
    q.drag(pts, seconds=3.0)
    q.set_pin("ZoomIn", True)
    q.advance(1.0)
    q.set_pin("ZoomIn", False)
    q.advance(1.0)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 20000 and len(q.camera_view()) < 20000
    small = boot(props={"Pad Width": 120, "Pad Height": 120})
    turn(small, 98)
    assert near(level(small), 0.125, 1e-6) and small.errors == []


def test_dial_zoom_button_pressed_again_keeps_following():
    # A second press within the post-release reading delay must not switch
    # the following off for the whole second hold.
    q = boot(props={"Camera Control": DEMO})
    q.set_pin("ZoomIn", True)
    q.advance(0.5)
    q.set_pin("ZoomIn", False)
    q.advance(0.1)                                       # inside CAM_READ (0.2 s)
    q.set_pin("ZoomIn", True)
    q.advance(1.5)
    assert q.run("return TouchPad.inst.following") is True
    z = q.run("return TouchPad.E.camera.zoomPos")
    assert z > 0.4 and near(level(q), z, 0.06)           # the level keeps following while held
    assert near(q.run("return TouchPad.inst.camZoom"), level(q), 1e-6)
    # both buttons: releasing one keeps following while the other is held
    q.set_pin("ZoomOut", True)
    q.set_pin("ZoomIn", False)
    assert q.run("return TouchPad.inst.following") is True
    q.set_pin("ZoomOut", False)
    assert q.run("return TouchPad.inst.following") is False
    q.advance(0.5)
    assert near(level(q), q.run("return TouchPad.E.camera.zoomPos"), 1e-6)
    assert q.errors == []


def test_dial_adopts_a_camera_that_answers_later():
    # A VISCA camera answers getPosition on the inquiry reply: the intent to
    # adopt the zoom travels with the callback.
    q = boot(props={"Camera Control": DEMO})
    q.run("""
      local cam = TouchPad.E.camera
      cam.getPosition = function(self, cb)
        Timer.CallAfter(function() cb(self.pan, self.tilt, self.zoomPos) end, 0.05)
      end
      cam.zoomPos = 0.6
    """)
    q.run("TouchPad.inst:onStart()")
    assert level(q) == 0                                 # nothing yet: the answer is pending
    q.advance(0.3)
    assert near(level(q), 0.6, 1e-6) and near(q.run("return TouchPad.inst.camZoom"), 0.6, 1e-6)
    q.set_pin("ZoomIn", True)
    q.advance(1.0)
    q.set_pin("ZoomIn", False)
    q.advance(0.5)
    z = q.run("return TouchPad.E.camera.zoomPos")
    assert z > 0.8 and near(level(q), z, 1e-6)           # the late last reading is adopted too
    # a finger turning the wheel is not overridden by the late reading
    settle(q)
    q.set_pin("ZoomOut", True)
    q.advance(0.3)
    q.set_pin("ZoomOut", False)
    g = geometry(q)
    q.touch(arc_points(g, g["R"] * 0.7, 90, 48), dt=0.03, lift=False)   # turning within 0.2 s
    v = level(q)
    q.advance(0.3)
    assert near(level(q), v, 1e-6)
    q.lift()
    assert q.errors == []


def test_dial_quantised_target_echo_is_not_followed():
    # An Integer knob snaps the position we write; its echo must not be taken
    # as an external change (the dial would run ahead of the finger).
    q = boot()
    amp = q.add_component("Amp", "gain", controls={"step": {"Value": 0, "Min": 0, "Max": 10}})
    q.run("__FAKE.state[Component.New('Amp').step].Unit = 'Integer'")
    q.set_pin("DialTarget", "Amp~step")
    assert q.status().startswith("Dial target OK: Amp~step")
    g = geometry(q)
    q.drag(arc_points(g, g["R"] * 0.7, 90, 60), seconds=0.4)   # 52 counted at Turns 2
    assert near(level(q), 52 / 720, 1e-6)
    assert near(amp.get("step")["Position"], 0.1)        # the target snapped to step 1
    settle(q)
    q.drag(arc_points(g, g["R"] * 0.7, 30, 98), seconds=0.6)   # 90 more
    assert near(level(q), 142 / 720, 1e-6)
    assert near(amp.get("step")["Position"], 0.2)
    amp.set("step", 7)                                   # a real change elsewhere is followed
    assert near(level(q), 0.7)
    assert q.errors == []


def test_dial_notch_style_follows_detents_crossing_zero():
    def notch_path(q):
        q.advance(0.05)
        m = re.search(r'<g transform="rotate\([^)]*\)">(.*?)</g>', q.icon())
        return m.group(1)
    line, muted = boot().run("return TouchPad.E.T.line, TouchPad.E.T.muted")
    q = boot()
    q.set_pin("Detents", 12)
    strong = notch_path(q)
    assert 'stroke="%s"' % muted in strong and 'stroke-width="2"' in strong and 'opacity="0.9"' in strong
    q.set_pin("Detents", 0)                              # same count (12 idle marks), faint style
    faint = notch_path(q)
    assert 'stroke="%s"' % line in faint and 'stroke-width="1"' in faint and 'opacity="0.7"' in faint
    assert faint != strong
    q.set_pin("Detents", 12)
    assert notch_path(q) == strong
    other = boot()
    other.set_pin("Detents", 0)
    assert notch_path(other) == faint
    other.set_pin("Detents", 12)
    assert notch_path(other) == strong


def test_dial_target_status_never_hides_or_outlives_other_status():
    q = boot()
    ok_text = q.status()
    assert ok_text.startswith("OK") and q.pin("Status")["Value"] == 0
    q.set_pin("DialTarget", "Nope~gain")
    assert "no component named Nope" in q.status() and q.pin("Status")["Value"] == 1
    q.set_pin("DialTarget", "")                          # nothing wrong any more
    q.advance(0.5)
    assert q.status() == ok_text and q.pin("Status")["Value"] == 0
    q.add_component("Amp", "gain", controls={"gain": {"Value": 0, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Amp~gain")
    assert q.status().startswith("Dial target OK")
    q.set_pin("DialTarget", "Amp~nope")                  # OK replaced by the warning...
    assert "has no control nope" in q.status()
    q.set_pin("DialTarget", "")                          # ...and the engine's text is back
    assert q.status() == ok_text
    # a worse status stands: no picker in the design
    bare = boot(picker=None)
    err = bare.status()
    assert "No Color Picker" in err and bare.pin("Status")["Value"] == 2
    bare.add_component("Amp", "gain", controls={"gain": {"Value": 0, "Min": -100, "Max": 20}})
    bare.set_pin("DialTarget", "Amp~gain")
    assert bare.status() == err and bare.pin("Status")["Value"] == 2
    assert bare.run("return TouchPad.inst.target ~= nil") is True   # bound all the same
    bare.set_pin("DialTarget", "Nope~gain")
    assert bare.status() == err
    bare.set_pin("DialTarget", "")
    assert bare.status() == err


def test_dial_restored_level_is_adopted_at_start():
    # A DialValue the Core restored before the script ran is adopted, not
    # overwritten with 0.
    q = QSys(mode="Dial", picker="Color_Picker", plugin=PLUGIN, runtime=False)
    q.set_pin("DialValue", 0.5)
    q._dispatch("load", q._chunk)
    q.advance(0.3)
    assert near(level(q), 0.5) and near(q.run("return TouchPad.inst.v"), 0.5)
    assert ">50%<" in q.icon()
    turn(q, 98)                                          # the turn goes on from there
    assert near(level(q), 0.625, 1e-6)
    # a restored level also seeds a target bound at start
    r = QSys(mode="Dial", picker="Color_Picker", plugin=PLUGIN, runtime=False)
    r.add_component("Amp", "gain", controls={"gain": {"Value": -40, "Min": -100, "Max": 20}})
    r.set_pin("DialValue", 0.25)
    r.set_pin("DialTarget", "Amp~gain")
    r._dispatch("load", r._chunk)
    r.advance(0.3)
    assert near(level(r), 0.5)                           # the target's level wins without a camera
    assert r.errors == []


def test_dial_fast_flick_pays_all_detent_clicks():
    q = boot()
    q.set_pin("Detents", 72)                             # 5 degrees per detent
    q.set_pin("Turns", 10)
    g = geometry(q)
    r = g["R"] * 0.7
    # one report covering 60 degrees after settling: 12 clicks, 8 at once
    q.touch([polar(g, r, 90), polar(g, r, 90 - 8.001), polar(g, r, 90 - 68)], dt=0.03, lift=False)
    assert q.pulses("StepUp") == 8
    assert q.run("return TouchPad.inst.stepDebt") == 4 and q.run("return TouchPad.state.animating")
    q.advance(0.1)                                       # the rest comes from the next frames
    assert q.pulses("StepUp") == 12 and q.run("return TouchPad.inst.stepDebt") == 0
    q.touch(arc_points(g, r, 90 - 68, 60)[1:], dt=0.05, lift=False)   # a slow 60 more
    assert q.pulses("StepUp") == 24
    q.lift()
    # a flick back the other way right after a capped report nets out: 100 up
    # (8 pulsed, 12 owed) then 50 down leaves 10 up in all, nothing pulsed twice
    settle(q)
    q.reset_pulses()
    q.touch([polar(g, r, 90), polar(g, r, 90 - 8.001), polar(g, r, 90 - 108), polar(g, r, 90 - 58)],
            dt=0.03, lift=False)
    q.advance(0.2)
    assert q.pulses("StepUp") == 10 and q.pulses("StepDown") == 0
    assert q.run("return TouchPad.inst.stepDebt") == 0
    q.lift()
    assert q.errors == []


def test_dial_small_pads_keep_the_drawing_inside_the_canvas():
    for props in ({"Pad Width": 120, "Pad Height": 120}, {"Pad Width": 200, "Pad Height": 200},
                  {"Pad Width": 300, "Pad Height": 300}, {"Pad Width": 120, "Pad Height": 120, "Show Hints": False},
                  {"Pad Width": 1600, "Pad Height": 300}):
        q = boot(props=props)
        W, H = props["Pad Width"], props["Pad Height"]
        hint = props.get("Show Hints", True)
        cx, cy, R, Rtrack, trackW, cueR, cueSize, readW = q.run(
            "local g = TouchPad.inst.geometry return g.cx, g.cy, g.R, g.Rtrack, g.trackW, g.cueR, g.cueSize, g.readW")
        outer = Rtrack + trackW / 2
        assert cy - outer >= 0 and cx - outer >= 0 and cx + outer <= W, props
        assert cy + outer <= H - (20 if hint else 0), props          # above the hint line
        assert cueR + cueSize / 2 < R * 0.8 and cueR - cueSize / 2 > R * 0.3, props   # inside the wheel
        q.set_pin("DialValue", 1)
        q.set_pin("Detents", 4)
        q.advance(0.05)
        texts = re.findall(r'>([^<]*)</text>', q.icon())
        assert texts[0] == "100%", props                 # the readout is never shortened
        assert not any("..." in t for t in texts if not t.startswith("Turn")), props
        g = geometry(q)
        q.touch(arc_points(g, g["R"] * 0.7, 90, -98), dt=0.03, lift=False)   # a step down
        svg = q.icon()                                   # the cue is drawn inside the canvas
        assert "STEP -" in svg, props
        m = re.search(r'<g transform="translate\(([-\d.]+) ([-\d.]+)\) scale\(([\d.]+)\)', svg)
        assert m, props
        x0, y0, k = float(m.group(1)), float(m.group(2)), float(m.group(3))
        assert 0 <= x0 and x0 + 24 * k <= W and 0 <= y0 and y0 + 24 * k <= H, props
        q.lift()
        assert q.errors == []


def test_dial_binding_a_target_never_moves_the_camera():
    q = boot(props={"Camera Control": DEMO})
    amp = q.add_component("Amp", "gain", controls={"gain": {"Value": -40, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Amp~gain")
    assert q.run("return TouchPad.E.camera.target") is None          # no unrequested zoom move
    assert level(q) == 0                                 # the camera's zoom seeds the level...
    assert near(amp.get("gain")["Position"], 0)          # ...and the target follows it
    turn(q, 98)                                          # the first turn does not jump the zoom
    q.advance(1.0)
    assert near(q.run("return TouchPad.E.camera.zoomPos"), 0.125, 1e-6)
    assert near(amp.get("gain")["Position"], 0.125)
    # at start-up with both saved in the design the camera seeds the level as well
    r = QSys(mode="Dial", picker="Color_Picker", plugin=PLUGIN, runtime=False,
             props={"Camera Control": DEMO})
    g2 = r.add_component("Amp", "gain", controls={"gain": {"Value": -40, "Min": -100, "Max": 20}})
    r.set_pin("DialTarget", "Amp~gain")
    r._dispatch("load", r._chunk)
    r.advance(0.3)
    assert r.run("return TouchPad.E.camera.target") is None
    assert level(r) == 0 and near(g2.get("gain")["Position"], 0)
    g2.set("gain", 20)                                   # the target changed elsewhere still drives the zoom
    assert near(level(r), 1) and near(r.run("return TouchPad.E.camera.target.zoom"), 1)
    assert r.errors == []
