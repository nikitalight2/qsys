# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Knob mode (16_mode_knob.lua)
"""A bounded rotary with a 270 degree sweep: a touch on the ring sets the
value from its angle, dragging turns relative with acceleration, the readout
shows display units from KnobMin / KnobMax / Units, KnobValue and
KnobPosition are pins both ways and DialTarget drives a control position-wise."""
import math
import os
import re

from harness import QSys, DEFAULT_PLUGIN

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
MODE_BUILD = os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-knob.qplug")
PLUGIN = os.environ.get("TOUCHPAD_PLUGIN") or (MODE_BUILD if os.path.exists(MODE_BUILD) else DEFAULT_PLUGIN)


def boot(**kw):
    kw.setdefault("mode", "Knob")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


def settle(q):
    """Lets the engine's 1.5 s resume window after a lift pass, so the next
    drag is a new touch even when it starts where the last one ended."""
    q.advance(1.6)


def geometry(q):
    """Centre and radii of the knob as the mode computed them."""
    cx, cy, R, Rm, Rin, Rdead = q.run("local g = TouchPad.inst.geometry return g.cx, g.cy, g.R, g.Rm, g.Rin, g.Rdead")
    return {"cx": cx, "cy": cy, "R": R, "Rm": Rm, "Rin": Rin, "Rdead": Rdead}


def polar(g, r, deg):
    """Pad pixels (y down) at radius r and canvas angle deg (0 = right, 90 = up)."""
    a = math.radians(deg)
    return (g["cx"] + r * math.cos(a), g["cy"] - r * math.sin(a))


def arc_points(g, r, deg0, deg1, n):
    """n + 1 points along the arc from deg0 to deg1 at radius r."""
    return [polar(g, r, deg0 + (deg1 - deg0) * i / n) for i in range(n + 1)]


def texts(svg):
    return re.findall(r"<text[^>]*>([^<]*)</text>", svg)


def pos(q):
    return q.pin("KnobPosition")["Value"]


def test_knob_controls_and_pins():
    q = boot()
    names = q.control_names()
    for n in ("KnobMin", "KnobMax", "Units", "KnobValue", "KnobPosition", "DialTarget"):
        assert n in names, n
    assert len(names) == 26 + 6
    pins = q.run("local l = GetControls(Properties) local out = {} "
                 "for _, c in ipairs(l) do out[c.Name] = tostring(c.PinStyle) .. '/' .. tostring(c.UserPin) .. '/' .. tostring(c.Min) .. '/' .. tostring(c.Max) end return out")
    assert pins["KnobMin"] == "Input/true/-1000/1000"
    assert pins["KnobMax"] == "Input/true/-1000/1000"
    assert pins["Units"] == "Input/true/nil/nil"
    assert pins["DialTarget"] == "Input/true/nil/nil"
    assert pins["KnobValue"] == "Both/true/-1000/1000"
    assert pins["KnobPosition"] == "Both/true/0/1"
    assert near(q.pin("KnobMin")["Value"], 0) and near(q.pin("KnobMax")["Value"], 100)
    assert near(pos(q), 0) and near(q.pin("KnobValue")["Value"], 0)
    assert q.status().startswith("OK")
    assert q.pin("Gesture")["String"] == "TOUCH THE RING TO SET, DRAG TO TURN"


def test_knob_layout_lint_and_pages():
    q = boot()
    problems = q.layout_lint(matrix=[{}, {"Pad Width": 1600, "Pad Height": 300}, {"Theme": "Light"},
                                     {"Show Hints": False}, {"Pad Width": 120, "Pad Height": 120}])
    assert problems == [], problems
    pages = q.run("local out = {} for _, p in ipairs(GetPages(Properties)) do out[#out + 1] = p.name end return table.concat(out, ',')")
    assert pages == "Pad,Setup,Outputs,Display,About"


