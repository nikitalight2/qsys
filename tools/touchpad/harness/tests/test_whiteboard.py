# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Whiteboard mode (26_mode_whiteboard.lua)
"""The Whiteboard draws freehand strokes in the pen colour and width, a
touch without movement draws a dot, the Eraser removes strokes the finger
crosses, Undo and ClearBoard edit the board, Strokes counts, Snapshot writes
<base>/Whiteboard/<time>.svg and names it on LastFile. Strokes keep at most
400 points, the board at most 60 strokes and 2400 points."""
import math
import os
import re

from harness import QSys
from harness.qsys_fake import DEFAULT_PLUGIN

ACCENT, ACCENT2, TEXT, MUTED, OK, DANGER = "#C513E8", "#FF8A1E", "#F4F2F7", "#A79FB3", "#2ECC8F", "#F0328C"

# The full plugin when it carries the Whiteboard mode, else the per-mode build
# (python3 tools/touchpad/build.py --modes whiteboard --out plugins/.build/NikitaTouchPad-whiteboard.qplug).
PER_MODE = os.path.join(os.path.dirname(os.path.abspath(DEFAULT_PLUGIN)), ".build", "NikitaTouchPad-whiteboard.qplug")


def has_whiteboard(path):
    """True when the plugin at `path` registers the mode (MODE_NAMES lists every
    mode name whether or not its module was built in, so the source is checked)."""
    try:
        with open(path, "rb") as fh:
            return b'Modes["Whiteboard"]' in fh.read()
    except OSError:
        return False


def plugin_path():
    if has_whiteboard(DEFAULT_PLUGIN):
        return DEFAULT_PLUGIN
    return PER_MODE if os.path.exists(PER_MODE) else DEFAULT_PLUGIN


def boot(**kw):
    kw.setdefault("mode", "Whiteboard")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", plugin_path())
    q = QSys(**kw)
    q.advance(0.2)
    return q


def polylines(svg):
    """[(points, attrs)] of every <polyline> in the SVG; points as [(x, y)]."""
    out = []
    for m in re.finditer(r'<polyline points="([^"]*)"([^>]*)/>', svg):
        pts = [tuple(float(v) for v in p.split(",")) for p in m.group(1).split()]
        out.append((pts, m.group(2)))
    return out


