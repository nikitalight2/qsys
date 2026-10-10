# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Panner mode (18_mode_panner.lua)
"""The Panner places a source in a room over a speaker layout (Speakers
property), outputs PanX / PanY / Pan (-1..1, both directions) and one
SpeakerGain per speaker in dB from a constant-power law on the distance to
each speaker (weights clamped at 1e-4, so -80 dB is the floor), widened by
Divergence. It draws the room, the speakers with a glow that follows their
gain and the source dot. A double tap centres the source."""
import math
import re

from harness import QSys

HINT = "Drag to pan, double tap to centre"
COUNTS = {"Stereo": 2, "LCR": 3, "Quad": 4, "5.1": 6, "7.1": 8}


def boot(**kw):
    kw.setdefault("mode", "Panner")
    kw.setdefault("picker", "Color_Picker")
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
        for want in ("PanX", "PanY", "Pan", "Divergence", "SpeakerGain"):
            assert want in names, (name, want)
        assert int(q.run("return #Controls.SpeakerGain")) == count
        assert len(names) == 26 + 5
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
    assert g[0] == 0 and g[1] < -10                        # on the left speaker, the right one far
    svg = q.icon()
    assert (lx, ly, 9.0) in circles(svg)                   # the finger dot
    assert HINT not in svg
    assert "0.0" in label_texts(svg)
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
    assert g[2] == max(g) and g[2] == 0
    q.lift()


def test_panner_divergence_widens_the_spread_and_applies_at_once():
    q = boot()
    q.touch([to_pad(q, -1, 1)])
    q.set_pin("Divergence", 0)
    g = gains(q)
    assert g[0] == 0 and g[1] == -80                       # the floor: w clamped at 1e-4
    q.set_pin("Divergence", 1)
    g = gains(q)
    assert g[0] - g[1] < 3                                 # nearly equal with a wide kernel
    assert near(power(g), 1.0, 0.02)
    # a mid position with Divergence 0.5 again
    q.set_pin("Divergence", 0.5)
    assert gains(q)[1] < -10


def test_panner_double_tap_centres_the_source():
    q = boot()
    q.touch([to_pad(q, 1, -1)], panel_touch=True)
    assert near(q.pin("PanX")["Value"], 1)
    q.double_tap(120, 120, panel_touch=True)
    assert q.pulses("DoubleTap") == 1 and q.pulses("Tap") == 2
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
    assert g[5] == 0 and g[2] == 0 and g[0] < g[2]
    assert near(power(g[:5]), 1.0, 0.02)
    q.lift()
    q = boot(props={"Speakers": "7.1"})
    assert int(q.run("return #Controls.SpeakerGain")) == 8
    texts = label_texts(q.icon())
    for want in ("Lss", "Rss", "Lrs", "Rrs", "LFE"):
        assert want in texts, want
    q.touch([to_pad(q, -1, 0)], lift=False)
    g = gains(q)
    assert g[3] == 0 and g[7] == 0 and near(power(g[:7]), 1.0, 0.02)
    q.lift()
    q = boot(props={"Speakers": "LCR"})
    q.touch([to_pad(q, 0, 1)], lift=False)
    g = gains(q)
    assert g[1] == 0 and near(g[0], g[2]) and g[0] < -5
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
    assert near(q.pin("PanX")["Value"], 0)
    assert (pts[-1][0], pts[-1][1], 5.0) in circles(q.icon())
    nx, ny = to_pad(q, 0.1, 0)
    q.touch([(nx, ny)], lift=False)                        # resumed
    assert near(q.pin("PanX")["Value"], 0.1)
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
    assert near(wide.pin("PanX")["Value"], 0.5) and near(wide.pin("PanY")["Value"], -0.5)


def test_panner_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Speakers": "7.1", "Max Frame Rate": "30"})
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(100)], seconds=2.0)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 12000
