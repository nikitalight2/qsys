# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the XY Pad mode (10_mode_xy.lua)
"""The XY Pad draws a card with a dotted grid, crosshair lines and a dot at
the finger, shows the hint "Drag anywhere" and outputs only the common set."""
import math
import re

from harness import QSys


def boot(**kw):
    kw.setdefault("mode", "XY Pad")
    kw.setdefault("picker", "Color_Picker")
    q = QSys(**kw)
    q.advance(0.2)
    return q


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


def circles(svg):
    """[(cx, cy, r)] of every <circle> in the SVG."""
    out = []
    for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)"', svg):
        out.append(tuple(float(v) for v in m.groups()))
    return out


def test_xy_idle_drawing_has_card_grid_crosshair_and_hint():
    q = boot()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert 'rx="18"' in svg                                   # the engine's pad frame
    assert "h0.5" in svg and 'stroke-linecap="round"' in svg  # the dotted grid path
    assert svg.count("stroke-dasharray") == 2                 # two crosshair hairlines
    assert "Drag anywhere" in svg
    assert all(ord(ch) < 127 for ch in svg)
    assert (250.0, 250.0, 6.0) in circles(svg)                # the crosshair ring sits at the centre


def test_xy_dot_follows_the_finger_and_hint_hides():
    q = boot()
    q.touch([(100, 400)], lift=False)
    svg = q.icon()
    assert (100.0, 400.0, 9.0) in circles(svg)                # the finger dot
    assert (100.0, 400.0, 6.0) in circles(svg)                # crosshair ring at the finger
    assert "Drag anywhere" not in svg
    assert '<line x1="0" y1="400" x2="500" y2="400"' in svg
    assert '<line x1="100" y1="0" x2="100" y2="500"' in svg
    q.touch([(300, 200)], lift=False)
    svg = q.icon()
    assert (300.0, 200.0, 9.0) in circles(svg) and (100.0, 400.0, 9.0) not in circles(svg)
    q.lift()
    svg = q.icon()
    assert (300.0, 200.0, 5.0) in circles(svg)                # the last position stays marked
    assert (300.0, 200.0, 9.0) not in circles(svg)
    assert "Drag anywhere" in svg


def test_xy_show_hints_off():
    q = boot(props={"Show Hints": False})
    assert "Drag anywhere" not in q.icon()
    assert q.pin("Gesture")["String"] == "DRAG ANYWHERE"      # the readout still names the hint


def test_xy_outputs_are_the_common_set_only():
    q = boot()
    names = q.control_names()
    assert len(names) == 26 and "Status" in names and "DragAngle" in names
    pts = [(100 + 20 * i, 400 - 20 * i) for i in range(11)]  # (100,400) -> (300,200)
    q.drag(pts, seconds=1.0)
    assert near(q.pin("X")["Value"], 0.6) and near(q.pin("Y")["Value"], 0.6)
    assert near(q.pin("DragDistance")["Value"], math.sqrt(2) * 200 / math.sqrt(2 * 500 ** 2))
    assert near(q.pin("DragAngle")["Value"], 45.0)
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1 and q.pulses("Tap") == 0


def test_xy_resume_keeps_the_dot_down():
    q = boot()
    q.touch([(100, 100), (150, 150), (200, 200)], lift=False)
    q.advance(0.5)                                            # inferred lift
    assert (200.0, 200.0, 5.0) in circles(q.icon())
    q.touch([(210, 210)], lift=False)                         # resumed
    assert (210.0, 210.0, 9.0) in circles(q.icon())
    q.lift()


def test_xy_lock_overlay_and_dot_release():
    q = boot()
    q.touch([(120, 120)], panel_touch=True, lift=False)
    q.set_pin("Lock", True)
    q.advance(0.05)                                           # the frame cap: at most one frame per 1/20 s
    svg = q.icon()
    assert "Locked" in svg and (120.0, 120.0, 9.0) not in circles(svg)
    q.lift()
    q.set_pin("Lock", False)
    assert "Locked" not in q.icon()


def test_xy_themes_and_background():
    light = boot(props={"Theme": "Light"})
    assert "#F4F4F6" in light.icon() and "#FFFFFF" in light.icon()
    custom = boot(props={"Theme": "Custom", "Accent Color": "#123456", "Background Color": "#202020"})
    svg = custom.icon()
    assert "#123456" in svg and "#202020" in svg
    clear = boot(props={"Background": "Transparent", "Corner Radius": 0})
    svg = clear.icon()
    assert 'rx="18"' not in svg
    assert svg.count('<rect x="0" y="0"') == 0                # no pad background at all
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300})
    assert 'viewBox="0 0 1600 300"' in wide.icon()
    assert len(wide.icon()) < 20000


def test_xy_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(100)], seconds=2.0)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 15000
