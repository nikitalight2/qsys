# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Zone Select mode (20_mode_zones.lua)
"""Zone Select: tap toggles a zone, a drag from a zone paints, a closed lasso on
empty space selects the enclosed centres, long press solos, double tap on
empty space clears; Exclusive is a radio group; Edit mode moves, resizes and
redraws zones and writes ZoneLayout; SelectedList names the selection.

Default grid for a 500 x 500 pad with 8 zones in 4 columns (pad px, y down):
zone 1 x 15..125, zone 2 x 135..245, zone 3 x 255..365, zone 4 x 375..485,
row 1 y 15..235, row 2 (zones 5..8) y 245..465; gaps are 10 px wide and the
hint strip below y 465 is empty space.
"""
import json
import os

from harness import QSys, DEFAULT_PLUGIN

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
MODE_BUILD = os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-zones.qplug")


def plugin_path():
    """$TOUCHPAD_PLUGIN when set, else the newest of the full build and the
    per-mode build that contains the Zone Select mode."""
    env = os.environ.get("TOUCHPAD_PLUGIN")
    if env and os.path.exists(env):
        return env
    found = []
    for path in (DEFAULT_PLUGIN, MODE_BUILD):
        if os.path.exists(path):
            with open(path, "rb") as fh:
                if b'Modes["Zone Select"]' in fh.read():
                    found.append((os.path.getmtime(path), path))
    if found:
        return max(found)[1]
    return DEFAULT_PLUGIN


def boot(**kw):
    kw.setdefault("mode", "Zone Select")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", plugin_path())
    q = QSys(**kw)
    q.advance(0.2)
    return q


def selected(q, n=8):
    return [i for i in range(1, n + 1) if q.pin("ZoneSelected", i)["Boolean"]]


def zone(q, i):
    return q.run("local z = TouchPad.inst.zones[%d]; return z.x, z.y, z.w, z.h" % i)


def centre(q, i):
    x, y, w, h = zone(q, i)
    return ((x + w / 2) * 500, (y + h / 2) * 500)


def ring(cx, cy, rx, ry, n=16):
    """A closed path around (cx, cy): n points, the last one on the first."""
    import math
    pts = []
    for k in range(n + 1):
        a = 2 * math.pi * k / n
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return pts


def test_zones_controls_pins_and_defaults():
    q = boot()
    names = q.control_names()
    assert len(names) == 50
    for i in range(1, 9):
        assert "ZoneName %d" % i in names and "ZoneSelected %d" % i in names
    for n in ("SelectAll", "ClearAll", "SelectedList", "Edit", "ShowBackground", "ZoneLayout", "Exclusive", "Columns"):
        assert n in names
    pins = dict(q.run('local t = {}; for _, c in ipairs(GetControls(Properties)) do t[c.Name] = (c.PinStyle or "none") .. "/" .. tostring(c.Count) end; return t'))
    assert pins["ZoneSelected"] == "Both/8" and pins["ZoneName"] == "Input/8"
    assert pins["SelectedList"] == "Output/1" and pins["ZoneLayout"] == "Both/1"
    assert pins["SelectAll"] == "Input/1" and pins["Columns"] == "Input/1"
    assert q.pin("ShowBackground")["Boolean"] is True
    assert q.pin("Columns")["Value"] == 4
    assert q.pin("SelectedList")["String"] == ""
    assert q.pin("Gesture")["String"] == "TAP, DRAG OR CIRCLE ZONES"
    assert q.status().startswith("OK")
    twelve = boot(props={"Zones": 12})
    assert "ZoneSelected 12" in twelve.control_names() and "ZoneSelected 13" not in twelve.control_names()


def test_zones_default_grid_and_drawing():
    q = boot()
    x, y, w, h = zone(q, 1)
    assert abs(x - 0.03) < 1e-9 and abs(y - 0.03) < 1e-9 and abs(w - 0.22) < 1e-9 and abs(h - 0.44) < 1e-9
    x5, y5 = zone(q, 5)[:2]
    assert abs(x5 - 0.03) < 1e-9 and abs(y5 - 0.49) < 1e-9       # second row
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    for i in range(1, 9):
        assert "Zone %d" % i in svg
    assert "h0.5" in svg                                             # the dotted background grid
    assert "Tap, drag or circle zones" in svg
    assert all(ord(ch) < 127 for ch in svg)
    assert svg.count('rx="10"') >= 8                                 # eight tiles