def test_knob_idle_drawing_track_ticks_labels_and_hint():
    q = boot()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    g = geometry(q)
    assert g["R"] == 200 and g["Rm"] == 186 and g["Rin"] == 158
    # the track is a 270 degree arc (large-arc flag set) of the well colour
    assert 'A186 186 0 1 1' in svg and "#0E0D12" in svg
    assert svg.count("<line") >= 31 + 1                   # 31 ticks and the pointer
    t = texts(svg)
    assert "0" in t and "100" in t                        # Min / Max labels and the readout
    assert "Touch the ring to set, drag to turn" in svg
    assert len(svg) < 8000
    # no fill arc at position 0
    assert svg.count("#C513E8") == 1 and "#FF8A1E" in svg  # the pointer line only; the rim dot is accent2


def test_knob_touch_on_the_ring_sets_from_the_angle():
    q = boot()
    g = geometry(q)
    x, y = polar(g, g["Rm"], 90)                          # top of the track: half way
    q.tap(x, y)
    assert near(pos(q), 0.5) and near(q.pin("KnobValue")["Value"], 50)
    assert q.pulses("Tap") == 1                            # the common outputs still flow
    q.tap(*polar(g, g["Rm"], 225 - 270 * 0.25))            # a quarter
    assert near(pos(q), 0.25) and near(q.pin("KnobValue")["Value"], 25)
    q.tap(*polar(g, g["R"] + 20, 225 - 270 * 0.8))         # beyond the track still counts as the ring
    assert near(pos(q), 0.8)
    svg = q.icon()
    assert "80" in texts(svg)
    assert 'A186 186 0 1 1' in svg and svg.count("A186 186 0") >= 3   # track, outline and the fill arc


def test_knob_dead_gap_snaps_to_the_nearest_end():
    q = boot()
    g = geometry(q)
    q.tap(*polar(g, g["Rm"], 90))
    assert near(pos(q), 0.5)
    q.tap(*polar(g, g["Rm"], -95))                         # bottom, slightly left of the gap centre
    assert near(pos(q), 0)
    q.tap(*polar(g, g["Rm"], -85))                         # bottom, slightly right
    assert near(pos(q), 1)


def test_knob_body_touch_does_not_set_but_a_drag_turns_relative():
    q = boot()
    g = geometry(q)
    q.set_pin("KnobPosition", 0.5)
    q.tap(*polar(g, g["Rin"] * 0.6, 0))                    # on the body: no jump
    assert near(pos(q), 0.5)
    q.tap(g["cx"], g["cy"])                                # the dead centre: nothing
    assert near(pos(q), 0.5)
    # a slow clockwise turn of 54 degrees on the body moves 54/270 = 0.2
    q.drag(arc_points(g, g["Rin"] * 0.6, 90, 36, 9), seconds=1.0)
    assert near(pos(q), 0.7, 1e-6)
    assert near(q.pin("KnobValue")["Value"], 70, 1e-6)
    # counter-clockwise turns it back (after the engine's 1.5 s resume window)
    settle(q)
    q.drag(arc_points(g, g["Rin"] * 0.6, 36, 90, 9), seconds=1.0)
    assert near(pos(q), 0.5, 1e-6)


def test_knob_fast_drag_accelerates_and_clamps_at_the_ends():
    q = boot()
    g = geometry(q)
    pts = arc_points(g, g["Rin"] * 0.6, 90, 36, 9)          # 54 degrees
    q.drag(pts, seconds=1.0)                               # 54 deg/s: gain 1
    slow = pos(q)
    assert near(slow, 0.2)
    settle(q)
    q.set_pin("KnobPosition", 0)
    q.drag(pts, seconds=0.15)                              # 360 deg/s: gain 1 + 2 * (360 - 180) / 540
    fast = pos(q)
    expected = 0.2 * (1 + 2 * (360 - 180) / 540)
    assert near(fast, expected, 1e-3), (fast, expected)
    assert fast > slow
    settle(q)
    q.set_pin("KnobPosition", 0)
    q.drag(pts, seconds=0.05)                              # 1080 deg/s: gain capped at 3
    assert near(pos(q), 0.6, 1e-3)
    # clamped: turning further clockwise from the top end stays at 1, no wrap
    settle(q)
    q.set_pin("KnobPosition", 1)
    q.drag(arc_points(g, g["Rin"] * 0.6, -45, -135, 9), seconds=0.5)
    assert near(pos(q), 1)
    settle(q)
    q.drag(arc_points(g, g["Rin"] * 0.6, -135, -90, 5), seconds=0.5)
    assert near(pos(q), 1 - 45 / 270, 1e-6)


