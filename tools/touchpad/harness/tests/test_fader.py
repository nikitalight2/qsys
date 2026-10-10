# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Fader mode (17_mode_fader.lua)
"""A linear touch fader, vertical or horizontal: GrabMode Jump sets the
value under the finger, Relative moves it by the finger's travel; the Taper
is Linear or Audio (0 dB at 75 % of the travel for -100..10); SnapCenter
snaps within 3 % of the centre value; FaderValue / FaderPosition are pins
both ways; DialTarget drives a control position-wise; the pad draws the
slot, the fill, the cap, scale ticks and the value readout."""
import os
import re

from harness import QSys, DEFAULT_PLUGIN

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
MODE_BUILD = os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-fader.qplug")
PLUGIN = os.environ.get("TOUCHPAD_PLUGIN") or (MODE_BUILD if os.path.exists(MODE_BUILD) else DEFAULT_PLUGIN)


def boot(**kw):
    kw.setdefault("mode", "Fader")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


def geometry(q):
    """The fader travel as the mode computed it (pad px, y down)."""
    keys = ("vertical", "cx", "cy", "x0", "x1", "y0", "y1", "len", "capW", "capH", "slot")
    vals = q.run("local g = TouchPad.inst.geometry return " + ", ".join("g.%s" % k for k in keys))
    return dict(zip(keys, vals))


def at(g, p):
    """Pad point on the travel at position p (0..1)."""
    if g["vertical"]:
        return (g["cx"], g["y0"] - p * g["len"])
    return (g["x0"] + p * g["len"], g["cy"])


def along(g, p0, p1, n):
    """n + 1 points along the travel from position p0 to p1."""
    return [at(g, p0 + (p1 - p0) * i / n) for i in range(n + 1)]


def texts(svg):
    return re.findall(r"<text[^>]*>([^<]*)</text>", svg)


def rects(svg):
    """[(x, y, w, h)] of every <rect> in the SVG."""
    return [tuple(float(v) for v in m.groups())
            for m in re.finditer(r'<rect x="([-\d.]+)" y="([-\d.]+)" width="([-\d.]+)" height="([-\d.]+)"', svg)]


def pos(q):
    return q.pin("FaderPosition")["Value"]


def val(q):
    return q.pin("FaderValue")["Value"]


def test_fader_controls_pins_defaults_and_choices():
    q = boot()
    names = q.control_names()
    for n in ("FaderMin", "FaderMax", "Units", "FaderValue", "FaderPosition", "GrabMode", "Taper",
              "SnapCenter", "DialTarget"):
        assert n in names, n
    assert len(names) == 26 + 9
    pins = q.run("local l = GetControls(Properties) local out = {} "
                 "for _, c in ipairs(l) do out[c.Name] = tostring(c.PinStyle) .. '/' .. tostring(c.UserPin) .. '/' .. tostring(c.Min) .. '/' .. tostring(c.Max) end return out")
    assert pins["FaderMin"] == "Input/true/-1000/1000"
    assert pins["FaderMax"] == "Input/true/-1000/1000"
    assert pins["Units"] == "Input/true/nil/nil"
    assert pins["GrabMode"] == "Input/true/nil/nil"
    assert pins["Taper"] == "Input/true/nil/nil"
    assert pins["SnapCenter"] == "Input/true/nil/nil"
    assert pins["DialTarget"] == "Input/true/nil/nil"
    assert pins["FaderValue"] == "Both/true/-1000/1000"
    assert pins["FaderPosition"] == "Both/true/0/1"
    # defaults: -100..10 dB, Jump, Linear, position 0 at the bottom of the range
    assert near(q.pin("FaderMin")["Value"], -100) and near(q.pin("FaderMax")["Value"], 10)
    assert q.pin("Units")["String"] == "dB"
    assert q.pin("GrabMode")["String"] == "Jump" and q.pin("Taper")["String"] == "Linear"
    assert q.pin("SnapCenter")["Boolean"] is False
    assert near(pos(q), 0) and near(val(q), -100)
    # the runtime fills the Choices of the option texts
    assert list(q.pin("GrabMode")["Choices"]) == ["Jump", "Relative"]
    assert list(q.pin("Taper")["Choices"]) == ["Linear", "Audio"]
    assert q.status().startswith("OK")
    assert q.pin("Gesture")["String"] == "TOUCH OR DRAG THE FADER"


