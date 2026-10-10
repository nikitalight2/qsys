# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Swipe Layer mode (11_mode_swipe.lua)
"""The Swipe Layer draws only a fading finger trail and a brief chevron in the
swipe direction, adds the Setup knob SwipeDistance (fraction of the pad
diagonal, 0.05..0.8, default 0.2), needs distance and speed (0.6 s at most)
for a swipe and does not lose a second swipe that follows the first within
0.25 s."""
import math
import os
import re

from harness import QSys, DEFAULT_PLUGIN

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
BUILD = os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-swipe.qplug")
PLUGIN = BUILD if os.path.exists(BUILD) else DEFAULT_PLUGIN   # the per-mode build when present

PINS = ("SwipeLeft", "SwipeRight", "SwipeUp", "SwipeDown")
DIAG = math.sqrt(500 ** 2 + 500 ** 2)


def boot(**kw):
    kw.setdefault("mode", "Swipe Layer")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def polylines(svg):
    """[(points, opacity)] of every <polyline> in the SVG."""
    out = []
    for m in re.finditer(r'<polyline points="([^"]*)"([^>]*)/>', svg):
        attrs = m.group(2)
        op = re.search(r'opacity="([\d.]+)"', attrs)
        out.append((m.group(1), float(op.group(1)) if op else 1.0))
    return out


def circles(svg):
    return [tuple(float(v) for v in m.groups())
            for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)"', svg)]


def swipe_pulses(q):
    return {p: q.pulses(p) for p in PINS}


def only(q, pin, n=1):
    counts = swipe_pulses(q)
    assert counts[pin] == n, counts
    assert all(v == 0 for p, v in counts.items() if p != pin), counts


# ---------------------------------------------------------------- controls and layout

def test_swipe_controls_add_swipe_distance_only():
    q = boot()
    names = q.control_names()
    assert len(names) == 27 and "SwipeDistance" in names
    k = q.pin("SwipeDistance")
    assert abs(k["Value"] - 0.2) < 1e-9
    assert q.pin("Gesture")["String"] == "SWIPE IN ANY DIRECTION"
    assert q.layout_lint(matrix=[{}, {"Pad Width": 120, "Pad Height": 120},
                                 {"Pad Width": 1600, "Pad Height": 1200},
                                 {"Background": "Transparent", "Theme": "Light"}]) == []
    q.run("return TouchPad.mode")
    assert q.run("return Modes['Swipe Layer'].id") == "swipe"


def test_swipe_setup_page_places_the_knob_and_outputs_page_lists_the_pins():
    q = boot()
    names = q.run("""
      local names = Framework.pageNames(Properties)
      return table.concat(names, ",")
    """)
    assert names == "Pad,Setup,Outputs,Display,About"
    pages = q.run("""
      local out = {}
      local names = Framework.pageNames(Properties)
      for i, page in ipairs(names) do
        Properties.page_index = { Value = i }
        local layout = GetControlLayout(Properties)
        local keys = {}
        for k in pairs(layout) do keys[#keys + 1] = k end
        table.sort(keys)
        out[#out + 1] = page .. "=" .. table.concat(keys, "/")
      end
      Properties.page_index = nil
      return table.concat(out, ";")
    """)
    pages = dict(p.split("=", 1) for p in pages.split(";"))
    assert "SwipeDistance" in pages["Setup"].split("/")
    assert "SwipeDistance" not in pages["Outputs"].split("/")
    assert all(p in pages["Outputs"].split("/") for p in PINS)
    assert "Display" in pages["Pad"].split("/") and "Gesture" in pages["Pad"].split("/")


# ---------------------------------------------------------------- drawing

def test_swipe_idle_pad_draws_nothing_but_the_hint():
    q = boot()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert "Swipe in any direction" in svg
    assert polylines(svg) == [] and circles(svg) == []
    assert svg.count("<rect") == 2                                   # the engine's pad frame only
    assert "h0.5" not in svg and "stroke-dasharray" not in svg       # no grid, no crosshair
    assert all(ord(ch) < 127 for ch in svg)
    dark = boot(props={"Show Hints": False})
    assert "Swipe in any direction" not in dark.icon()
    assert dark.pin("Gesture")["String"] == "SWIPE IN ANY DIRECTION"