def test_zones_tap_toggles_and_lists():
    q = boot()
    q.tap(*centre(q, 1))
    assert selected(q) == [1]
    assert q.pin("SelectedList")["String"] == "Zone 1"
    assert q.pin("Gesture")["String"] == "ZONE 1 ON"
    assert q.pulses("Tap") == 1
    q.tap(*centre(q, 3))
    assert selected(q) == [1, 3] and q.pin("SelectedList")["String"] == "Zone 1, Zone 3"
    q.tap(*centre(q, 1))
    assert selected(q) == [3] and q.pin("Gesture")["String"] == "ZONE 1 OFF"
    q.tap(130, 480)                                                  # empty space: nothing
    assert selected(q) == [3] and q.pulses("Tap") == 4


def test_zones_names_feed_list_and_drawing():
    q = boot()
    q.set_pin("ZoneName", "Stage", 1)
    q.set_pin("ZoneName", "  Bar  ", 2)
    q.advance(0.05)                                                  # the frame cap: one frame per 1/20 s
    svg = q.icon()
    assert "Stage" in svg and "Bar" in svg and "Zone 1" not in svg
    q.tap(*centre(q, 2))
    q.tap(*centre(q, 1))
    assert q.pin("SelectedList")["String"] == "Stage, Bar"
    assert q.pin("Gesture")["String"] == "STAGE ON"
    q.set_pin("ZoneName", "Caf\u00e9", 1)                            # non-ASCII stays out of the SVG
    q.advance(0.05)
    svg = q.icon()
    assert "Caf&#233;" in svg and all(ord(ch) < 127 for ch in svg)
    assert q.pin("SelectedList")["String"] == "Caf\u00e9, Bar"


def test_zones_drag_paints_the_opposite_of_the_start_zone():
    q = boot()
    q.set_pin("ZoneSelected", True, 2)
    # from zone 1 (off) across zones 2 and 3: paints ON
    q.drag([(70 + 25 * i, 125) for i in range(11)], seconds=0.8)    # 70 -> 320
    assert selected(q) == [1, 2, 3]
    assert q.pin("Gesture")["String"] == "PAINTED 2 ON"              # zone 2 was already on
    assert q.pulses("Tap") == 0
    q.advance(1.6)                                                   # past the resume window (spec 5.3)
    # from zone 3 (on) back across zone 2: paints OFF, zone 1 untouched
    q.drag([(310 - 20 * i, 125) for i in range(7)], seconds=0.6)    # 310 -> 190
    assert selected(q) == [1]
    assert q.pin("Gesture")["String"] == "PAINTED 2 OFF"
    q.advance(1.6)
    # a short wobble on a zone is a tap, not a paint
    q.touch([(70, 400), (74, 403), (70, 400)], dt=0.05)
    assert selected(q) == [1, 5] and q.pulses("Tap") == 1


def test_zones_drag_crossing_fast_still_paints_every_zone():
    q = boot()
    q.drag([(70, 125), (440, 125)], seconds=0.1)                     # one jump across the row
    assert selected(q) == [1, 2, 3, 4]


def test_zones_lasso_selects_enclosed_centres_after_the_inferred_lift():
    q = boot()
    # around zones 1 and 2 through the margins and gaps (start on empty space)
    pts = [(130, 7), (190, 7), (250, 7), (250, 120), (250, 240), (130, 240), (7, 240), (7, 120), (7, 7), (70, 7), (126, 8)]
    q.drag(pts, seconds=1.0)
    assert selected(q) == []                                         # the inferred lift may be taken back
    assert 'stroke-dasharray="6 5"' in q.icon()                      # the pending trail is dashed
    q.advance(1.6)
    assert selected(q) == [1, 2]
    assert q.pin("Gesture")["String"] == "LASSO: 2 ZONES"
    assert q.pin("SelectedList")["String"] == "Zone 1, Zone 2"
    assert "stroke-dasharray" not in q.icon().split("</g>")[-1] or 'stroke-dasharray="6 5"' not in q.icon()


