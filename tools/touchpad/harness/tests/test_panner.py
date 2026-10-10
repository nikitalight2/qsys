# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Panner mode (18_mode_panner.lua)
"""The Panner places a source in a room over a speaker layout (Speakers
property), outputs PanX / PanY / Pan (-1..1, both directions) and one
SpeakerGain per speaker in dB from a constant-power law on the distance to
each speaker (weights clamped at 1e-4, so -80 dB is the floor), widened by
Divergence. It draws the room, the speakers with a glow that follows their
gain and the source dot. A double tap centres the source."""
import math
import os
import re

from harness import QSys, DEFAULT_PLUGIN

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
MODE_BUILD = os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-panner.qplug")
PLUGIN = os.environ.get("TOUCHPAD_PLUGIN") or (MODE_BUILD if os.path.exists(MODE_BUILD) else DEFAULT_PLUGIN)

HINT = "Drag to pan, double tap to centre"
COUNTS = {"Stereo": 2, "LCR": 3, "Quad": 4, "5.1": 6, "7.1": 8}


def boot(**kw):
    kw.setdefault("mode", "Panner")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


def to_pad(q, x, y):
    """Pad pixels of a room position (-1..1, y forward)."""
    px, py = q.run("return TouchPad.inst.toPad(%r, %r)" % (float(x), float(y)))
    return float(px), float(py)


def gains(q):
    n = int(q.run("return #Controls.SpeakerGain"))
    return [q.pin("SpeakerGain", i)["Value"] for i in range(1, n + 1)]


def circles(svg):
    """[(cx, cy, r)] of every <circle> in the SVG."""
    out = []
    for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)"', svg):
        out.append(tuple(float(v) for v in m.groups()))
    return out


def label_texts(svg):
    return re.findall(r'<text[^>]*>([^<]*)</text>', svg)


def power(dbs):
    """Summed power of the positional gains (LFE excluded by the caller)."""
    return sum(10 ** (db / 10) for db in dbs)


def test_panner_controls_and_speaker_counts():
    for name, count in COUNTS.items():
        q = boot(props={"Speakers": name})
        names = q.control_names()
        for want in ("PanX", "PanY", "Pan", "Divergence", "SpeakerGain 1", "SpeakerGain %d" % count):
            assert want in names, (name, want)
        assert "SpeakerGain %d" % (count + 1) not in names
        assert int(q.run("return #Controls.SpeakerGain")) == count
        assert len(names) == 26 + 4 + count
        assert q.pin("Divergence")["Value"] == 0.5
        assert q.run("return TouchPad.inst.layoutName") == name
        assert q.status().startswith("OK") or "Picker OK" in q.status()


def test_panner_idle_source_sits_centred_with_equal_gains():
    q = boot()
    assert q.pin("PanX")["Value"] == 0 and q.pin("PanY")["Value"] == 0 and q.pin("Pan")["Value"] == 0
    g = gains(q)
    assert len(g) == 2 and near(g[0], -3.01, 1e-9) and near(g[1], -3.01, 1e-9)
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    assert HINT in svg
    assert "<radialGradient id=\"pglow\"" in svg and 'fill="url(#pglow)"' in svg
    texts = label_texts(svg)
    assert "L" in texts and "R" in texts and "-3.0" in texts and "+0.00 / +0.00" in texts
    cx, cy = to_pad(q, 0, 0)
    assert (cx, cy, 11.0) in circles(svg) and (cx, cy, 5.0) in circles(svg)


def test_panner_touch_places_the_source_and_drives_the_gains():
    q = boot()
    lx, ly = to_pad(q, -1, 1)
    q.touch([(lx, ly)], lift=False)
    assert near(q.pin("PanX")["Value"], -1) and near(q.pin("PanY")["Value"], 1)
    assert near(q.pin("Pan")["Value"], -1)
    g = gains(q)
    assert g[0] > -0.2 and g[1] < -10                      # on the left speaker, the right one far
    svg = q.icon()
    assert (lx, ly, 9.0) in circles(svg)                   # the finger dot
    assert HINT not in svg
    assert "-1.00 / +1.00" in label_texts(svg)
    rx, ry = to_pad(q, 1, -1)
    q.touch([(rx, ry)], lift=False)
    assert near(q.pin("PanX")["Value"], 1) and near(q.pin("PanY")["Value"], -1)
    q.lift()
    svg = q.icon()
    assert HINT in svg
    assert near(q.pin("PanX")["Value"], 1)                 # the source stays where it was left
    assert (rx, ry, 5.0) in circles(svg)
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1