def test_knob_ring_set_then_drag_continues_from_the_set_value():
    q = boot()
    g = geometry(q)
    # touch down on the ring at the top (sets 0.5), then turn 27 degrees clockwise along the ring
    pts = arc_points(g, g["Rm"], 90, 63, 6)
    q.drag(pts, seconds=1.0)
    assert near(pos(q), 0.6, 1e-6)
    svg = q.icon()
    assert "60" in texts(svg)


def test_knob_resume_after_inferred_lift_reanchors_without_a_jump():
    q = boot()
    g = geometry(q)
    q.touch(arc_points(g, g["Rin"] * 0.6, 90, 63, 3), lift=False)
    assert near(pos(q), 0.1, 1e-6)
    q.advance(0.5)                                         # inferred lift
    assert q.run("return TouchPad.inst.down") is False
    q.touch([polar(g, g["Rin"] * 0.6, 50)], dt=0.2, lift=False)   # resumed 13 degrees further: no jump
    assert q.run("return TouchPad.inst.down") is True
    assert near(pos(q), 0.1, 1e-6)
    q.touch([polar(g, g["Rin"] * 0.6, 23)], dt=0.2, lift=False)   # then 27 degrees more at 135 deg/s
    assert near(pos(q), 0.2, 1e-6)
    q.lift()


def test_knob_drag_through_the_dead_centre_changes_nothing():
    q = boot()
    g = geometry(q)
    q.set_pin("KnobPosition", 0.5)
    q.drag([polar(g, 60, 90), (g["cx"], g["cy"]), polar(g, 60, -90)], seconds=0.4)
    assert near(pos(q), 0.5)


def test_knob_external_value_and_position_pins():
    q = boot()
    q.set_pin("KnobValue", 25)
    assert near(pos(q), 0.25)
    q.set_pin("KnobPosition", 0.75)
    assert near(q.pin("KnobValue")["Value"], 75)
    q.set_pin("KnobValue", 500)                            # above Max clamps
    assert near(pos(q), 1) and near(q.pin("KnobValue")["Value"], 100)
    q.set_pin("KnobValue", -5)
    assert near(pos(q), 0) and near(q.pin("KnobValue")["Value"], 0)
    q.set_pin("KnobPosition", 0.3)
    q.advance(0.1)
    assert "30" in texts(q.icon())


def test_knob_range_units_and_readout_decimals():
    q = boot()
    g = geometry(q)
    q.set_pin("KnobPosition", 0.5)
    q.set_pin("KnobMin", -100)
    q.set_pin("KnobMax", 20)
    q.set_pin("Units", "dB")
    q.advance(0.1)
    assert near(q.pin("KnobValue")["Value"], -40)
    t = texts(q.icon())
    assert "-100" in t and "20" in t and "-40" in t and "dB" in t
    assert q.run("return TouchPad.inst.readout(-40)") == "-40 dB"
    # narrow ranges get decimals
    q.set_pin("KnobMin", 0)
    q.set_pin("KnobMax", 10)
    q.advance(0.1)
    assert "5.0" in texts(q.icon()) and "10.0" in texts(q.icon())
    q.set_pin("KnobMax", 5)
    q.advance(0.1)
    assert "2.50" in texts(q.icon()) and "5.00" in texts(q.icon())
    q.set_pin("KnobMax", 100)
    q.advance(0.1)
    assert "50" in texts(q.icon())
    q.set_pin("KnobMax", 1000)
    q.advance(0.1)
    assert "500" in texts(q.icon())
    # a touch after the range change outputs the new units
    q.tap(*polar(g, g["Rm"], 90 + 67.5))
    assert near(q.pin("KnobValue")["Value"], 250, 1e-6)
    # Min == Max never divides by zero
    q.set_pin("KnobMax", 0)
    q.tap(*polar(g, g["Rm"], 90))
    assert near(pos(q), 0.5) and q.errors == []