def test_zones_lasso_commits_at_once_with_panel_touch():
    q = boot()
    q.drag(ring(250, 240, 240, 230), seconds=1.2, panel_touch=True)  # around every zone but through nothing closed
    assert selected(q) == [1, 2, 3, 4, 5, 6, 7, 8]
    assert q.pin("Gesture")["String"] == "LASSO: 8 ZONES"
    q.set_pin("ClearAll", True)
    q.set_pin("ClearAll", False)
    # a lasso around the right column only
    q.drag(ring(430, 240, 60, 232, n=20), seconds=1.0, panel_touch=True)
    assert selected(q) == [4, 8]


def test_zones_lasso_rejects_open_small_or_short_paths():
    q = boot()
    # open path: an L from empty space, far from closed
    q.drag([(7, 7), (7, 120), (7, 240), (130, 240), (250, 240), (250, 120)], seconds=0.8)
    q.advance(1.6)
    assert selected(q) == []
    # closed but tiny (well under 2 % of the pad)
    q.drag(ring(130, 480, 14, 12, n=10), seconds=0.6)
    q.advance(1.6)
    assert selected(q) == []
    # closed with enough area but fewer than 6 points kept
    q.drag([(7, 7), (250, 7), (250, 240), (7, 240), (7, 8)], seconds=0.5)
    q.advance(1.6)
    assert selected(q) == []
    assert q.pin("Gesture")["String"] != "LASSO: 2 ZONES"


def test_zones_lasso_resume_keeps_one_path():
    q = boot()
    half = [(130, 7), (190, 7), (250, 7), (250, 120), (250, 240), (130, 240)]
    q.touch(half, dt=0.1, lift=False)
    q.advance(0.5)                                                   # inferred lift: commit pending
    assert q.pulses("Release") == 1 and selected(q) == []
    rest = [(126, 236), (7, 240), (7, 120), (7, 7), (70, 7), (126, 8)]
    q.touch(rest, dt=0.1)                                            # resumed: the same lasso goes on
    q.advance(1.6)
    assert selected(q) == [1, 2]
    assert q.pin("Gesture")["String"] == "LASSO: 2 ZONES"
    assert q.pulses("Release") == 1                                  # a resumed touch is one touch


def test_zones_new_touch_commits_a_pending_lasso():
    q = boot()
    q.drag([(130, 7), (250, 7), (250, 120), (250, 240), (130, 240), (7, 240), (7, 120), (7, 7), (70, 7), (126, 8)], seconds=1.0)
    assert selected(q) == []
    q.tap(*centre(q, 4))                                             # far from the lift: a new touch
    assert selected(q) == [1, 2, 4]


def test_zones_long_press_solos_and_double_tap_on_empty_clears():
    q = boot()
    q.set_pin("ZoneSelected", True, 1)
    q.set_pin("ZoneSelected", True, 2)
    q.long_press(*centre(q, 3), seconds=1.0, panel_touch=True)
    assert selected(q) == [3]
    assert q.pin("Gesture")["String"] == "SOLO ZONE 3"
    assert q.pulses("LongPress") == 1
    q.set_pin("ZoneSelected", True, 6)
    q.double_tap(130, 480, gap=0.15, panel_touch=True)              # empty space below the grid
    assert selected(q) == []
    assert q.pin("Gesture")["String"] == "DOUBLE TAP: ALL CLEARED"
    assert q.pulses("DoubleTap") == 1
    # a double tap on a zone toggles it once (not twice)
    q.double_tap(*centre(q, 5), gap=0.15, panel_touch=True)
    assert selected(q) == [5]


def test_zones_exclusive_is_a_radio_group():
    q = boot()
    q.set_pin("ZoneSelected", True, 2)
    q.set_pin("ZoneSelected", True, 5)
    q.set_pin("Exclusive", True)
    assert selected(q) == [2]                                        # the first selected zone survives
    q.tap(*centre(q, 3), panel_touch=True)
    assert selected(q) == [3]
    q.set_pin("ZoneSelected", True, 7)                               # an input pin obeys it too
    assert selected(q) == [7] and q.pin("SelectedList")["String"] == "Zone 7"
    q.set_pin("SelectAll", True)
    q.set_pin("SelectAll", False)
    assert selected(q) == [7] and "EXCLUSIVE" in q.pin("Gesture")["String"]
    q.drag([(70 + 25 * i, 125) for i in range(11)], seconds=0.8, panel_touch=True)   # the zone under the finger
    assert selected(q) == [3]
    q.drag(ring(250, 240, 240, 230), seconds=1.0, panel_touch=True)  # lasso: the first enclosed zone only
    assert selected(q) == [1]
    q.tap(*centre(q, 1), panel_touch=True)                           # tapping the selected zone clears it
    assert selected(q) == []
    q.set_pin("Exclusive", False)
    q.set_pin("SelectAll", True)
    assert selected(q) == [1, 2, 3, 4, 5, 6, 7, 8]