def test_panner_touch_outside_the_inner_area_clamps_to_the_edge():
    q = boot()
    q.touch([(2, 2)], lift=False)                          # the room corner, outside the speaker square
    assert near(q.pin("PanX")["Value"], -1) and near(q.pin("PanY")["Value"], 1)
    q.touch([(498, 498)], lift=False)
    assert near(q.pin("PanX")["Value"], 1) and near(q.pin("PanY")["Value"], -1)
    q.lift()


def test_panner_gains_follow_a_constant_power_law():
    q = boot(props={"Speakers": "Quad"})
    for x, y in [(0, 0), (-1, 1), (0.3, -0.6), (1, 0), (-0.5, -0.5), (0.9, 0.9)]:
        q.touch([to_pad(q, x, y)], lift=False)
        q.advance(0.05)
        g = gains(q)
        assert len(g) == 4
        assert near(power(g), 1.0, 0.02), (x, y, g)
        assert all(-80 <= v <= 0 for v in g)
    q.lift()
    # the white-box weights are exactly constant power before the dB rounding
    w = q.run("local w = TouchPad.inst.computeWeights(0.3, -0.6, 0.5) return w[1], w[2], w[3], w[4]")
    assert near(sum(float(v) ** 2 for v in w), 1.0, 1e-9)
    # the nearest speaker gets the most
    q.touch([to_pad(q, -1, -1)], lift=False)
    g = gains(q)
    assert g[2] == max(g) and g[2] > -0.2
    q.lift()


def test_panner_divergence_widens_the_spread_and_applies_at_once():
    q = boot()
    q.touch([to_pad(q, -1, 1)])
    q.set_pin("Divergence", 0)
    g = gains(q)
    assert g[0] == 0 and g[1] == -80                       # the floor: w clamped at 1e-4
    q.set_pin("Divergence", 1)
    g = gains(q)
    assert g[0] - g[1] < 1.5                               # nearly equal with a wide kernel
    assert near(power(g), 1.0, 0.02)
    q.set_pin("Divergence", 0.5)                           # the default: a focused image
    g = gains(q)
    assert g[0] > -0.2 and g[1] < -10
    q.set_pin("Divergence", 0.8)
    g = gains(q)
    assert -8 < g[1] < -2


def test_panner_double_tap_centres_the_source():
    q = boot()
    q.touch([to_pad(q, 1, -1)], panel_touch=True)
    assert near(q.pin("PanX")["Value"], 1)
    q.double_tap(120, 120, panel_touch=True)
    assert q.pulses("DoubleTap") == 1 and q.pulses("Tap") == 3   # the first touch was a tap too
    assert q.pin("PanX")["Value"] == 0 and q.pin("PanY")["Value"] == 0 and q.pin("Pan")["Value"] == 0
    assert q.pin("Gesture")["String"] == "CENTRE"
    g = gains(q)
    assert near(g[0], g[1]) and near(g[0], -3.01, 1e-9)
    q.advance(0.1)
    cx, cy = to_pad(q, 0, 0)
    assert (cx, cy, 5.0) in circles(q.icon())


def test_panner_pins_move_the_source():
    q = boot()
    q.set_pin("PanX", 0.5)
    assert near(q.pin("Pan")["Value"], 0.5) and q.pin("PanY")["Value"] == 0
    g = gains(q)
    assert g[1] > g[0]
    q.advance(0.1)
    sx, sy = to_pad(q, 0.5, 0)
    assert (sx, sy, 5.0) in circles(q.icon())
    q.set_pin("Pan", -0.5)
    assert near(q.pin("PanX")["Value"], -0.5)
    assert gains(q)[0] > gains(q)[1]
    q.set_pin("PanY", -1)
    assert near(q.pin("PanY")["Value"], -1) and near(q.pin("PanX")["Value"], -0.5)
    q.set_pin("PanX", 7)                                   # out of range: clamped by the knob
    assert near(q.pin("PanX")["Value"], 1) and near(q.pin("Pan")["Value"], 1)