def test_fader_layout_lint_and_pages():
    q = boot()
    problems = q.layout_lint(matrix=[{}, {"Orientation": "Horizontal"}, {"Pad Width": 1600, "Pad Height": 300},
                                     {"Orientation": "Horizontal", "Pad Width": 1600, "Pad Height": 300},
                                     {"Theme": "Light"}, {"Show Hints": False},
                                     {"Pad Width": 120, "Pad Height": 120},
                                     {"Orientation": "Horizontal", "Pad Width": 120, "Pad Height": 120}])
    assert problems == [], problems
    pages = q.run("local out = {} for _, p in ipairs(GetPages(Properties)) do out[#out + 1] = p.name end return table.concat(out, ',')")
    assert pages == "Pad,Setup,Outputs,Display,About"
    # the Pad page carries a Fader-styled FaderValue and the Snap toggle beside the display
    styles = q.run("local l = GetControlLayout(Properties) local out = {} "
                   "for k, e in pairs(l) do out[k] = tostring(e.Style) end return out")
    assert styles["FaderValue"] == "Fader" and styles["SnapCenter"] == "Button"
    assert styles["Display"] == "Button"


def test_fader_idle_drawing_slot_ticks_labels_readout_and_hint():
    q = boot()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    g = geometry(q)
    assert g["vertical"] is True
    assert g["y0"] == 442 and g["y1"] == 90 and g["len"] == 352 and g["cx"] == 250
    assert g["capW"] == 120 and g["capH"] == 56 and g["slot"] == 26
    # the slot: a well-coloured rounded rect spanning the travel
    assert (237.0, 77.0, 26.0, 378.0) in rects(svg) and "#0E0D12" in svg
    # 31 ticks on each side plus the cap's centre line
    assert svg.count("<line") == 62 + 1
    t = texts(svg)
    assert "-100" in t and "10" in t and "-45" in t          # scale labels
    assert "-100.0 dB" in t                                  # the readout
    assert "Touch or drag the fader" in svg
    # the cap sits at the bottom of the travel, no fill at position 0
    assert (190.0, 414.0, 120.0, 56.0) in rects(svg)
    assert 'opacity="0.9"' not in svg
    assert len(svg) < 10000


def test_fader_jump_sets_the_value_under_the_finger():
    q = boot()
    g = geometry(q)
    q.tap(*at(g, 0.5))
    assert near(pos(q), 0.5) and near(val(q), -45)
    assert q.pulses("Tap") == 1                                # the common outputs still flow
    q.tap(*at(g, 1.0))
    assert near(pos(q), 1) and near(val(q), 10)
    q.tap(g["cx"], g["y0"] + 30)                               # below the travel clamps to 0
    assert near(pos(q), 0) and near(val(q), -100)
    q.tap(g["cx"] - 200, g["y0"] - 0.25 * g["len"])            # anywhere across the pad counts
    assert near(pos(q), 0.25, 1e-6)
    svg = q.icon()
    assert "-72.5 dB" in texts(svg)
    # the fill reaches from the bottom of the slot up to the cap
    yc = g["y0"] - 0.25 * g["len"]
    assert (239.0, yc, 22.0, g["y0"] - yc + 11) in rects(svg)
    assert 'opacity="0.9"' in svg


def test_fader_jump_drag_follows_the_finger():
    q = boot()
    g = geometry(q)
    q.touch(along(g, 0.2, 0.6, 8), lift=False)
    assert near(pos(q), 0.6, 1e-6)
    assert q.pin("Touching")["Boolean"] is True
    svg = q.icon()
    assert 'opacity="0.25"' in svg                             # the glowing cap while down
    assert "Touch or drag the fader" not in svg                # the hint hides under a finger
    q.touch(along(g, 0.6, 0.3, 6), lift=False)
    assert near(pos(q), 0.3, 1e-6) and near(val(q), -67, 1e-6)
    q.lift()
    assert q.pin("Touching")["Boolean"] is False
    assert near(pos(q), 0.3, 1e-6)
    svg = q.icon()
    assert 'opacity="0.25"' not in svg and "Touch or drag the fader" in svg