def test_zones_select_all_clear_all_and_input_pins():
    q = boot()
    q.set_pin("SelectAll", True)
    q.set_pin("SelectAll", False)
    assert selected(q) == list(range(1, 9))
    assert q.pin("SelectedList")["String"] == ", ".join("Zone %d" % i for i in range(1, 9))
    assert q.pin("Gesture")["String"] == "ALL SELECTED"
    q.advance(0.2)                                                   # tiles re-render six per frame
    svg = q.icon()
    assert svg.count('fill="#C513E8"') >= 8                          # eight accent-filled tiles
    q.set_pin("ClearAll", True)
    q.set_pin("ClearAll", False)
    assert selected(q) == [] and q.pin("SelectedList")["String"] == ""
    assert q.pin("Gesture")["String"] == "ALL CLEARED"
    q.set_pin("ZoneSelected", True, 4)
    assert q.pin("SelectedList")["String"] == "Zone 4"
    q.advance(0.3)                                                   # the frame cap and the 0.2 s echo window
    assert q.icon().count('fill="#C513E8"') >= 1
    q.set_pin("ZoneSelected", False, 4)
    assert q.pin("SelectedList")["String"] == ""


def test_zones_layout_json_moves_the_zones():
    q = boot(props={"Zones": 2})
    layout = [{"x": 0.5, "y": 0.5, "w": 0.4, "h": 0.4}, {"x": 0.0, "y": 0.0, "w": 0.2, "h": 0.2}]
    q.set_pin("ZoneLayout", json.dumps(layout))
    assert zone(q, 1) == (0.5, 0.5, 0.4, 0.4) and zone(q, 2) == (0.0, 0.0, 0.2, 0.2)
    q.tap(350, 350)
    assert selected(q, 2) == [1]
    q.tap(50, 50)
    assert selected(q, 2) == [1, 2]
    # out-of-range values are clamped, a short list keeps the grid for the rest
    q.set_pin("ZoneLayout", json.dumps([{"x": 0.9, "y": -1, "w": 0.5, "h": 5}]))
    assert zone(q, 1) == (0.5, 0.0, 0.5, 1.0)
    assert abs(zone(q, 2)[0] - 0.51) < 1e-9                          # grid cell 2 of 2 columns
    # bad JSON keeps the layout and warns
    q.set_pin("ZoneLayout", "{not json")
    assert zone(q, 1) == (0.5, 0.0, 0.5, 1.0)
    assert q.status().startswith("Zone Layout")
    # blank returns to the grid
    q.set_pin("ZoneLayout", "")
    assert abs(zone(q, 1)[0] - 0.03) < 1e-9


def test_zones_columns_rebuild_the_default_grid():
    q = boot()
    q.set_pin("Columns", 2)
    x3, y3 = zone(q, 3)[:2]
    assert abs(x3 - 0.03) < 1e-9 and y3 > 0.2                       # zone 3 starts the second row
    assert abs(zone(q, 1)[2] - 0.46) < 1e-9                          # (1 - 0.06 - 0.02) / 2
    q.set_pin("ZoneLayout", json.dumps([{"x": 0.1, "y": 0.1, "w": 0.3, "h": 0.3}]))
    q.set_pin("Columns", 8)
    assert zone(q, 1) == (0.1, 0.1, 0.3, 0.3)                        # a custom layout wins
    one = boot(props={"Zones": 1})
    assert abs(one.zone(1)[2] - 0.94) < 1e-9 if hasattr(one, "zone") else abs(zone(one, 1)[2] - 0.94) < 1e-9