def test_swipe_trail_follows_the_finger_and_fades_after_the_lift():
    q = boot()
    pts = [(100 + 20 * i, 300) for i in range(8)]
    q.drag(pts, seconds=0.35, lift=False)
    svg = q.icon()
    assert "Swipe in any direction" not in svg
    lines = polylines(svg)
    assert 1 <= len(lines) <= 8                                      # bucketed by age
    joined = " ".join(p for p, _ in lines)
    assert "240,300" in joined and "100,300" in joined               # newest and oldest points
    assert lines[-1][1] >= lines[0][1]                               # newer segments are brighter
    assert "stroke-linecap=\"round\"" in svg
    assert any(abs(cx - 240) < 1e-6 and abs(cy - 300) < 1e-6 for cx, cy, _ in circles(svg))  # the head dot
    assert "#C513E8" in svg                                          # Nikita accent
    q.lift()                                                         # 0.65 s of silence: the trail is gone
    q.advance(1.5)
    svg = q.icon()
    assert polylines(svg) == [] and circles(svg) == []
    assert "Swipe in any direction" in svg
    assert q.run("return TouchPad.state.animating") is False


def test_swipe_trail_fades_in_steps_while_the_finger_rests():
    q = boot()
    q.touch([(100, 100), (160, 100), (220, 100), (280, 100)], dt=0.05, lift=False, panel_touch=True)
    assert polylines(q.icon())
    q.advance(0.4)                                                   # the tail ages: fewer, dimmer segments
    svg = q.icon()
    assert all(op < 0.9 for _, op in polylines(svg))
    q.advance(0.5)                                                   # everything older than 0.7 s is gone
    svg = q.icon()
    assert polylines(svg) == []
    assert any(5 <= r <= 10 for _, _, r in circles(svg))             # the resting finger still shows (r = 0.9 x width)
    q.lift()


def test_swipe_chevron_points_the_way_and_disappears():
    q = boot()
    q.swipe(100, 250, 400, 250, seconds=0.2, panel_touch=True)
    svg = q.icon()
    chevrons = [p for p, _ in polylines(svg) if p.count(" ") == 2]   # three-point polylines
    assert len(chevrons) == 2, polylines(svg)
    xs = [float(pt.split(",")[0]) for pt in chevrons[-1].split(" ")]
    ys = [float(pt.split(",")[1]) for pt in chevrons[-1].split(" ")]
    assert xs[1] > xs[0] and xs[1] > xs[2] and abs(ys[0] - ys[2]) > 100 and abs(ys[1] - 250) < 1e-6
    assert "#FF8A1E" in svg                                          # drawn in the second accent
    q.advance(1.0)                                                   # 0.55 s life
    assert [p for p, _ in polylines(q.icon()) if p.count(" ") == 2] == []
    q.reset_pulses()
    q.swipe(250, 400, 250, 100, seconds=0.2, panel_touch=True)
    svg = q.icon()
    chevrons = [p for p, _ in polylines(svg) if p.count(" ") == 2]
    ys = [float(pt.split(",")[1]) for pt in chevrons[-1].split(" ")]
    assert ys[1] < ys[0] and ys[1] < ys[2]                           # tip above the tails: up
    only(q, "SwipeUp")


# ---------------------------------------------------------------- recognition

def test_swipe_four_directions_pulse_and_name_the_gesture():
    q = boot()
    cases = [((100, 250, 400, 250), "SwipeRight", "SWIPE RIGHT"), ((400, 250, 100, 250), "SwipeLeft", "SWIPE LEFT"),
             ((250, 400, 250, 100), "SwipeUp", "SWIPE UP"), ((250, 100, 250, 400), "SwipeDown", "SWIPE DOWN")]
    for (x1, y1, x2, y2), pin, text in cases:
        q.reset_pulses()
        q.swipe(x1, y1, x2, y2, seconds=0.2)
        q.advance(2.0)
        only(q, pin)
        assert q.pin("Gesture")["String"] == text
        assert q.pulses("Tap") == 0
    assert q.run("return TouchPad.inst.swipes") == 0                 # all four came from the engine