def test_panner_surround_layouts_keep_the_lfe_at_full_level():
    q = boot(props={"Speakers": "5.1"})
    assert int(q.run("return #Controls.SpeakerGain")) == 6
    svg = q.icon()
    texts = label_texts(svg)
    for want in ("L", "C", "R", "Ls", "Rs", "LFE"):
        assert want in texts, want
    assert gains(q)[5] == 0
    q.touch([to_pad(q, 1, 1)], lift=False)
    g = gains(q)
    assert g[5] == 0 and g[2] == max(g[:5]) and g[2] > -1 and g[0] < g[2]   # C one unit away shares a little
    assert near(power(g[:5]), 1.0, 0.02)
    q.lift()
    q = boot(props={"Speakers": "7.1"})
    assert int(q.run("return #Controls.SpeakerGain")) == 8
    texts = label_texts(q.icon())
    for want in ("Lss", "Rss", "Lrs", "Rrs", "LFE"):
        assert want in texts, want
    q.touch([to_pad(q, -1, 0)], lift=False)
    g = gains(q)
    assert g[3] == max(g[:7]) and g[3] > -1.5 and g[7] == 0 and near(power(g[:7]), 1.0, 0.02)
    q.lift()
    q = boot(props={"Speakers": "LCR"})
    q.touch([to_pad(q, 0, 1)], lift=False)
    g = gains(q)
    assert g[1] == max(g) and g[1] > -1.5 and near(g[0], g[2]) and g[0] < -5
    q.lift()


def test_panner_speaker_glow_follows_the_gain():
    q = boot()
    lx, ly = to_pad(q, -1, 1)
    rx, ry = to_pad(q, 1, 1)
    q.touch([(lx, ly)], lift=False)
    svg = q.icon()
    cs = circles(svg)
    glow_l = max(r for cx, cy, r in cs if (cx, cy) == (lx, ly))
    glow_r = max(r for cx, cy, r in cs if (cx, cy) == (rx, ry))
    sr = float(q.run("return TouchPad.inst.geometry.sr"))
    assert glow_l > glow_r and glow_r <= sr + 1 and glow_l > sr * 2
    q.touch([(rx, ry)], lift=False)
    cs = circles(q.icon())
    assert max(r for cx, cy, r in cs if (cx, cy) == (rx, ry)) > max(r for cx, cy, r in cs if (cx, cy) == (lx, ly))
    q.lift()


def test_panner_show_hints_off():
    q = boot(props={"Show Hints": False})
    assert HINT not in q.icon()
    assert q.pin("Gesture")["String"] == HINT.upper()
    g = q.run("local g = TouchPad.inst.geometry return g.rh")
    assert float(g) == 500 - 20                            # the room takes the hint line's height


def test_panner_lock_releases_the_finger_and_keeps_the_source():
    q = boot()
    sx, sy = to_pad(q, 0.5, 0.5)
    q.touch([(sx, sy)], panel_touch=True, lift=False)
    q.set_pin("Lock", True)
    q.advance(0.05)
    svg = q.icon()
    assert "Locked" in svg and (sx, sy, 9.0) not in circles(svg)
    assert near(q.pin("PanX")["Value"], 0.5) and near(q.pin("PanY")["Value"], 0.5)
    q.lift()
    q.set_pin("Lock", False)
    assert "Locked" not in q.icon()


def test_panner_resume_keeps_the_source_moving():
    q = boot()
    pts = [to_pad(q, -1 + 0.2 * i, 0) for i in range(6)]
    q.touch(pts, lift=False)
    q.advance(0.5)                                         # inferred lift
    assert near(q.pin("PanX")["Value"], 0, 0.01)
    assert (pts[-1][0], pts[-1][1], 5.0) in circles(q.icon())
    nx, ny = to_pad(q, 0.1, 0.1)                           # both axes move: one report, no landing wait
    q.touch([(nx, ny)], lift=False)                        # resumed
    assert near(q.pin("PanX")["Value"], 0.1, 0.01) and near(q.pin("PanY")["Value"], 0.1, 0.01)
    assert (nx, ny, 9.0) in circles(q.icon())
    q.lift()
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1


def test_panner_themes_and_odd_pad_sizes():
    light = boot(props={"Theme": "Light", "Speakers": "7.1"})
    svg = light.icon()
    assert "#2F6FEB" in svg and "#FFFFFF" in svg and all(ord(ch) < 127 for ch in svg)
    small = boot(props={"Pad Width": 120, "Pad Height": 120, "Speakers": "7.1"})
    svg = small.icon()
    assert 'viewBox="0 0 120 120"' in svg
    small.touch([(60, 60)])
    assert near(power(gains(small)[:7]), 1.0, 0.02)
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300, "Speakers": "5.1"})
    svg = wide.icon()
    assert 'viewBox="0 0 1600 300"' in svg and len(svg) < 12000
    wide.touch([to_pad(wide, 0.5, -0.5)])
    assert near(wide.pin("PanX")["Value"], 0.5, 0.01) and near(wide.pin("PanY")["Value"], -0.5, 0.02)