def test_zones_edit_mode_moves_resizes_and_redraws():
    q = boot()
    q.set_pin("Edit", True)
    assert q.pin("Gesture")["String"] == "EDIT ON" and "EDIT" in q.icon()
    # move zone 1 by (+100, +50) px
    q.drag([(70 + 10 * i, 125 + 5 * i) for i in range(11)], seconds=0.6, panel_touch=True)
    x, y, w, h = zone(q, 1)
    assert abs(x - 0.23) < 1e-6 and abs(y - 0.13) < 1e-6 and abs(w - 0.22) < 1e-6
    assert q.pin("Gesture")["String"] == "MOVED ZONE 1"
    assert selected(q) == []                                         # editing never selects
    layout = json.loads(q.pin("ZoneLayout")["String"])
    assert len(layout) == 8 and abs(layout[0]["x"] - 0.23) < 1e-6 and layout[1]["x"] == 0.27
    # resize zone 1 from its bottom-right corner (now at 225, 285): drag by (+50, +25)
    q.drag([(220 + 5 * i, 280 + 2.5 * i) for i in range(11)], seconds=0.6, panel_touch=True)
    x, y, w, h = zone(q, 1)
    assert abs(w - 0.32) < 1e-6 and abs(h - 0.49) < 1e-6 and abs(x - 0.23) < 1e-6
    assert q.pin("Gesture")["String"] == "RESIZED ZONE 1"
    # redraw the last touched zone (1) from empty space: the strip below the grid
    q.drag([(10 + 20 * i, 470 + 2 * i) for i in range(11)], seconds=0.6, panel_touch=True)
    x, y, w, h = zone(q, 1)
    assert abs(x - 0.02) < 1e-6 and abs(y - 0.94) < 1e-6 and abs(w - 0.4) < 1e-6 and abs(h - 0.04) < 1e-6
    assert q.pin("Gesture")["String"] == "REDREW ZONE 1"
    # tapping zone 3 picks it as the edit target
    q.tap(*centre(q, 3), panel_touch=True)
    assert q.pin("Gesture")["String"] == "ZONE 3 PICKED" and selected(q) == []
    q.drag([(300 + 15 * i, 470 + 2 * i) for i in range(11)], seconds=0.6, panel_touch=True)   # empty strip, right of zone 1
    assert abs(zone(q, 3)[0] - 0.6) < 1e-6 and abs(zone(q, 3)[1] - 0.94) < 1e-6
    assert q.pin("Gesture")["String"] == "REDREW ZONE 3"
    # off: prints the layout, keeps it in force
    q.set_pin("Edit", False)
    assert q.pin("Gesture")["String"] == "EDIT OFF"
    assert any(line.startswith("Zone layout: [") for line in q.output())
    assert json.loads(q.pin("ZoneLayout")["String"])[2]["y"] == 0.94
    q.tap(*centre(q, 2), panel_touch=True)
    assert selected(q) == [2]


def test_zones_edit_mode_times_out_after_five_minutes():
    q = boot()
    q.set_pin("Edit", True)
    q.advance(200)
    q.drag([(70 + 10 * i, 125) for i in range(6)], seconds=0.5, panel_touch=True)   # touched: the clock restarts
    q.advance(200)
    assert q.pin("Edit")["Boolean"] is True and "EDIT" in q.icon()
    q.advance(101)
    assert q.pin("Edit")["Boolean"] is False
    assert q.pin("Gesture")["String"] == "EDIT OFF: 5 MIN UNTOUCHED"
    assert any(line.startswith("Zone layout: [") for line in q.output())
    assert "EDIT" not in q.icon()
    # untouched edit mode leaves ZoneLayout blank (the grid stays in force)
    q.set_pin("Edit", True)
    q.advance(301)
    assert q.pin("Edit")["Boolean"] is False and q.pin("ZoneLayout")["String"] != ""


def test_zones_show_background_and_hints_off():
    q = boot()
    assert "h0.5" in q.icon()
    q.set_pin("ShowBackground", False)
    assert "h0.5" not in q.icon() and "Zone 1" in q.icon()
    quiet = boot(props={"Show Hints": False})
    assert "Tap, drag" not in quiet.icon()
    assert abs(zone(quiet, 1)[3] - 0.46) < 1e-9                      # no hint strip reserved