def test_swipe_needs_distance_and_speed():
    q = boot()
    q.swipe(100, 250, 400, 250, seconds=1.0, steps=10)               # 1 s: too slow
    assert sum(swipe_pulses(q).values()) == 0 and q.pin("Gesture")["String"] == "DRAG"
    q.advance(2.0)
    q.swipe(200, 250, 260, 250, seconds=0.1, steps=3)                # 60 px of 707: too short
    assert sum(swipe_pulses(q).values()) == 0
    q.advance(2.0)
    q.swipe(100, 100, 400, 400, seconds=0.2)                         # diagonal: no dominant axis
    assert sum(swipe_pulses(q).values()) == 0
    q.advance(2.0)
    q.tap(250, 250)                                                  # a tap is never a swipe
    assert sum(swipe_pulses(q).values()) == 0 and q.pulses("Tap") == 1
    q.advance(2.0)
    q.swipe(100, 250, 400, 250, seconds=0.55, steps=11)              # 0.55 s: still quick enough
    assert q.pulses("SwipeRight") == 1


def test_swipe_distance_knob_lowers_the_threshold():
    q = boot()
    q.set_pin("SwipeDistance", 0.05)                                 # 35 px of the 707 px diagonal
    assert abs(q.run("return TouchPad.inst.fraction") - 0.05) < 1e-9
    q.swipe(200, 250, 260, 250, seconds=0.1, steps=3)                # 60 px: the engine ignores it
    only(q, "SwipeRight")
    assert q.pin("Gesture")["String"] == "SWIPE RIGHT"
    assert q.run("return TouchPad.inst.swipes") == 1                 # recognised by the mode
    chevrons = [p for p, _ in polylines(q.icon()) if p.count(" ") == 2]
    assert len(chevrons) == 2
    q.advance(2.0)
    q.reset_pulses()
    q.swipe(250, 200, 250, 260, seconds=0.1, steps=3)                # 60 px down
    only(q, "SwipeDown")
    assert q.pin("Gesture")["String"] == "SWIPE DOWN"
    q.advance(2.0)
    q.reset_pulses()
    q.swipe(250, 250, 270, 250, seconds=0.1, steps=2)                # 20 px: below 0.05 x 707 too
    assert sum(swipe_pulses(q).values()) == 0
    q.advance(2.0)
    q.reset_pulses()
    q.swipe(200, 250, 260, 250, seconds=0.8, steps=8)                # 60 px but slow
    assert sum(swipe_pulses(q).values()) == 0
    q.advance(2.0)
    q.reset_pulses()
    q.set_pin("SwipeDistance", 0.2)                                  # back to the default: 60 px is short again
    q.swipe(200, 250, 260, 250, seconds=0.1, steps=3)
    assert sum(swipe_pulses(q).values()) == 0
    q.set_pin("SwipeDistance", 5.0)                                  # clamped to the knob's range
    assert abs(q.run("return TouchPad.inst.fraction") - 0.8) < 1e-9


def test_swipe_engine_and_mode_never_pulse_the_same_swipe_twice():
    q = boot()
    q.set_pin("SwipeDistance", 0.05)
    q.swipe(100, 250, 400, 250, seconds=0.2)                         # above both thresholds
    q.advance(2.0)
    only(q, "SwipeRight")
    assert q.run("return TouchPad.inst.swipes") == 0
    q.swipe(400, 250, 100, 250, seconds=0.2, lift=False)
    q.advance(0.35)                                                  # inferred lift: classified once
    assert q.pulses("SwipeLeft") == 1
    q.touch([(104, 252)], lift=False)                                # the finger settles: a resume
    q.lift()
    q.advance(2.0)
    assert q.pulses("SwipeLeft") == 1 and q.pulses("SwipeRight") == 1


def test_swipe_quick_swipes_in_a_row_each_count_with_panel_touch():
    q = boot()
    for i in range(3):
        q.swipe(100, 250, 400, 250, seconds=0.15, panel_touch=True, lift=False)
        q.set_pin("PanelTouch", False)
        q.advance(0.1)                                               # the next swipe 0.1 s after the lift
    q.advance(1.0)
    only(q, "SwipeRight", 3)
    assert q.pulses("Press") == 3 and q.pulses("Release") == 3
    q.reset_pulses()
    q.swipe(400, 250, 100, 250, seconds=0.15, panel_touch=True, lift=False)
    q.set_pin("PanelTouch", False)
    q.advance(0.2)
    q.swipe(100, 250, 400, 250, seconds=0.15, panel_touch=True)
    assert q.pulses("SwipeLeft") == 1 and q.pulses("SwipeRight") == 1