def test_knob_dial_target_is_driven_and_followed():
    q = boot()
    g = geometry(q)
    gain = q.add_component("Gain", "gain", controls={"gain": {"Value": -100, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Gain~gain")
    assert q.status().startswith("Knob target OK: Gain~gain")
    assert near(pos(q), 0)                                 # starts from the target's level
    q.tap(*polar(g, g["Rm"], 90))
    assert near(gain.get("gain")["Position"], 0.5) and near(gain.get("gain")["Value"], -40)
    q.set_pin("KnobPosition", 0.25)                        # pins drive the target too
    assert near(gain.get("gain")["Position"], 0.25)
    gain.set("gain", 20)                                   # changed elsewhere: followed
    assert near(pos(q), 1) and near(q.pin("KnobValue")["Value"], 100)
    q.touch([polar(g, g["Rin"] * 0.6, 90)], lift=False)    # a resting finger owns the knob
    gain.set("gain", -100)
    assert near(pos(q), 1)
    q.lift()
    q.set_pin("DialTarget", "")                            # unbound: changes no longer follow
    gain.set("gain", -40)
    assert near(pos(q), 1)
    assert q.errors == []


def test_knob_bad_dial_target_warns_and_keeps_working():
    q = boot()
    g = geometry(q)
    q.set_pin("DialTarget", "Nope~gain")
    assert "no component named Nope" in q.status()
    q.add_component("Amp", "gain", controls={"gain": {"Value": 0, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Amp~level")
    assert "has no control level" in q.status()
    q.set_pin("DialTarget", "Amp")
    assert "use CodeName~control" in q.status()
    q.tap(*polar(g, g["Rm"], 90))
    assert near(pos(q), 0.5)
    assert q.errors == []
    q.set_pin("DialTarget", "Amp~gain")
    assert q.status().startswith("Knob target OK")


def test_knob_lock_releases_the_finger_and_ignores_touches():
    q = boot()
    g = geometry(q)
    q.touch([polar(g, g["Rin"] * 0.6, 90)], panel_touch=True, lift=False)
    assert q.run("return TouchPad.inst.down") is True
    q.set_pin("Lock", True)
    q.advance(0.05)
    svg = q.icon()
    assert "Locked" in svg
    assert q.run("return TouchPad.inst.down") is False
    q.lift()
    q.tap(*polar(g, g["Rm"], 90), panel_touch=True)
    assert near(pos(q), 0)                                 # swallowed while locked
    q.set_pin("Lock", False)
    q.tap(*polar(g, g["Rm"], 90), panel_touch=True)
    assert near(pos(q), 0.5)
    assert "Locked" not in q.icon()


def test_knob_hints_off_and_touch_feedback():
    q = boot(props={"Show Hints": False})
    assert "Touch the ring" not in q.icon()
    g = geometry(q)
    assert g["cy"] == 250                                  # no room reserved for the hint line
    q.touch([polar(g, g["Rm"], 90)], lift=False)
    svg = q.icon()
    assert 'opacity="0.25"' in svg                         # the glowing finger dot while down
    q.lift()
    assert 'opacity="0.25"' not in q.icon()
    q = boot()
    assert "Touch the ring" in q.icon()
    q.touch([polar(geometry(q), 100, 90)], lift=False)
    assert "Touch the ring" not in q.icon()                # hidden while a finger is down
    q.lift()


def test_knob_themes_and_sizes_stay_ascii_and_small():
    light = boot(props={"Theme": "Light"})
    svg = light.icon()
    assert "#2F6FEB" in svg and "#17151C" not in svg
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300})
    svg = wide.icon()
    assert 'viewBox="0 0 1600 300"' in svg and all(ord(ch) < 127 for ch in svg)
    g = geometry(wide)
    assert g["R"] == 120
    tiny = boot(props={"Pad Width": 120, "Pad Height": 120})
    assert len(tiny.icon()) < 8000
    tiny.tap(60, 60 - 36)
    assert near(pos(tiny), 0.5)


def test_knob_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    g = geometry(q)
    q.drag(arc_points(g, g["Rm"], 225, -45, 100), seconds=2.0)
    assert near(pos(q), 1)
    q.drag(arc_points(g, g["Rin"] * 0.5, -45, 225, 100), seconds=4.0)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 20000 and b["max_handler"] < 20000, b
    assert len(q.icon()) < 8000