def test_panner_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Speakers": "7.1", "Max Frame Rate": "30"})
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(100)], seconds=2.0)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 12000


def test_panner_font_property_reaches_the_speaker_labels():
    # The static room canvas (labels) must take the Font property like the
    # readouts drawn on the engine's canvas: one family for every <text>.
    q = boot(props={"Font": "Heebo Bold", "Speakers": "7.1"})
    svg = q.icon()
    fams = set(re.findall(r'<text[^>]*font-family="([^"]*)"', svg))
    assert fams == {"Heebo Bold, Roboto, sans-serif"}, fams
    assert 'font-family="Roboto, sans-serif"' not in svg
    texts = label_texts(svg)
    for want in ("L", "C", "R", "Lss", "Rss", "Lrs", "Rrs", "LFE", "+0.00 / +0.00", HINT):
        assert want in texts, want
    assert all(ord(ch) < 127 for ch in svg)
    # the cached static part keeps the family across frames
    q.touch([to_pad(q, 0.5, 0.5)], lift=False)
    assert 'font-family="Roboto, sans-serif"' not in q.icon()
    q.lift()
    # the default font keeps the plain family on every string
    plain = boot(props={"Speakers": "5.1"})
    fams = set(re.findall(r'<text[^>]*font-family="([^"]*)"', plain.icon()))
    assert fams == {"Roboto, sans-serif"}, fams


def test_panner_nan_pin_writes_centre_the_axis():
    # A NaN written to PanX / Pan / PanY must not be clamped to -1: it reads
    # as 0 (centre) on that axis and the other axis is kept.
    q = boot()
    q.set_pin("PanX", 0.5)
    q.set_pin("PanY", 0.5)
    q.advance(0.25)
    q.set_pin("PanX", float("nan"))
    assert q.run("return TouchPad.inst.x") == 0 and near(q.run("return TouchPad.inst.y"), 0.5)
    assert q.pin("PanX")["Value"] == 0 and q.pin("Pan")["Value"] == 0
    assert near(q.pin("PanY")["Value"], 0.5)
    g = gains(q)
    assert near(g[0], g[1]) and g[0] > -4                  # centred: both speakers equal
    q.advance(0.25)
    q.set_pin("PanY", float("nan"))
    assert q.run("return TouchPad.inst.y") == 0 and q.pin("PanY")["Value"] == 0
    assert q.pin("PanX")["Value"] == 0
    q.advance(0.25)
    q.set_pin("Pan", -0.25)
    assert near(q.pin("PanX")["Value"], -0.25)
    q.advance(0.25)
    q.set_pin("Pan", float("nan"))
    assert q.run("return TouchPad.inst.x") == 0 and q.pin("PanX")["Value"] == 0 and q.pin("Pan")["Value"] == 0
    assert all(-80 <= v <= 0 for v in gains(q))
    assert "Lua error" not in " ".join(q.output())
    # a NaN written while the source already sits at the centre: the pins are
    # rewritten so none of them keeps the NaN
    idle = boot()
    idle.set_pin("PanX", float("nan"))
    assert idle.pin("PanX")["Value"] == 0 and idle.pin("Pan")["Value"] == 0
    idle.advance(0.25)
    idle.set_pin("PanY", float("nan"))
    assert idle.pin("PanY")["Value"] == 0 and tuple(idle.run("return TouchPad.inst.x, TouchPad.inst.y")) == (0, 0)


def test_panner_coupled_pins_stay_consistent():
    # PanX, Pan and the source agree after any sequence of pin writes
    # (writes spaced past the engine's 0.2 s echo window; the faster
    # sequence depends on the engine clearing its own-write mark).
    q = boot()
    seq = [("PanX", 0.5), ("Pan", 0.7), ("Pan", 0.5), ("PanX", -0.3), ("Pan", -0.3), ("PanX", 0.5)]
    for name, v in seq:
        q.set_pin(name, v)
        q.advance(0.25)
        x = float(q.run("return TouchPad.inst.x"))
        assert near(x, v) and near(q.pin("PanX")["Value"], v) and near(q.pin("Pan")["Value"], v), (name, v, x)
    # a finger then a pin write of the same value the finger produced
    q.touch([to_pad(q, 0.5, 0)], lift=False)
    q.lift()
    q.advance(0.25)
    q.set_pin("PanX", 0.3)
    q.advance(0.25)
    q.set_pin("PanX", 0.5)
    assert near(q.run("return TouchPad.inst.x"), 0.5) and near(q.pin("Pan")["Value"], 0.5)