def test_zones_lock_drops_the_drag_and_pending_lasso():
    q = boot()
    q.drag([(130, 7), (250, 7), (250, 120), (250, 240), (130, 240), (7, 240), (7, 120), (7, 7), (70, 7), (126, 8)], seconds=1.0)
    q.set_pin("Lock", True)
    q.advance(2)
    assert selected(q) == []                                         # the pending lasso was dropped
    assert "Locked" in q.icon()
    q.set_pin("Lock", False)
    q.touch([(70, 125), (120, 125), (170, 125)], dt=0.1, lift=False)
    q.set_pin("Lock", True)
    q.advance(0.05)
    assert q.run("return TouchPad.inst.touch") is None
    q.lift()
    q.set_pin("Lock", False)
    assert selected(q) == [1, 2]                                     # painted before the lock, kept


def test_zones_resumed_paint_goes_on():
    q = boot()
    q.touch([(70, 125), (120, 125), (190, 125)], dt=0.1, lift=False)
    q.advance(0.5)                                                   # inferred lift
    assert selected(q) == [1, 2]
    q.touch([(200, 125), (260, 125), (320, 125)], dt=0.1)            # resumed near the lift spot
    assert selected(q) == [1, 2, 3]
    assert q.pin("Gesture")["String"] == "PAINTED 3 ON"


def test_zones_layout_pages_and_lint():
    q = boot()
    assert q.layout_lint(matrix=[{}, {"Zones": 32}, {"Zones": 1}, {"Pad Width": 1600, "Pad Height": 1200}]) == []
    pages = q.run("local t = {}; for _, p in ipairs(GetPages(Properties)) do t[#t + 1] = p.name end; return table.concat(t, ',')")
    assert pages == "Pad,Setup,Names,Outputs,Display,About"