def test_fader_relative_moves_from_where_it_was():
    q = boot()
    g = geometry(q)
    q.set_pin("GrabMode", "Relative")
    q.set_pin("FaderPosition", 0.5)
    q.tap(*at(g, 0.9))                                         # a touch does not jump
    assert near(pos(q), 0.5)
    q.drag(along(g, 0.1, 0.3, 10), seconds=0.5)                # +0.2 of travel
    assert near(pos(q), 0.7, 1e-6) and near(val(q), -23, 1e-6)
    q.drag(along(g, 0.8, 0.6, 10), seconds=0.5)                # -0.2 of travel
    assert near(pos(q), 0.5, 1e-6)
    # saturates at the end and comes straight back without slack
    q.set_pin("FaderPosition", 0.9)
    q.drag(along(g, 0.2, 0.7, 10) + along(g, 0.7, 0.6, 5), seconds=0.5)
    assert near(pos(q), 0.9, 1e-6)
    q.set_pin("FaderPosition", 0.1)
    q.drag(along(g, 0.7, 0.2, 10) + along(g, 0.2, 0.3, 5), seconds=0.5)
    assert near(pos(q), 0.1, 1e-6)
    # back to Jump: a touch sets again
    q.set_pin("GrabMode", "Jump")
    q.tap(*at(g, 0.25))
    assert near(pos(q), 0.25, 1e-6)


def test_fader_audio_taper_puts_zero_db_at_three_quarters():
    q = boot()
    g = geometry(q)
    q.set_pin("Taper", "Audio")
    q.set_pin("FaderPosition", 0.75)
    assert near(val(q), 0)
    q.tap(*at(g, 0.5))
    assert near(val(q), -20, 1e-6)
    q.tap(*at(g, 0.25))
    assert near(val(q), -40, 1e-6)
    q.tap(*at(g, 0.1))
    assert near(val(q), -60, 1e-6)
    q.tap(*at(g, 1.0))
    assert near(val(q), 10, 1e-6)
    # the curve inverts exactly for value pins
    q.set_pin("FaderValue", -60)
    assert near(pos(q), 0.1, 1e-6)
    q.set_pin("FaderValue", -80)
    assert near(pos(q), 0.05, 1e-6)
    q.set_pin("FaderValue", 5)
    assert near(pos(q), 0.875, 1e-6)
    # monotonic along the whole travel
    vals = [q.run("return TouchPad.inst.valueOf(%s)" % (i / 20)) for i in range(21)]
    assert all(b > a for a, b in zip(vals, vals[1:]))
    # the scale labels follow the curve; a taper change keeps the position and re-outputs the value
    q.advance(0.1)
    assert "0" in texts(q.icon())
    q.set_pin("FaderPosition", 0.5)
    q.set_pin("Taper", "Linear")
    assert near(pos(q), 0.5) and near(val(q), -45)


def test_fader_snap_center_within_three_percent():
    q = boot()
    g = geometry(q)
    q.tap(*at(g, 0.52))
    assert near(pos(q), 0.52, 1e-6)                            # off: exact
    q.set_pin("SnapCenter", True)
    q.tap(*at(g, 0.52))
    assert near(pos(q), 0.5) and near(val(q), -45)             # on: snapped to the centre value
    q.tap(*at(g, 0.48))
    assert near(pos(q), 0.5)
    q.tap(*at(g, 0.54))
    assert near(pos(q), 0.54, 1e-6)                            # beyond 3 %: free
    # dragging through the centre sticks there and leaves again
    q.touch(along(g, 0.40, 0.49, 9), lift=False)
    assert near(pos(q), 0.5)
    q.touch(along(g, 0.49, 0.60, 11), lift=False)
    assert near(pos(q), 0.6, 1e-6)
    q.lift()
    # pins are exact even with the snap on
    q.set_pin("FaderPosition", 0.51)
    assert near(pos(q), 0.51)
    # the centre follows the taper: with Audio the centre value -45 sits lower on the travel
    q.set_pin("Taper", "Audio")
    centre = q.run("return TouchPad.inst.posOfValue(-45)")
    assert 0.2 < centre < 0.25
    q.tap(*at(g, centre + 0.02))
    assert near(pos(q), centre, 1e-6) and near(val(q), -45, 1e-6)
    q.set_pin("SnapCenter", False)
    q.tap(*at(g, 0.52))
    assert near(pos(q), 0.52, 1e-6)