def stroke_circles(svg):
    """Filled circles without a stroke attribute: the dots (the badge swatch has a stroke)."""
    out = []
    for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)" fill="(#[0-9A-F]{6})"/>', svg):
        out.append((float(m.group(1)), float(m.group(2)), float(m.group(3)), m.group(4)))
    return out


def pulse(q, name):
    q.set_pin(name, True)
    q.set_pin(name, False)


def strokes(q):
    """The Strokes pin; also checks that no handler error was swallowed by the engine's guard."""
    assert "Recovered" not in q.status(), q.status()
    assert q.errors == []
    return int(q.pin("Strokes")["String"])


def lua_points(q, index=None):
    """Kept point count of a stroke (default: the last) from the mode's state."""
    idx = "#TouchPad.inst.strokes" if index is None else str(index)
    return q.run("return #TouchPad.inst.strokes[%s].pts // 2" % idx)


def zigzag(n, x0=40, y0=250, step=0.9, amp=14):
    """n points that RDP cannot straighten: a saw tooth 2*amp high."""
    return [(x0 + step * i, y0 + (amp if i % 2 else -amp)) for i in range(n)]


def scribble(n, x0, y0, roww=60, step=0.9, amp=5, rowh=12):
    """n points of a serpentine saw tooth filling rows `roww` wide, `rowh` apart:
    a dense hatch RDP keeps almost entirely."""
    per = int(roww / step)
    pts = []
    for i in range(n):
        r, k = divmod(i, per)
        x = x0 + k * step if r % 2 == 0 else x0 + roww - k * step
        y = y0 + r * rowh + (amp if i % 2 else -amp)
        pts.append((x, y))
    return pts


def total_points(q):
    return q.run("local n = 0; for i = 1, #TouchPad.inst.strokes do n = n + #TouchPad.inst.strokes[i].pts // 2 end; return n")


# ------------------------------------------------------------ controls, layout, idle drawing

def test_whiteboard_controls_defaults_and_layout_lint():
    q = boot()
    names = q.control_names()
    for n in ["PenWidth", "PenColor", "Eraser", "Undo", "ClearBoard", "Snapshot", "Strokes", "LastFile"]:
        assert n in names, n
    assert len(names) == 34                                   # 26 common + 8 whiteboard
    assert q.pin("PenWidth")["Value"] == 3
    assert q.pin("PenColor")["String"] == "Accent"
    assert q.pin("PenColor")["Choices"] == ["Accent", "White", "Black", "Red", "Green", "Blue"]
    assert q.pin("Eraser")["Boolean"] is False
    assert q.pin("Strokes")["String"] == "0"
    assert q.pin("LastFile")["String"] == ""
    assert q.layout_lint([{}, {"Pad Width": 120, "Pad Height": 120}, {"Pad Width": 1600, "Pad Height": 1200},
                          {"Show Hints": False}, {"Theme": "Light"}]) == []
    # pins carry the Whiteboard group
    assert q.run('return GetControlLayout(Properties)["PenWidth"].PrettyName') == "Whiteboard~Pen Width"
    pages = q.run("return #GetPages(Properties)")
    assert pages == 5


def test_whiteboard_idle_drawing_badge_and_hint():
    q = boot()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert "Draw with one finger" in svg
    assert q.pin("Gesture")["String"] == "DRAW WITH ONE FINGER"
    assert "M4 20l1-5L16 4l4 4L9 19z" in svg                  # the pen icon of the badge
    assert ('<circle cx="466" cy="484" r="5" fill="%s"' % ACCENT) in svg   # the colour swatch
    assert polylines(svg) == [] and stroke_circles(svg) == []
    assert all(ord(ch) < 127 for ch in svg)
    assert len(svg) < 1200


def test_whiteboard_show_hints_off():
    q = boot(props={"Show Hints": False})
    assert "Draw with one finger" not in q.icon()
    q.set_pin("Eraser", True)
    assert "Eraser:" not in q.icon() and "ERASER" in q.icon()  # the badge still names the tool


# ------------------------------------------------------------ strokes

def test_whiteboard_drag_draws_a_stroke_live_then_finished():
    q = boot()
    pts = [(100 + 20 * i, 100 + 10 * i) for i in range(11)]  # (100,100) -> (300,200)
    q.touch(pts, dt=0.05, lift=False)
    svg = q.icon()
    assert strokes(q) == 1
    assert "Draw with one finger" not in svg
    live = polylines(svg)
    assert len(live) >= 1
    assert all(('stroke="%s"' % ACCENT) in a and 'stroke-width="3"' in a and 'stroke-linecap="round"' in a
               for _, a in live)
    assert live[-1][0][-1] == (300.0, 200.0)                  # the tail reaches the finger
    q.lift()
    svg = q.icon()
    finished = polylines(svg)
    assert len(finished) == 1                                 # one simplified polyline
    assert finished[0][0][0] == (100.0, 100.0) and finished[0][0][-1] == (300.0, 200.0)
    assert len(finished[0][0]) == 2                           # a straight line keeps its two ends
    assert strokes(q) == 1 and q.pulses("Release") == 1
    assert "Draw with one finger" not in svg                  # the hint stays off while strokes exist
    # a second stroke adds a second polyline and keeps the first
    q.drag([(100, 400), (200, 380), (300, 400)], seconds=0.3)
    assert strokes(q) == 2 and len(polylines(q.icon())) == 2


def test_whiteboard_tap_draws_a_dot():
    q = boot()
    q.tap(300, 300)
    assert strokes(q) == 1
    dots = stroke_circles(q.icon())
    assert (300.0, 300.0, 2.4, ACCENT) in dots                # r = width * 0.8
    assert polylines(q.icon()) == []
    assert q.pulses("Tap") == 1
    # a tiny wobble under 2.5 px is still a dot
    q.touch([(120, 120), (121, 121)], dt=0.05)
    assert strokes(q) == 2
    assert any(abs(c[0] - 120) < 2 and abs(c[1] - 120) < 2 for c in stroke_circles(q.icon()))


def test_whiteboard_pen_color_and_width_apply_to_the_next_stroke():
    q = boot()
    q.set_pin("PenColor", "Red")
    q.set_pin("PenWidth", 6)
    assert ('<circle cx="466" cy="484" r="5" fill="#E53935"' % ()) in q.icon()   # the swatch follows
    q.drag([(50, 50), (150, 60), (250, 50)], seconds=0.3)
    (_, attrs), = polylines(q.icon())
    assert 'stroke="#E53935"' in attrs and 'stroke-width="6"' in attrs
    q.set_pin("PenColor", "white")                            # case does not matter
    q.set_pin("PenWidth", 1.26)                               # rounded to 0.5
    q.drag([(50, 150), (150, 160), (250, 150)], seconds=0.3)
    attrs = polylines(q.icon())[-1][1]
    assert 'stroke="#FFFFFF"' in attrs and 'stroke-width="1.5"' in attrs
    for name, hexv in [("Black", "#000000"), ("Green", "#43A047"), ("Blue", "#1E88E5"), ("Accent", ACCENT),
                       ("purple", ACCENT), ("", ACCENT)]:     # unknown names fall back to the accent
        q.set_pin("PenColor", name)
        assert q.run("return TouchPad.inst.color") == hexv, name
    # the first stroke keeps its own colour and width
    first = polylines(q.icon())[0][1]
    assert 'stroke="#E53935"' in first and 'stroke-width="6"' in first
    # a Light theme accent
    light = boot(props={"Theme": "Light"})
    light.tap(200, 200)
    assert stroke_circles(light.icon())[0][3] == light.run("return TouchPad.E.T.accent")


def test_whiteboard_undo_and_clear_board():
    q = boot()
    q.drag([(50, 50), (150, 60), (250, 50)], seconds=0.3)
    q.drag([(50, 150), (150, 160), (250, 150)], seconds=0.3)
    q.tap(300, 300)
    assert strokes(q) == 3
    pulse(q, "Undo")                                          # a pin pulse: true then false
    assert strokes(q) == 2 and q.pin("Gesture")["String"] == "UNDO"
    assert stroke_circles(q.icon()) == [] and len(polylines(q.icon())) == 2
    q.advance(0.3)
    q.trigger("Undo")                                         # the Pad page button: handler with Boolean false
    assert strokes(q) == 1 and len(polylines(q.icon())) == 1
    assert polylines(q.icon())[0][0][0] == (50.0, 50.0)       # the oldest stroke remains
    q.advance(0.3)
    pulse(q, "Undo")
    assert strokes(q) == 0
    q.advance(0.3)
    pulse(q, "Undo")
    assert strokes(q) == 0 and q.pin("Gesture")["String"] == "NOTHING TO UNDO"
    assert "Draw with one finger" in q.icon()                 # the hint returns on an empty board
    q.drag([(50, 50), (150, 60), (250, 50)], seconds=0.3)
    q.tap(300, 300)
    pulse(q, "ClearBoard")
    assert strokes(q) == 0 and q.pin("Gesture")["String"] == "BOARD CLEARED"
    assert polylines(q.icon()) == [] and stroke_circles(q.icon()) == []
    q.advance(1)
    q.trigger("ClearBoard")
    assert q.pin("Gesture")["String"] == "BOARD EMPTY"
    # Undo during a live stroke drops the stroke being drawn
    q.advance(1)
    q.touch([(100, 100), (150, 150), (200, 200)], lift=False)
    assert strokes(q) == 1
    pulse(q, "Undo")
    assert strokes(q) == 0
    q.touch([(250, 250)], lift=False)                         # the rest of the touch draws nothing
    assert strokes(q) == 0
    q.lift()
    assert strokes(q) == 0


def test_whiteboard_eraser_removes_crossed_strokes_only():
    q = boot()
    q.drag([(100 + 20 * i, 100) for i in range(11)], seconds=0.5)        # horizontal at y = 100
    q.drag([(100 + 20 * i, 300) for i in range(11)], seconds=0.5)        # horizontal at y = 300
    q.tap(400, 400)                                                      # a dot
    assert strokes(q) == 3
    q.set_pin("Eraser", True)
    assert q.pin("Gesture")["String"] == "ERASER ON"
    svg = q.icon()
    assert "Eraser: drag across a stroke to remove it" in svg and "ERASER" in svg
    assert "M17 3l4 4L10 18H6l-3-3L17 3z" in svg                        # the eraser icon
    # a vertical eraser stroke across y = 100 only
    q.touch([(150, 40 + 10 * i) for i in range(12)], dt=0.04, lift=False)  # 40 -> 150
    svg = q.icon()
    assert strokes(q) == 2 and q.pin("Gesture")["String"] == "ERASED 1 STROKE"
    assert ('<circle cx="150" cy="150" r="15" fill="none" stroke="%s"' % ACCENT2) in svg   # the eraser cursor
    assert [p[0][0] for p in polylines(svg)] == [(100.0, 300.0)]        # the y = 300 stroke remains
    q.lift()
    assert "r=\"15\" fill=\"none\"" not in q.icon()                      # the cursor leaves with the finger
    # the eraser does not draw
    assert strokes(q) == 2 and len(polylines(q.icon())) == 1
    # touching down right on a dot erases it, a long segment is hit in its middle too
    q.touch([(402, 402)], lift=False)
    assert strokes(q) == 1 and stroke_circles(q.icon()) == []
    q.lift()
    q.touch([(200, 240 + 12 * i) for i in range(10)], dt=0.04)          # crosses y = 300 at x = 200
    assert strokes(q) == 0 and polylines(q.icon()) == []
    # a stroke far away is left alone
    q.set_pin("Eraser", False)
    assert q.pin("Gesture")["String"] == "PEN"
    q.drag([(50, 450), (150, 460), (250, 450)], seconds=0.3)
    q.set_pin("Eraser", True)
    q.touch([(400, 100 + 10 * i) for i in range(10)], dt=0.04)
    assert strokes(q) == 1


def test_whiteboard_eraser_drag_onto_a_line_and_lift():
    """An eraser drag that stops within reach of a segment's interior without
    crossing it erases on the lift, and so does a finger resting on the line."""
    q = boot()
    q.drag([(100 + 20 * i, 300) for i in range(11)], seconds=0.5)        # (100,300)-(300,300), two kept points
    assert polylines(q.icon())[0][0] == [(100.0, 300.0), (300.0, 300.0)]
    q.set_pin("Eraser", True)
    q.touch([(200, 200), (200, 290)], dt=0.05)                           # stops 10 px short (reach 16.5)
    assert strokes(q) == 0 and q.pin("Gesture")["String"] == "ERASED 1 STROKE"
    # the same approach that stops outside the reach leaves the stroke alone
    q.set_pin("Eraser", False)
    q.drag([(100 + 20 * i, 300) for i in range(11)], seconds=0.5)
    q.set_pin("Eraser", True)
    q.touch([(200, 200), (200, 280)], dt=0.05)                           # 20 px short
    assert strokes(q) == 1
    # the far end of a long report is tested too: the report ends on a dot
    q.set_pin("Eraser", False)
    q.tap(400, 100)
    q.set_pin("Eraser", True)
    q.touch([(100, 100), (400, 100)], dt=0.05)
    assert strokes(q) == 1 and stroke_circles(q.icon()) == []
    assert q.errors == []
    # a finger resting exactly on the line (PanelTouch held) erases it; PanelTouch
    # is sticky once used, so this runs on its own instance
    p = boot()
    p.drag([(100 + 20 * i, 300) for i in range(11)], seconds=0.5, panel_touch=True)
    assert strokes(p) == 1
    p.set_pin("Eraser", True)
    p.touch([(200, 200), (200, 300)], dt=0.05, panel_touch=True, hold=1.0)
    assert strokes(p) == 0 and p.errors == []


def test_whiteboard_eraser_hit_test_stays_in_budget():
    """A dense 400-point hatch in the corner of a long diagonal eraser report,
    a board at the point cap crossed by one pad-wide report and realistic
    sweeps all stay far under the handler budget."""
    q = boot()
    q.touch(scribble(395, 350, 232, roww=68, step=1.0, amp=5, rowh=11), dt=0.02)
    q.advance(2.0)
    assert strokes(q) == 1 and lua_points(q) >= 350
    q.set_pin("Eraser", True)
    q.reset_pulses()
    before = q.budget()["handlers"].get("callafter", 0)
    q.touch([(250, 300), (420, 130)], dt=0.033)                          # x + y = 550, 23+ px from the hatch
    assert strokes(q) == 1                                               # nothing within reach
    b = q.budget()
    assert b["handlers"]["callafter"] < 40000, b["handlers"]["callafter"]
    assert b["max_handler"] < 120000
    # three such hatches, then a board at the cap of six corner scribbles with a full diagonal
    q2 = boot()
    for k in range(6):
        q2.touch(scribble(395, 40 + (k % 3) * 70, 40 + (k // 3) * 90), dt=0.02)
        q2.advance(2.0)
    assert strokes(q2) == 6 and total_points(q2) > 2000
    q2.set_pin("Eraser", True)
    q2.touch([(20, 480), (480, 20)], dt=0.05)                            # one pad-wide jump
    b = q2.budget()
    assert b["handlers"]["callafter"] < 60000, b["handlers"]["callafter"]
    # the same diagonal in 100 px reports over a spread board erases what it crosses
    q3 = boot()
    for k in range(6):
        x0, y0 = 20 + (k % 3) * 153 + 10, 20 + (k // 3) * 230 + 10
        q3.touch(scribble(395, x0, y0, roww=123, step=1.0, amp=6, rowh=14), dt=0.02)
        q3.advance(2.0)
    assert strokes(q3) == 6
    q3.set_pin("Eraser", True)
    q3.touch([(20 + 70 * i, 480 - 70 * i) for i in range(7)], dt=0.033)
    assert strokes(q3) < 6
    b = q3.budget()
    assert b["max_handler"] < 60000 and b["max_frame"] < 60000, b
    assert q.errors == [] and q2.errors == [] and q3.errors == []


def test_whiteboard_trigger_presses_in_quick_succession_all_count():
    """Pad page presses (handler with Boolean false) 0.3 s apart each count;
    a pin pulse (true then false) counts once."""
    q = boot()
    for k in range(3):
        q.drag([(50, 50 + 100 * k), (150, 60 + 100 * k), (250, 50 + 100 * k)], seconds=0.3)
    assert strokes(q) == 3
    q.trigger("Undo")
    q.advance(0.3)
    q.trigger("Undo")
    assert strokes(q) == 1
    q.trigger("Undo")                                                    # back to back
    assert strokes(q) == 0
    q.drag([(50, 50), (150, 60), (250, 50)], seconds=0.3)
    q.drag([(50, 150), (150, 160), (250, 150)], seconds=0.3)
    pulse(q, "Undo")                                                     # one press, not two
    assert strokes(q) == 1
    pulse(q, "Undo")                                                     # right after: a second press
    assert strokes(q) == 0
    q.set_pin("Undo", True)                                              # a true edge, false edge much later
    q.advance(1.5)
    q.drag([(50, 50), (150, 60), (250, 50)], seconds=0.3)
    q.set_pin("Undo", False)                                             # no longer the trailing edge
    assert strokes(q) == 0
    q.trigger("Snapshot")
    q.advance(0.3)
    q.trigger("Snapshot")
    assert len(q.list_files()) == 2
    pulse(q, "Snapshot")
    assert len(q.list_files()) == 3
    q.drag([(50, 50), (150, 60), (250, 50)], seconds=0.3)
    q.trigger("ClearBoard")
    q.advance(0.3)
    q.trigger("ClearBoard")
    assert strokes(q) == 0 and q.pin("Gesture")["String"] == "BOARD EMPTY"
    assert q.errors == []


def test_whiteboard_resume_far_from_the_lift_starts_a_new_stroke():
    """Without PanelTouch the engine resumes a drag that comes back within 1.5 s;
    the stroke continues only when the finger lands close to where it left."""
    q = boot()
    q.touch([(100, 200), (120, 150), (140, 200)], dt=0.05)              # a letter; lift inferred
    assert strokes(q) == 1 and q.pin("Touching")["Boolean"] is False
    q.touch([(180, 200), (200, 150), (220, 200)], dt=0.05)              # the next letter 40 px away, 0.65 s later
    assert strokes(q) == 2
    lines = polylines(q.icon())
    assert len(lines) == 2
    assert lines[0][0] == [(100.0, 200.0), (120.0, 150.0), (140.0, 200.0)]
    # the engine settles the resume on the first or second report of the new touch
    assert lines[1][0][0] in [(180.0, 200.0), (200.0, 150.0)] and lines[1][0][-1] == (220.0, 200.0)
    # a resume within the continuity distance (20 px here) continues the stroke
    # (2 s gaps: a touch inside the engine's 1.5 s window lands on its second report)
    q.advance(2.0)
    q.touch([(300, 300), (350, 350)], lift=False)
    q.advance(0.5)
    assert strokes(q) == 3 and q.pin("Touching")["Boolean"] is False
    q.touch([(362, 362), (362, 362), (400, 400)], dt=0.05)               # 17 px from the lift point
    assert strokes(q) == 3
    joined = polylines(q.icon())[-1][0]
    assert joined[0] == (300.0, 300.0) and joined[-1] == (400.0, 400.0)
    # just outside it, a new stroke; a wide pen widens the distance (3 widths)
    q.advance(2.0)
    q.touch([(100, 400), (150, 450)], lift=False)
    q.advance(0.5)
    q.touch([(166, 466), (166, 466), (200, 480)], dt=0.05)               # 22.6 px away
    assert strokes(q) == 5
    assert polylines(q.icon())[-2][0] == [(100.0, 400.0), (150.0, 450.0)]
    q.advance(2.0)
    q.set_pin("PenWidth", 8)
    q.touch([(300, 100), (350, 100)], lift=False)
    q.advance(0.5)
    q.touch([(372, 100), (372, 100), (400, 100)], dt=0.05)               # 22 px away, under 24
    assert strokes(q) == 6
    wide = polylines(q.icon())[-1][0]
    assert wide[0] == (300.0, 100.0) and wide[-1] == (400.0, 100.0)
    assert q.errors == []
    # the Setup page carries the PanelTouch recommendation
    found = q.run('local pages = GetPages(Properties); local p = {}; for k, v in pairs(Properties) do p[k] = v end; '
                  'for i = 1, #pages do if pages[i].name == "Setup" then p.page_index = { Value = i } end end; '
                  'local _, g = GetControlLayout(p); for _, e in ipairs(g or {}) do '
                  'if type(e.Text) == "string" and e.Text:find("PanelTouch") then return true end end return false')
    assert found is True


# ------------------------------------------------------------ snapshot

def test_whiteboard_snapshot_writes_the_board_and_last_file():
    q = boot()
    q.drag([(100 + 20 * i, 100 + 10 * i) for i in range(11)], seconds=0.5)
    q.set_pin("PenColor", "White")
    q.tap(300, 300)
    assert q.pin("LastFile")["String"] == ""
    pulse(q, "Snapshot")
    files = q.list_files()
    assert len(files) == 1 and re.fullmatch(r"media/Whiteboard/\d{8}_\d{6}\.svg", files[0]), files
    assert q.pin("LastFile")["String"] == files[0]
    assert q.pin("Gesture")["String"] == "SNAPSHOT SAVED"
    data = q.read_file(files[0])
    assert data.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"') and data.endswith("</svg>")
    assert len(polylines(data)) == 1 and polylines(data)[0][0] == [(100.0, 100.0), (300.0, 200.0)]
    assert (300.0, 300.0, 2.4, "#FFFFFF") in stroke_circles(data)
    assert 'rx="18"' in data and "Draw with one finger" not in data and "M4 20l1-5" not in data
    assert all(ord(ch) < 127 for ch in data)
    assert "Saved " in q.icon()                                       # the toast
    assert q.status().startswith("OK")                                # success does not touch Status
    # a second snapshot in the same second gets its own name; a later one a new stamp
    pulse(q, "Snapshot")
    files = q.list_files()
    assert len(files) == 2 and files[1].endswith("_1.svg")
    q.advance(2)
    assert "Saved " not in q.icon()                                   # the toast is gone
    q.trigger("Snapshot")
    files = q.list_files()
    assert len(files) == 3 and not files[2].endswith("_1.svg")
    assert q.pin("LastFile")["String"] == files[2]
    # Emulate writes under design/
    e = boot(emulate=True)
    pulse(e, "Snapshot")
    assert e.list_files() and e.list_files()[0].startswith("design/Whiteboard/")


def test_whiteboard_snapshot_failure_is_reported_and_counts_nothing():
    q = boot()
    q.tap(200, 200)
    q.run("TouchPad.E.file.write = function() return nil, 'disk full' end")
    pulse(q, "Snapshot")
    assert q.list_files() == []
    assert q.pin("LastFile")["String"] == ""
    assert q.status() == "Snapshot not saved: disk full"
    assert q.pin("Gesture")["String"] == "SNAPSHOT FAILED"
    assert "Not saved" in q.icon()
    q.advance(2)
    assert "Not saved" not in q.icon()
    assert strokes(q) == 1                                            # the board is untouched
    assert q.errors == []


# ------------------------------------------------------------ caps and engine interplay

def test_whiteboard_stroke_caps_points_strokes_and_total():
    q = boot()
    # a 1000-point saw tooth keeps at most 400 points and stays one stroke
    q.touch(zigzag(1000, step=0.45), dt=0.02)
    assert strokes(q) == 1
    n = lua_points(q)
    assert 50 < n <= 400, n
    assert len(polylines(q.icon())) == 1
    assert q.status().startswith("OK")
    # the board keeps at most 2400 points: older strokes are halved
    for k in range(8):
        q.touch(zigzag(700, x0=40, y0=60 + 50 * k, step=0.6), dt=0.02)
    assert strokes(q) == 9
    total = q.run("local n = 0; for i = 1, #TouchPad.inst.strokes do n = n + #TouchPad.inst.strokes[i].pts // 2 end; return n")
    assert total <= 2400, total
    assert lua_points(q, 1) < lua_points(q), (lua_points(q, 1), lua_points(q))   # the oldest was halved
    q.advance(0.5)                                                   # the halved strokes are re-rendered lazily
    svg = q.icon()
    assert len(svg) < 45000 and "Drawing too large" not in q.status()
    assert len(polylines(svg)) == 9
    assert len(polylines(svg)[0][0]) == lua_points(q, 1)             # the rendering follows the halving
    # at most 60 strokes: the oldest is dropped
    for i in range(55):
        q.tap(30 + 7 * i, 480 - (i % 3) * 20)
    assert strokes(q) == 60
    assert q.run("return TouchPad.inst.strokes[1].dot") is False     # the saw teeth 1..4 were dropped, 5.. remain
    assert len(polylines(q.icon())) == 5 and len(stroke_circles(q.icon())) == 55
    q.tap(450, 450)
    assert strokes(q) == 60 and len(polylines(q.icon())) == 4
    b = q.budget()
    assert b["max_handler"] < 120000 and b["max_frame"] < 60000


def test_whiteboard_resume_continues_the_same_stroke():
    q = boot()
    q.touch([(100, 100), (150, 150), (200, 200)], lift=False)
    q.advance(0.5)                                            # inferred lift
    assert strokes(q) == 1 and q.pin("Touching")["Boolean"] is False
    q.touch([(210, 210), (260, 260)], lift=False)             # resumed: the same stroke goes on
    assert strokes(q) == 1 and q.pin("Touching")["Boolean"] is True
    assert polylines(q.icon())[-1][0][-1] == (260.0, 260.0)
    q.lift()
    (pts, _), = polylines(q.icon())
    assert pts[0] == (100.0, 100.0) and pts[-1] == (260.0, 260.0)
    assert strokes(q) == 1
    # a touch far from the last spot is a new stroke, and so is a touch near
    # it once the engine's own 1.5 s resume window has passed
    q.touch([(100, 400), (150, 450), (200, 480)], lift=False)
    assert strokes(q) == 2
    q.advance(0.5)
    assert strokes(q) == 2 and q.pin("Touching")["Boolean"] is False
    q.advance(2.0)
    q.touch([(205, 485), (250, 450)], lift=False)
    assert strokes(q) == 3
    q.lift()
    assert len(polylines(q.icon())) == 3


def test_whiteboard_lock_ends_the_stroke_and_keeps_it():
    q = boot()
    q.touch([(100, 100), (150, 150), (200, 200)], panel_touch=True, lift=False)
    q.set_pin("Lock", True)
    q.advance(0.05)
    svg = q.icon()
    assert "Locked" in svg and strokes(q) == 1
    assert polylines(svg)[0][0] == [(100.0, 100.0), (200.0, 200.0)]
    assert q.run("return TouchPad.inst.live == nil") is True
    q.lift()
    q.set_pin("Lock", False)
    assert "Locked" not in q.icon()
    q.touch([(300, 100), (300, 200), (300, 300)], panel_touch=True)
    assert strokes(q) == 2 and len(polylines(q.icon())) == 2


def test_whiteboard_frames_stay_within_budget_on_a_large_pad():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    for k in range(5):
        q.touch(zigzag(400, x0=60, y0=150 + 200 * k, step=3.5, amp=40), dt=0.03)
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(100)], seconds=2.0)
    q.set_pin("Eraser", True)
    q.touch([(800, 100 + 10 * i) for i in range(100)], dt=0.03)   # the eraser crosses every saw tooth
    assert strokes(q) <= 1
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000, b
    assert len(q.icon()) < 20000