def test_zones_thirty_two_zones_stay_within_budget():
    q = boot(props={"Zones": 32, "Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    for i in range(1, 33):
        q.set_pin("ZoneName", "Meeting room number %d on the east wing" % i, i)
    q.advance(0.2)                                                   # tiles re-render ten per frame
    svg = q.icon()
    assert len(svg) < 40000 and all("Meeting room number %d" % i in svg for i in range(1, 33))
    q.drag([(100 + 15 * i, 60 + 11 * i) for i in range(100)], seconds=2.0)  # from zone 1 down a diagonal
    assert len(selected(q, 32)) >= 8
    q.set_pin("SelectAll", True)
    q.set_pin("SelectAll", False)
    q.advance(0.2)
    assert q.icon().count('fill="#C513E8"') >= 32                    # every tile caught up
    # a 200-point lasso along the margins (a rectangle: an ellipse misses the corner centres)
    box = [(20 + 1560 * k / 50, 20) for k in range(50)] + [(1580, 20 + 1160 * k / 50) for k in range(50)] \
        + [(1580 - 1560 * k / 50, 1180) for k in range(50)] + [(20, 1180 - 1160 * k / 50) for k in range(50)] + [(20, 24)]
    q.drag(box, seconds=3.0, panel_touch=True)
    assert q.pin("Gesture")["String"] == "LASSO: 32 ZONES"
    q.set_pin("Edit", True)
    q.drag([(100 + 20 * i, 60 + 10 * i) for i in range(30)], seconds=1.0, panel_touch=True)
    q.set_pin("Edit", False)
    assert len(json.loads(q.pin("ZoneLayout")["String"])) == 32
    b = q.budget()
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 40000


def test_zones_double_tap_needs_both_taps_on_the_same_target():
    q = boot()
    q.set_pin("ZoneSelected", True, 5)
    q.set_pin("ZoneSelected", True, 7)
    # a tap on zone 1 and a mis-landed second tap in the gap (the engine pairs
    # taps within 40 px): zone 1 toggles, nothing clears
    q.touch([(120, 125)], panel_touch=True, silence=0.15)
    q.touch([(130, 125)], panel_touch=True)
    assert selected(q) == [1, 5, 7] and q.pulses("DoubleTap") == 1
    assert q.pin("Gesture")["String"] != "DOUBLE TAP: ALL CLEARED"
    # zone 1 then the margin
    q.touch([(20, 125)], panel_touch=True, silence=0.15)
    q.touch([(10, 125)], panel_touch=True)
    assert selected(q) == [5, 7]
    # two quick taps on adjacent zones each stand
    q.touch([(120, 125)], panel_touch=True, silence=0.15)
    q.touch([(140, 125)], panel_touch=True)
    assert selected(q) == [1, 2, 5, 7] and q.pulses("DoubleTap") == 3
    # empty space then a zone: the zone toggles, nothing clears
    q.touch([(130, 480)], panel_touch=True, silence=0.15)
    q.touch([(140, 455)], panel_touch=True)
    assert selected(q) == [1, 2, 5, 6, 7]
    # both taps on empty space clear; both on one zone toggle it once
    q.double_tap(130, 480, gap=0.15, panel_touch=True)
    assert selected(q) == [] and q.pin("Gesture")["String"] == "DOUBLE TAP: ALL CLEARED"
    q.double_tap(*centre(q, 3), gap=0.15, panel_touch=True)
    assert selected(q) == [3]
    # a third tap right after a double starts afresh (no chained double)
    q.touch([(130, 480)], panel_touch=True, silence=0.15)
    assert selected(q) == [3]


def test_zones_long_press_solo_survives_a_drift():
    q = boot()
    q.set_pin("ZoneSelected", True, 1)
    q.set_pin("ZoneSelected", True, 2)
    cx, cy = centre(q, 3)
    q.touch([(cx, cy)] * 6 + [(cx + 8, cy), (cx + 16, cy), (cx + 24, cy)], dt=0.15, panel_touch=True)
    assert q.pulses("LongPress") == 1
    assert selected(q) == [3]                                        # the solo stands
    assert "PAINTED" not in q.pin("Gesture")["String"]
    assert q.pin("SelectedList")["String"] == "Zone 3"


def test_zones_triggers_debounce_each_their_own_edge():
    q = boot()
    q.trigger("SelectAll")                                           # Trigger() runs with Boolean false
    assert selected(q) == list(range(1, 9))
    q.advance(0.3)
    q.trigger("ClearAll")                                            # a different trigger 0.3 s later acts
    assert selected(q) == [] and q.pin("Gesture")["String"] == "ALL CLEARED"
    q.advance(0.3)
    q.trigger("SelectAll")
    assert selected(q) == list(range(1, 9))
    q.set_pin("ClearAll", True)
    q.set_pin("ClearAll", False)
    assert selected(q) == []
    q.advance(0.6)
    q.trigger("SelectAll")                                           # 0.6 s after its own last action
    assert selected(q) == list(range(1, 9))
    # the same trigger again within 0.5 s is its own trailing edge: no second action
    q.set_pin("ZoneSelected", False, 1)
    q.advance(0.2)
    q.trigger("SelectAll")
    assert selected(q) == list(range(2, 9))
    q.trigger("ClearAll")                                            # the other one still acts
    assert selected(q) == []
    q.advance(0.6)
    q.trigger("SelectAll")
    assert selected(q) == list(range(1, 9))


def test_zones_thirty_two_zone_lasso_with_inferred_lift_stays_within_budget():
    q = boot(props={"Zones": 32})
    n = 60
    box = [(7 + 486 * k / n, 7) for k in range(n)] + [(493, 7 + 486 * k / n) for k in range(n)] \
        + [(493 - 486 * k / n, 493) for k in range(n)] + [(7, 493 - 486 * k / n) for k in range(n)] + [(7, 11)]
    q.drag(box, seconds=2.4)                                         # no PanelTouch: the lift is inferred
    assert selected(q, 32) == []
    q.advance(1.6)                                                   # the commit runs in the retract timer
    assert selected(q, 32) == list(range(1, 33))
    assert q.pin("Gesture")["String"] == "LASSO: 32 ZONES"
    q.advance(0.4)                                                   # the tiles catch up, six per frame
    assert q.icon().count('fill="#C513E8"') >= 32
    assert "stroke-dasharray" not in q.icon()
    b = q.budget()                                                   # raises above either budget
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert b["handlers"]["callafter"] < 60000                        # the commit itself, redraw apart
    # a lasso around the right column only, on a free layout (one edge walk per zone)
    q.set_pin("ClearAll", True)
    q.set_pin("ClearAll", False)
    q.set_pin("ZoneLayout", json.dumps([{"x": 0.1 + 0.025 * i, "y": 0.02 + 0.029 * i, "w": 0.05, "h": 0.05} for i in range(32)]))
    q.drag(box, seconds=2.4)
    q.advance(1.6)
    assert selected(q, 32) == list(range(1, 33))
    b = q.budget()
    assert b["max_frame"] < 60000 and b["handlers"]["callafter"] < 60000


def test_zones_aborted_edit_drag_restores_the_zone():
    q = boot()
    q.set_pin("Edit", True)
    q.touch([(70 + 10 * i, 125 + 5 * i) for i in range(8)], dt=0.08, panel_touch=True, lift=False)
    assert abs(zone(q, 1)[0] - 0.17) < 1e-6                          # mid-drag
    q.set_pin("Lock", True)                                          # aborts the touch
    q.lift()
    q.set_pin("Lock", False)
    x, y, w, h = zone(q, 1)
    assert abs(x - 0.03) < 1e-9 and abs(y - 0.03) < 1e-9 and abs(w - 0.22) < 1e-9
    assert q.pin("ZoneLayout")["String"] == ""
    assert q.run("return TouchPad.inst.custom") is False
    assert "Zone 1" in q.icon()
    q.set_pin("Edit", False)
    assert q.pin("ZoneLayout")["String"] == ""                       # nothing changed: nothing written
    q.set_pin("Columns", 2)
    assert abs(zone(q, 1)[2] - 0.46) < 1e-9                          # the grid still applies


def test_zones_edit_on_commits_a_pending_lasso_first():
    q = boot()
    q.drag([(130, 7), (250, 7), (250, 120), (250, 240), (130, 240), (7, 240), (7, 120), (7, 7), (70, 7), (126, 8)], seconds=1.0)
    assert selected(q) == [] and q.run("return TouchPad.inst.pending ~= nil") is True
    q.set_pin("Edit", True)
    assert selected(q) == [1, 2]                                     # landed before the switch
    assert q.pin("Gesture")["String"] == "EDIT ON"
    assert q.run("return TouchPad.inst.pending") is None
    assert 'stroke-dasharray="6 5"' not in q.icon()
    q.advance(1.6)
    assert selected(q) == [1, 2] and q.pin("Gesture")["String"] == "EDIT ON"
    q.tap(*centre(q, 4), panel_touch=True)                           # editing never selects
    assert selected(q) == [1, 2] and q.pin("Gesture")["String"] == "ZONE 4 PICKED"


def test_zones_layout_warning_clears_and_wrong_shapes_warn():
    q = boot(props={"Zones": 2})
    ok = q.status()
    assert ok.startswith("OK")
    q.set_pin("ZoneLayout", "{not json")
    assert q.status().startswith("Zone Layout") and q.pin("Status")["Value"] == 1
    q.set_pin("ZoneLayout", json.dumps([{"x": 0.1, "y": 0.1, "w": 0.3, "h": 0.3}]))
    assert q.status() == ok and q.pin("Status")["Value"] == 0          # the warning is gone
    assert zone(q, 1) == (0.1, 0.1, 0.3, 0.3)
    # valid JSON of the wrong shape warns too and leaves the zones alone
    for text in ('{"x":0.5,"y":0.5,"w":0.4,"h":0.4}', "[[0.5,0.5,0.4,0.4]]", "[1,2]", "[{}]", '"text"'):
        q.set_pin("ZoneLayout", text)
        assert q.status().startswith("Zone Layout"), text
        assert zone(q, 1) == (0.1, 0.1, 0.3, 0.3) and q.run("return TouchPad.inst.custom") is True
    q.set_pin("ZoneLayout", "")
    assert q.status() == ok and abs(zone(q, 1)[0] - 0.03) < 1e-9
    q.set_pin("ZoneLayout", "{not json")
    assert q.status().startswith("Zone Layout")
    q.set_pin("ZoneLayout", "[]")                                    # an empty list is the grid, not a mistake
    assert q.status() == ok and abs(zone(q, 1)[0] - 0.03) < 1e-9
    assert q.run("return TouchPad.inst.custom") is False