def test_fader_horizontal_orientation():
    q = boot(props={"Orientation": "Horizontal", "Pad Width": 600, "Pad Height": 200})
    g = geometry(q)
    assert g["vertical"] is False
    assert g["x0"] == 30 and g["x1"] == 570 and g["len"] == 540
    svg = q.icon()
    assert 'viewBox="0 0 600 200"' in svg and all(ord(ch) < 127 for ch in svg)
    # the slot runs across the pad, the cap sits at the left
    assert (g["x0"] - g["slot"] / 2, g["cy"] - g["slot"] / 2, g["len"] + g["slot"], g["slot"]) in rects(svg)
    assert (g["x0"] - g["capW"] / 2, g["cy"] - g["capH"] / 2, g["capW"], g["capH"]) in rects(svg)
    assert svg.count("<line") == 62 + 1
    assert "-100" in texts(svg) and "10" in texts(svg) and "-100.0 dB" in texts(svg)
    q.tap(*at(g, 0.25))
    assert near(pos(q), 0.25, 1e-6) and near(val(q), -72.5, 1e-6)
    q.tap(g["x1"] + 20, g["cy"])                               # right of the travel clamps to 1
    assert near(pos(q), 1)
    q.tap(g["x0"] - 20, g["cy"] - 60)                          # left of it, anywhere across: 0
    assert near(pos(q), 0)
    q.drag(along(g, 0.1, 0.7, 12), seconds=0.6)
    assert near(pos(q), 0.7, 1e-6)
    q.set_pin("GrabMode", "Relative")
    q.drag(along(g, 0.5, 0.3, 10), seconds=0.5)
    assert near(pos(q), 0.5, 1e-6)
    assert len(q.icon()) < 10000 and q.errors == []


def test_fader_external_value_and_position_pins():
    q = boot()
    q.set_pin("FaderValue", -45)
    assert near(pos(q), 0.5)
    q.set_pin("FaderPosition", 0.75)
    assert near(val(q), -17.5)
    q.set_pin("FaderValue", 500)                               # above Max clamps
    assert near(pos(q), 1) and near(val(q), 10)
    q.set_pin("FaderValue", -300)
    assert near(pos(q), 0) and near(val(q), -100)
    q.set_pin("FaderPosition", 0.3)
    q.advance(0.1)
    assert "-67.0 dB" in texts(q.icon())


def test_fader_range_units_and_readout_decimals():
    q = boot()
    g = geometry(q)
    q.set_pin("FaderPosition", 0.5)
    q.set_pin("FaderMin", 0)
    q.set_pin("FaderMax", 100)
    q.set_pin("Units", "%")
    q.advance(0.1)
    assert near(val(q), 50)
    t = texts(q.icon())
    assert "0" in t and "100" in t and "50.0 %" in t
    assert q.run("return TouchPad.inst.readout(50)") == "50.0 %"
    # narrow ranges get decimals, wide ranges none
    q.set_pin("FaderMax", 10)
    q.advance(0.1)
    assert "5.00 %" in texts(q.icon())
    q.set_pin("FaderMax", 1000)
    q.advance(0.1)
    assert "500 %" in texts(q.icon())
    # blank units: the bare number
    q.set_pin("Units", "")
    q.advance(0.1)
    assert "500" in texts(q.icon())
    # a touch after the range change outputs the new units
    q.tap(*at(g, 0.25))
    assert near(val(q), 250, 1e-6)
    # Min == Max never divides by zero
    q.set_pin("FaderMax", 0)
    q.tap(*at(g, 0.5))
    assert near(pos(q), 0.5) and q.errors == []