def test_swipe_second_swipe_within_the_release_time_is_not_lost():
    q = boot()                                                       # no Panel Touch: lifts are inferred
    q.swipe(100, 250, 400, 250, seconds=0.15, lift=False)
    q.advance(0.15)                                                  # the finger is off for 0.15 s < ReleaseTime
    q.swipe(100, 250, 400, 250, seconds=0.15, lift=False)            # it lands at the start again: one long touch to the engine
    q.lift()
    q.advance(2.0)
    assert q.pulses("SwipeRight") == 2, swipe_pulses(q)              # the jump split the touch into two strokes
    assert q.pulses("Press") == 1                                    # the engine saw one touch
    assert q.pin("Gesture")["String"] == "SWIPE RIGHT"
    q.reset_pulses()
    q.swipe(400, 250, 100, 250, seconds=0.15, lift=False)            # left, then back from the right: left again
    q.advance(0.1)
    q.swipe(400, 250, 100, 250, seconds=0.15, lift=False)
    q.advance(0.1)
    q.swipe(250, 400, 250, 100, seconds=0.15, lift=False)            # and an up to finish
    q.lift()
    q.advance(2.0)
    counts = swipe_pulses(q)
    assert counts["SwipeLeft"] == 2 and counts["SwipeUp"] == 1 and counts["SwipeRight"] == 0, counts
    assert q.run("return TouchPad.inst.swipes") >= 3


def test_swipe_pin_written_by_a_script_shows_the_chevron_without_pulsing():
    q = boot()
    q.set_pin("SwipeDown", True)
    q.set_pin("SwipeDown", False)
    q.advance(0.06)
    svg = q.icon()
    chevrons = [p for p, _ in polylines(svg) if p.count(" ") == 2]
    assert len(chevrons) == 2
    ys = [float(pt.split(",")[1]) for pt in chevrons[-1].split(" ")]
    assert ys[1] > ys[0] and ys[1] > ys[2]                           # tip below the tails: down
    assert q.pulses("SwipeDown") == 1 and q.run("return TouchPad.inst.swipes") == 0
    q.advance(1.0)
    assert [p for p, _ in polylines(q.icon()) if p.count(" ") == 2] == []


def test_swipe_lock_clears_the_trail_and_chevron():
    q = boot()
    q.drag([(100, 100), (150, 150), (200, 200), (250, 250)], seconds=0.2, lift=False, panel_touch=True)
    assert polylines(q.icon())
    q.set_pin("Lock", True)
    q.advance(0.05)
    svg = q.icon()
    assert "Locked" in svg and polylines(svg) == [] and circles(svg) == []
    q.lift()
    q.set_pin("Lock", False)
    q.advance(0.05)
    assert "Locked" not in q.icon()
    assert sum(swipe_pulses(q).values()) == 0
    q.swipe(100, 250, 400, 250, seconds=0.2, panel_touch=True)       # the pad works again
    only(q, "SwipeRight")


def test_swipe_themes_and_sizes():
    light = boot(props={"Theme": "Light"})
    light.swipe(100, 250, 400, 250, seconds=0.2, panel_touch=True)
    svg = light.icon()
    assert "#2F6FEB" in svg or "#1DA27A" in svg
    assert "#C513E8" not in svg
    small = boot(props={"Pad Width": 120, "Pad Height": 120})
    small.swipe(10, 60, 110, 60, seconds=0.2, panel_touch=True)       # 100 px of a 170 px diagonal
    assert small.pulses("SwipeRight") == 1
    assert 'viewBox="0 0 120 120"' in small.icon()
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300, "Background": "Transparent"})
    wide.swipe(200, 150, 1400, 150, seconds=0.2, panel_touch=True)
    assert wide.pulses("SwipeRight") == 1
    assert len(wide.icon()) < 4000


def test_swipe_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(120)], seconds=2.4, lift=False)
    assert len(q.icon()) < 6000
    q.lift()
    q.advance(1.0)
    for _ in range(6):
        q.swipe(100, 600, 1500, 600, seconds=0.15, panel_touch=False, lift=False)
        q.advance(0.1)
    q.lift()
    q.advance(2.0)
    assert q.pulses("SwipeRight") >= 5
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 30000 and b["max_handler"] < 40000, (b["max_frame"], b["max_handler"])