def test_fader_dial_target_is_driven_and_followed():
    q = boot()
    g = geometry(q)
    gain = q.add_component("Gain", "gain", controls={"gain": {"Value": -100, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Gain~gain")
    assert q.status().startswith("Fader target OK: Gain~gain")
    assert near(pos(q), 0)                                     # starts from the target's level
    q.tap(*at(g, 0.5))
    assert near(gain.get("gain")["Position"], 0.5) and near(gain.get("gain")["Value"], -40)
    q.set_pin("FaderPosition", 0.25)                           # pins drive the target too
    assert near(gain.get("gain")["Position"], 0.25)
    gain.set("gain", 20)                                       # changed elsewhere: followed
    assert near(pos(q), 1) and near(val(q), 10)
    q.touch([at(g, 0.5)], lift=False)                          # a resting finger owns the fader
    gain.set("gain", -100)
    assert near(pos(q), 0.5)
    q.lift()
    q.set_pin("DialTarget", "")                                # unbound: changes no longer follow
    gain.set("gain", -40)
    assert near(pos(q), 0.5)
    assert q.errors == []


def test_fader_bad_dial_target_warns_and_keeps_working():
    q = boot()
    g = geometry(q)
    q.set_pin("DialTarget", "Nope~gain")
    assert "no component named Nope" in q.status()
    q.add_component("Amp", "gain", controls={"gain": {"Value": 0, "Min": -100, "Max": 20}})
    q.set_pin("DialTarget", "Amp~level")
    assert "has no control level" in q.status()
    q.set_pin("DialTarget", "Amp")
    assert "use CodeName~control" in q.status()
    q.tap(*at(g, 0.5))
    assert near(pos(q), 0.5)
    assert q.errors == []
    q.set_pin("DialTarget", "Amp~gain")
    assert q.status().startswith("Fader target OK")


def test_fader_resume_after_inferred_lift_reanchors_without_a_jump():
    q = boot()
    g = geometry(q)
    q.set_pin("GrabMode", "Relative")
    q.touch(along(g, 0.1, 0.2, 4), lift=False)
    assert near(pos(q), 0.1, 1e-6)
    q.advance(0.5)                                             # inferred lift
    assert q.run("return TouchPad.inst.down") is False
    q.touch([at(g, 0.23)], lift=False)                         # resumed a little further: no jump
    assert q.run("return TouchPad.inst.down") is True
    assert near(pos(q), 0.1, 1e-6)
    q.touch([at(g, 0.33)], lift=False)                         # then moves again
    assert near(pos(q), 0.2, 1e-6)
    q.lift()
    # in Jump mode a resumed finger simply keeps the fader under it
    q.set_pin("GrabMode", "Jump")
    q.touch(along(g, 0.5, 0.6, 2), lift=False)
    q.advance(0.5)
    q.touch([at(g, 0.62)], lift=False)
    assert near(pos(q), 0.6, 1e-6)
    q.touch([at(g, 0.7)], lift=False)
    assert near(pos(q), 0.7, 1e-6)
    q.lift()


def test_fader_lock_releases_the_finger_and_ignores_touches():
    q = boot()
    g = geometry(q)
    q.touch([at(g, 0.5)], panel_touch=True, lift=False)
    assert q.run("return TouchPad.inst.down") is True
    q.set_pin("Lock", True)
    q.advance(0.05)
    svg = q.icon()
    assert "Locked" in svg
    assert q.run("return TouchPad.inst.down") is False
    q.lift()
    q.tap(*at(g, 0.9), panel_touch=True)
    assert near(pos(q), 0.5)                                   # swallowed while locked
    q.set_pin("Lock", False)
    q.tap(*at(g, 0.9), panel_touch=True)
    assert near(pos(q), 0.9, 1e-6)
    assert "Locked" not in q.icon()


def test_fader_hints_off_themes_and_sizes_stay_ascii_and_small():
    q = boot(props={"Show Hints": False})
    assert "Touch or drag" not in q.icon()
    g = geometry(q)
    assert g["y0"] == 454                                      # no room reserved for the hint line
    assert q.pin("Gesture")["String"] == "TOUCH OR DRAG THE FADER"
    light = boot(props={"Theme": "Light"})
    svg = light.icon()
    assert "#2F6FEB" in svg and "#E8EAEE" in svg and "#17151C" not in svg
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300})
    svg = wide.icon()
    assert 'viewBox="0 0 1600 300"' in svg and all(ord(ch) < 127 for ch in svg)
    gw = geometry(wide)
    assert gw["vertical"] is True and gw["len"] > 100
    wide.tap(*at(gw, 0.5))
    assert near(pos(wide), 0.5, 1e-6)
    tiny = boot(props={"Pad Width": 120, "Pad Height": 120})
    assert len(tiny.icon()) < 8000
    gt = geometry(tiny)
    assert gt["len"] >= 40
    tiny.tap(*at(gt, 0.5))
    assert near(pos(tiny), 0.5, 1e-6)
    tinyH = boot(props={"Pad Width": 120, "Pad Height": 120, "Orientation": "Horizontal"})
    gh = geometry(tinyH)
    tinyH.tap(*at(gh, 0.5))
    assert near(pos(tinyH), 0.5, 1e-6) and tinyH.errors == []


def test_fader_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    g = geometry(q)
    q.drag(along(g, 0, 1, 100), seconds=2.0)
    assert near(pos(q), 1, 1e-6)
    q.set_pin("GrabMode", "Relative")
    q.drag(along(g, 1, 0, 100), seconds=2.0)
    assert near(pos(q), 0, 1e-6)
    q.set_pin("Taper", "Audio")
    q.set_pin("FaderMin", -60)
    q.drag(along(g, 0, 1, 50), seconds=1.0)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 30000 and b["max_handler"] < 30000, b
    assert len(q.icon()) < 10000
