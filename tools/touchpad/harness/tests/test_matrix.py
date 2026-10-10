# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Matrix mode (22_mode_matrix.lua)
"""A crosspoint grid, sources as rows and destinations as columns. A tap
toggles a crosspoint, a drag paints across crosspoints, a row header sends
that source to every column, a column header clears the column. Cross n
(index (r - 1) * cols + c) and Route n (per column) are pins both ways and
stay in sync while ExclusiveColumns is on; ClearAll clears everything. The
grid pages at 12 x 12 with arrow bars; Clear All on a large matrix spreads
its pin writes over several engine turns."""
import os

from harness import QSys

MODE = "Matrix"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))


def find_plugin():
    """The first plugin that defines the mode: $TOUCHPAD_PLUGIN, the per-mode
    build, then the full plugin."""
    candidates = [os.environ.get("TOUCHPAD_PLUGIN", ""),
                  os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-matrix.qplug"),
                  os.path.join(REPO, "plugins", "NikitaTouchPad.qplug")]
    for path in candidates:
        if path and os.path.exists(path):
            with open(path, "rb") as fh:
                if b'Modes["Matrix"]' in fh.read():
                    return path
    return candidates[-1]


PLUGIN = find_plugin()


def boot(sources=4, dests=3, props=None, **kw):
    p = {"Sources": sources, "Destinations": dests}
    if props:
        p.update(props)
    kw.setdefault("mode", MODE)
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(props=p, **kw)
    if sources * dests > 600:
        # The engine installs one handler per control in the load dispatch:
        # 900 Cross controls cost it about 115,000 instructions and 4096 about
        # 280,000 before the mode runs. The runner would fail the load budget,
        # so these tests check the handler and frame maxima themselves (check()).
        q.allow_budget = True
    q.advance(0.2)
    return q


def check(q):
    """Handler and frame budgets, whatever the load cost."""
    b = q.budget(strict=False)
    assert b["max_handler"] < 120000, b["handlers"]
    assert b["max_frame"] < 60000, b["handlers"]
    return b


def icon(q):
    """The pad drawing once the frame-rate cap has let the pending frame out."""
    q.advance(0.1)
    return q.icon()


def cell(q, r, c):
    v = q.run("return TouchPad.inst:cellCentre(%d, %d)" % (r, c))
    assert v is not None and v[0] is not None, "cell %d,%d is not on the current page" % (r, c)
    return v[0], v[1]


def row_header(q, r):
    v = q.run("return TouchPad.inst:rowHeaderCentre(%d)" % r)
    assert v is not None and v[0] is not None
    return v[0], v[1]


def col_header(q, c):
    v = q.run("return TouchPad.inst:colHeaderCentre(%d)" % c)
    assert v is not None and v[0] is not None
    return v[0], v[1]


def arrow(q, kind, direction):
    v = q.run("return TouchPad.inst:arrowCentre('%s', %d)" % (kind, direction))
    assert v is not None and v[0] is not None, "no %s arrows" % kind
    return v[0], v[1]


def page_info(q, kind):
    page, pages, sizes = q.run("return TouchPad.inst:pageInfo('%s')" % kind)
    return int(page), int(pages), [int(s) for s in sizes.split(",")]


def is_on(q, r, c):
    return bool(q.run("return TouchPad.inst:isOn(%d, %d)" % (r, c)))


def settle(q):
    """Lets the pin write queue drain (bulk writes follow 128 per turn)."""
    q.advance(0.25)
    assert q.run("return TouchPad.inst:pendingWrites()") == 0


def cross_pin(q, r, c, cols):
    return q.pin("Cross", (r - 1) * cols + c)["Boolean"]


def routes(q, n):
    return [int(q.pin("Route", j)["Value"]) for j in range(1, n + 1)]


def tap(q, xy):
    q.tap(xy[0], xy[1], panel_touch=True)


def drag(q, a, b, steps=10, seconds=0.8):
    pts = [(a[0] + (b[0] - a[0]) * k / steps, a[1] + (b[1] - a[1]) * k / steps) for k in range(steps + 1)]
    return q.drag(pts, seconds=seconds, panel_touch=True)


def test_matrix_controls_pins_and_lint():
    q = boot(4, 3)
    names = q.control_names()
    for n in ("SourceName 4", "DestName 3", "Cross 1", "Cross 12", "Route 3", "ExclusiveColumns", "ClearAll"):
        assert n in names, n
    assert "Cross 13" not in names and "Route 4" not in names and "SourceName 5" not in names
    assert q.pin("ExclusiveColumns")["Boolean"] is True             # default on
    assert routes(q, 3) == [0, 0, 0]
    assert all(cross_pin(q, r, c, 3) is False for r in range(1, 5) for c in range(1, 4))
    assert q.layout_lint(matrix=[{}, {"Sources": 64, "Destinations": 64}, {"Sources": 1, "Destinations": 1},
                                 {"Sources": 16, "Destinations": 17}, {"Pad Width": 120, "Pad Height": 120},
                                 {"Pad Width": 1600, "Pad Height": 300}]) == []
    assert q.status().startswith("OK")


def test_matrix_idle_drawing_names_hint_and_gesture():
    q = boot(4, 3)
    svg = icon(q)
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    for label in ("Source 1", "Source 4", "Dest 1", "Dest 3"):
        assert ">%s<" % label in svg, label                        # unnamed headers carry a default name
    assert svg.count('fill="#0E0D12"') == 12                        # 4 x 3 crosspoints, all off (theme well)
    assert "Tap a crosspoint, drag to paint" in svg
    assert q.pin("Gesture")["String"] == "TAP A CROSSPOINT, DRAG TO PAINT"
    assert "chevron" not in svg and "rotate(-90)" not in svg       # no paging, horizontal labels
    q.set_pin("SourceName", "Laptop", 1)
    q.set_pin("DestName", "Front Display", 2)
    svg = icon(q)
    assert ">Laptop<" in svg and ">Source 1<" not in svg and ">Front Display<" in svg
    assert q.budget()["max_frame"] < 60000


def test_matrix_tap_toggles_a_crosspoint():
    q = boot(4, 3)
    q.set_pin("SourceName", "Laptop", 2)
    q.set_pin("DestName", "Front Display", 3)
    tap(q, cell(q, 2, 3))
    assert is_on(q, 2, 3) and cross_pin(q, 2, 3, 3) is True
    assert routes(q, 3) == [0, 0, 2]
    assert q.pin("Gesture")["String"] == "LAPTOP -> FRONT DISPLAY"
    svg = icon(q)
    assert svg.count('fill="#C513E8" stroke="#C513E8"') == 1        # one accent cell
    assert q.pulses("Tap") == 1
    tap(q, cell(q, 2, 3))
    assert not is_on(q, 2, 3) and cross_pin(q, 2, 3, 3) is False
    assert routes(q, 3) == [0, 0, 0]
    assert q.pin("Gesture")["String"] == "LAPTOP -> FRONT DISPLAY OFF"
    assert 'fill="#C513E8" stroke="#C513E8"' not in icon(q)
    assert q.pulses("Press") == 2 and q.pulses("Release") == 2


def test_matrix_exclusive_columns_keep_one_source_per_column():
    q = boot(4, 2)
    tap(q, cell(q, 1, 1))
    tap(q, cell(q, 3, 1))
    assert is_on(q, 3, 1) and not is_on(q, 1, 1)
    assert cross_pin(q, 3, 1, 2) is True and cross_pin(q, 1, 1, 2) is False
    assert routes(q, 2) == [3, 0]
    tap(q, cell(q, 3, 2))                                           # another column is independent
    assert is_on(q, 3, 1) and is_on(q, 3, 2)
    assert routes(q, 2) == [3, 3]
    # the second tap of a quick double tap toggles the crosspoint back
    q.reset_pulses()
    q.double_tap(*cell(q, 2, 2), gap=0.15, panel_touch=True)
    assert q.pulses("DoubleTap") == 1 and q.pulses("Tap") == 2
    assert not is_on(q, 2, 2) and not is_on(q, 3, 2)                # the first tap replaced 3,2
    assert routes(q, 2) == [3, 0]
    assert q.pin("Gesture")["String"] == "SOURCE 2 -> DEST 2 OFF"   # the mode's text, not DOUBLE TAP


def test_matrix_exclusive_off_allows_several_sources_per_column():
    q = boot(4, 2)
    q.set_pin("ExclusiveColumns", False)
    tap(q, cell(q, 1, 1))
    tap(q, cell(q, 3, 1))
    tap(q, cell(q, 2, 1))
    assert is_on(q, 1, 1) and is_on(q, 3, 1) and is_on(q, 2, 1)
    assert q.pin("Route", 1)["Value"] == 2                          # the source routed last
    tap(q, cell(q, 2, 1))                                           # off: the lowest remaining source
    assert q.pin("Route", 1)["Value"] == 1
    tap(q, cell(q, 1, 1))
    assert q.pin("Route", 1)["Value"] == 3
    tap(q, cell(q, 3, 1))
    assert q.pin("Route", 1)["Value"] == 0
    # switching Exclusive back on keeps the routed source and drops the others
    tap(q, cell(q, 4, 2))
    tap(q, cell(q, 1, 2))
    assert is_on(q, 4, 2) and is_on(q, 1, 2) and q.pin("Route", 2)["Value"] == 1
    q.set_pin("ExclusiveColumns", True)
    assert is_on(q, 1, 2) and not is_on(q, 4, 2)
    assert cross_pin(q, 4, 2, 2) is False and q.pin("Route", 2)["Value"] == 1


def test_matrix_drag_paints_across_crosspoints():
    q = boot(4, 4)
    q.set_pin("ExclusiveColumns", False)
    drag(q, cell(q, 2, 1), cell(q, 2, 4))                           # along a row: all four on
    assert [is_on(q, 2, c) for c in (1, 2, 3, 4)] == [True] * 4
    assert routes(q, 4) == [2, 2, 2, 2]
    assert q.pin("Gesture")["String"] == "SET 4 CROSSPOINTS"
    assert q.pulses("Tap") == 0
    drag(q, cell(q, 1, 2), cell(q, 4, 2))                           # down a column
    assert [is_on(q, r, 2) for r in (1, 2, 3, 4)] == [True] * 4
    assert q.pin("Gesture")["String"] == "SET 3 CROSSPOINTS"        # 2,2 was on already
    drag(q, cell(q, 2, 4), cell(q, 2, 1))                           # starts on an on cell: paints off
    assert [is_on(q, 2, c) for c in (1, 2, 3, 4)] == [False] * 4
    assert q.pin("Gesture")["String"] == "CLEARED 4 CROSSPOINTS"
    assert routes(q, 4) == [0, 4, 0, 0]                             # column 2 still carries 1, 3, 4
    assert [is_on(q, r, 2) for r in (1, 3, 4)] == [True] * 3
    # with Exclusive on, painting a row moves every column to that row
    q.set_pin("ExclusiveColumns", True)
    drag(q, cell(q, 3, 1), cell(q, 3, 4))
    assert routes(q, 4) == [3, 3, 3, 3]
    assert not is_on(q, 1, 2) and is_on(q, 3, 2)
    assert q.budget()["max_handler"] < 120000


def test_matrix_row_header_selects_the_source_for_every_column():
    q = boot(3, 4)
    q.set_pin("SourceName", "Doc Cam", 2)
    tap(q, cell(q, 1, 2))
    tap(q, cell(q, 3, 4))
    tap(q, row_header(q, 2))
    assert routes(q, 4) == [2, 2, 2, 2]
    assert all(cross_pin(q, 2, c, 4) for c in (1, 2, 3, 4))
    assert cross_pin(q, 1, 2, 4) is False and cross_pin(q, 3, 4, 4) is False
    assert q.pin("Gesture")["String"] == "DOC CAM -> ALL"
    assert icon(q).count('fill="#C513E8" stroke="#C513E8"') == 4


def test_matrix_column_header_clears_the_column():
    q = boot(4, 3)
    q.set_pin("ExclusiveColumns", False)
    q.set_pin("DestName", "Stage Left", 2)
    for r in (1, 2, 4):
        tap(q, cell(q, r, 2))
    tap(q, cell(q, 3, 3))
    assert routes(q, 3) == [0, 4, 3]
    tap(q, col_header(q, 2))
    assert [is_on(q, r, 2) for r in (1, 2, 3, 4)] == [False] * 4
    assert all(cross_pin(q, r, 2, 3) is False for r in (1, 2, 3, 4))
    assert routes(q, 3) == [0, 0, 3]
    assert is_on(q, 3, 3)                                           # other columns untouched
    assert q.pin("Gesture")["String"] == "STAGE LEFT CLEARED"
    svg = icon(q)
    assert svg.count('fill="#C513E8" stroke="#C513E8"') == 1


def test_matrix_cross_and_route_pins_written_from_outside():
    q = boot(4, 3)
    q.set_pin("Cross", True, (3 - 1) * 3 + 2)                       # row 3, column 2
    assert is_on(q, 3, 2) and routes(q, 3) == [0, 3, 0]
    assert icon(q).count('fill="#C513E8" stroke="#C513E8"') == 1
    q.set_pin("Cross", True, (1 - 1) * 3 + 2)                       # exclusive: row 1 replaces row 3
    assert is_on(q, 1, 2) and not is_on(q, 3, 2)
    assert cross_pin(q, 3, 2, 3) is False and routes(q, 3) == [0, 1, 0]
    q.set_pin("Cross", False, (1 - 1) * 3 + 2)
    assert not is_on(q, 1, 2) and routes(q, 3) == [0, 0, 0]
    # Route from outside sets the crosspoint, clamped to the source count
    q.set_pin("Route", 4, 1)
    assert is_on(q, 4, 1) and cross_pin(q, 4, 1, 3) is True
    q.set_pin("Route", 99, 3)
    assert q.pin("Route", 3)["Value"] == 4 and is_on(q, 4, 3)
    q.set_pin("Route", 2, 3)
    assert is_on(q, 2, 3) and not is_on(q, 4, 3)
    q.set_pin("Route", 0, 3)
    assert not is_on(q, 2, 3) and cross_pin(q, 2, 3, 3) is False
    assert routes(q, 3) == [4, 0, 0]
    # the pad's own writes do not come back as pin events (echo guard)
    tap(q, cell(q, 2, 2))
    q.advance(2)
    assert is_on(q, 2, 2) and routes(q, 3) == [4, 2, 0]
    assert q.status().startswith("OK")


def test_matrix_start_up_state_follows_the_pins():
    """Pins preset before the mode starts: a fresh instance scans Cross, drops
    a second source of a column while Exclusive is on and follows Route for
    columns without a crosspoint."""
    q = boot(4, 3)
    q.run("TouchPad.inst.onControl = function() end")                # the live instance looks away
    q.set_pin("Cross", True, (1 - 1) * 3 + 1)                       # 1,1
    q.set_pin("Cross", True, (2 - 1) * 3 + 2)                       # 2,2
    q.set_pin("Cross", True, (4 - 1) * 3 + 2)                       # 4,2: second source of column 2
    q.set_pin("Route", 3, 3)                                        # column 3 by its Route pin
    q.run("TouchPad.fresh = Modes['Matrix'].create(TouchPad.E); TouchPad.fresh:onStart()")
    q.advance(0.3)
    on = lambda r, c: bool(q.run("return TouchPad.fresh:isOn(%d, %d)" % (r, c)))
    assert on(1, 1) and on(2, 2) and not on(4, 2) and on(3, 3)
    assert [int(q.run("return TouchPad.fresh:routeOf(%d)" % c)) for c in (1, 2, 3)] == [1, 2, 3]
    assert cross_pin(q, 4, 2, 3) is False and cross_pin(q, 3, 3, 3) is True
    assert routes(q, 3) == [1, 2, 3]
    assert q.run("return TouchPad.fresh:scanning()") is False
    assert q.status().startswith("OK")
    # a 64 x 64 start-up scans its 4096 pins over a few turns
    big = boot(64, 64)
    assert big.run("return TouchPad.inst:scanning()") is False      # 0.2 s was enough
    assert big.status().startswith("OK")
    check(big)


def test_matrix_clear_all():
    q = boot(3, 3)
    tap(q, cell(q, 1, 1))
    tap(q, cell(q, 2, 3))
    q.set_pin("ClearAll", True)
    assert routes(q, 3) == [0, 0, 0]
    assert not is_on(q, 1, 1) and not is_on(q, 2, 3)
    assert all(cross_pin(q, r, c, 3) is False for r in (1, 2, 3) for c in (1, 2, 3))
    assert q.pin("Gesture")["String"] == "ALL CLEARED"
    assert q.run("return TouchPad.inst:pendingWrites()") == 0        # a small matrix writes at once
    tap(q, cell(q, 3, 3))
    q.set_pin("ClearAll", False)                                    # the trailing edge clears nothing
    assert is_on(q, 3, 3)
    q.advance(2)
    q.trigger("ClearAll")                                           # a bare trigger clears too
    assert not is_on(q, 3, 3) and q.pin("Gesture")["String"] == "ALL CLEARED"
    assert 'fill="#C513E8" stroke="#C513E8"' not in icon(q)


def test_matrix_paging_64_by_64():
    q = boot(64, 64)
    pR, nR, sizesR = page_info(q, "R")
    pC, nC, sizesC = page_info(q, "C")
    assert pR == 1 and pC == 1
    assert max(sizesR) <= 12 and max(sizesC) <= 12
    assert sum(sizesR) == 64 and sum(sizesC) == 64
    assert max(sizesR) - min(sizesR) <= 1 and max(sizesC) - min(sizesC) <= 1   # pages share evenly
    assert nR == len(sizesR) and nC == len(sizesC) == 6
    svg = icon(q)
    assert len(svg) < 40000
    assert svg.count('fill="#0E0D12"') == sizesR[0] * sizesC[0]
    assert "1 / %d" % nR in svg and "rotate(-90)" in svg            # narrow columns: vertical labels
    assert svg.count('<g opacity="0.3">') == 2                     # both "previous" halves are off
    assert cell(q, sizesR[0], sizesC[0])
    assert q.run("return TouchPad.inst:cellCentre(%d, 1)" % (sizesR[0] + 1)) is None
    tap(q, arrow(q, "R", -1))                                       # no page before the first
    assert page_info(q, "R")[0] == 1
    tap(q, arrow(q, "R", 1))
    assert page_info(q, "R")[0] == 2
    assert q.pin("Gesture")["String"] == "ROWS PAGE 2 OF %d" % nR
    assert cell(q, sizesR[0] + 1, 1)
    tap(q, arrow(q, "C", 1))
    assert page_info(q, "C")[0] == 2
    assert q.pin("Gesture")["String"] == "COLUMNS PAGE 2 OF %d" % nC
    r, c = sizesR[0] + 2, sizesC[0] + 3
    tap(q, cell(q, r, c))                                           # a crosspoint on page (2, 2)
    assert is_on(q, r, c) and cross_pin(q, r, c, 64) is True        # a single write is immediate
    assert q.pin("Route", c)["Value"] == r
    for _ in range(nC):
        tap(q, arrow(q, "C", 1))
    assert page_info(q, "C")[0] == nC                               # stops at the last page
    assert cell(q, r, 64)
    assert "%d / %d" % (nC, nC) in icon(q)
    tap(q, row_header(q, r + 1))                                    # 64 columns: queued writes
    assert all(is_on(q, r + 1, cc) for cc in range(1, 65))
    settle(q)
    assert all(cross_pin(q, r + 1, cc, 64) for cc in range(1, 65))
    assert cross_pin(q, r, c, 64) is False and routes(q, 64) == [r + 1] * 64
    check(q)


def test_matrix_swipe_turns_the_pages():
    q = boot(30, 30)
    hx, hy = col_header(q, 5)                                       # along the column header strip
    q.swipe(hx + 120, hy, hx - 120, hy, seconds=0.2, panel_touch=True)   # left: next column page
    assert page_info(q, "C")[0] == 2 and page_info(q, "R")[0] == 1
    assert q.pin("Gesture")["String"] == "COLUMNS PAGE 2 OF 3"
    q.swipe(hx - 120, hy, hx + 120, hy, seconds=0.2, panel_touch=True)
    assert page_info(q, "C")[0] == 1
    rx, ry = row_header(q, 5)                                       # along the row headers
    q.swipe(rx, ry + 120, rx, ry - 120, seconds=0.2, panel_touch=True)   # up: next row page
    assert page_info(q, "R")[0] == 2
    assert q.pin("Gesture")["String"] == "ROWS PAGE 2 OF 3"
    q.swipe(rx, ry - 120, rx, ry + 120, seconds=0.2, panel_touch=True)
    assert page_info(q, "R")[0] == 1
    assert q.pulses("SwipeLeft") == 1 and q.pulses("SwipeRight") == 1
    assert q.pulses("SwipeUp") == 1 and q.pulses("SwipeDown") == 1
    assert not any(is_on(q, r, c) for r in range(1, 11) for c in range(1, 11))
    # a fast stroke over the crosspoints paints and never turns a page
    x, y = cell(q, 6, 2)
    x2, _ = cell(q, 6, 9)
    q.swipe(x, y, x2, y, seconds=0.2, panel_touch=True)
    assert q.pulses("SwipeRight") == 2
    assert page_info(q, "C")[0] == 1 and page_info(q, "R")[0] == 1
    assert is_on(q, 6, 2) and is_on(q, 6, 9)
    assert q.pin("Gesture")["String"].startswith("SET ")


def test_matrix_clear_all_on_a_full_64_by_64_is_spread_over_turns():
    q = boot(64, 64)
    q.set_pin("ExclusiveColumns", False)
    # every crosspoint on, as 4096 pin writes from outside (one handler each)
    q.run("for idx = 1, 4096 do Controls.Cross[idx].Boolean = true end")
    assert is_on(q, 1, 1) and is_on(q, 64, 64) and is_on(q, 33, 17)
    assert q.pin("Route", 64)["Value"] == 64
    check(q)
    q.set_pin("ClearAll", True)
    assert not is_on(q, 1, 1) and not is_on(q, 64, 64)
    assert routes(q, 64) == [0] * 64                                # 64 Route writes fit a handler
    assert q.pin("Gesture")["String"] == "ALL CLEARED"
    assert q.run("return TouchPad.inst:pendingWrites()") >= 1
    assert q.pin("Cross", 4096)["Boolean"] is True                  # not yet written
    tap(q, cell(q, 3, 3))                                           # a cell turned on meanwhile stays on
    q.advance(1.0)
    assert q.run("return TouchPad.inst:pendingWrites()") == 0
    assert all(q.pin("Cross", idx)["Boolean"] is False for idx in (1, 500, 2000, 4095, 4096))
    assert cross_pin(q, 3, 3, 64) is True and is_on(q, 3, 3)
    assert 'fill="#C513E8" stroke="#C513E8"' in icon(q)
    # Exclusive switched on over a full matrix is enforced column by column
    q.run("for idx = 1, 4096 do Controls.Cross[idx].Boolean = true end")
    q.set_pin("ExclusiveColumns", True)
    q.advance(1.0)
    assert sum(1 for r in range(1, 65) for c in range(1, 65) if is_on(q, r, c)) == 64
    assert all(q.pin("Route", c)["Value"] >= 1 for c in range(1, 65))
    assert sum(1 for idx in range(1, 4097) if q.pin("Cross", idx)["Boolean"]) == 64
    b = check(q)
    assert b["handlers"].get("callafter", 0) < 120000


def test_matrix_resume_continues_a_paint_after_an_inferred_lift():
    q = boot(4, 4)
    q.set_pin("ExclusiveColumns", False)
    a, b = cell(q, 2, 1), cell(q, 2, 2)
    pts = [(a[0] + (b[0] - a[0]) * k / 6, a[1]) for k in range(7)]
    q.touch(pts, dt=0.05, lift=False)                               # no PanelTouch: lifts are inferred
    assert q.run("return TouchPad.inst:isPainting()") is True
    q.advance(0.5)                                                  # silence: inferred lift
    assert q.run("return TouchPad.inst:isPainting()") is False
    assert q.pin("Gesture")["String"] == "SET 2 CROSSPOINTS"
    c3 = cell(q, 2, 3)
    q.touch([(b[0] + 8, b[1] + 8), (c3[0], c3[1])], dt=0.05, lift=False)  # resumed near the last spot
    assert q.run("return TouchPad.inst:isPainting()") is True
    q.lift()
    assert [is_on(q, 2, c) for c in (1, 2, 3)] == [True] * 3
    assert q.pin("Gesture")["String"] == "SET 3 CROSSPOINTS"


def test_matrix_lock_hints_and_odd_pads():
    q = boot(4, 3)
    a, b = cell(q, 1, 1), cell(q, 1, 3)
    q.touch([a, ((a[0] + b[0]) / 2, a[1])], panel_touch=True, lift=False)
    assert q.run("return TouchPad.inst:isPainting()") is True
    q.set_pin("Lock", True)
    q.advance(0.05)
    assert "Locked" in q.icon()
    assert q.run("return TouchPad.inst:isPainting()") is False
    q.lift()
    q.set_pin("Lock", False)
    assert "Locked" not in icon(q)
    assert is_on(q, 1, 1) and is_on(q, 1, 2) and not is_on(q, 1, 3)
    quiet = boot(4, 3, props={"Show Hints": False})
    assert "Tap a crosspoint" not in quiet.icon()
    assert quiet.pin("Gesture")["String"] == "TAP A CROSSPOINT, DRAG TO PAINT"
    for w, h, s, d in ((120, 120, 1, 1), (1600, 300, 12, 20), (300, 1200, 40, 2), (500, 500, 64, 64)):
        odd = boot(s, d, props={"Pad Width": w, "Pad Height": h, "Theme": "Light"})
        svg = odd.icon()
        assert 'viewBox="0 0 %d %d"' % (w, h) in svg and len(svg) < 40000
        assert all(ord(ch) < 127 for ch in svg)
        tap(odd, cell(odd, 1, 1))
        assert is_on(odd, 1, 1) and odd.status().startswith("OK")
        check(odd)


def test_matrix_budget_with_64_names_of_120_characters():
    q = boot(64, 64, props={"Max Frame Rate": "30"})
    q.set_pin("ExclusiveColumns", False)
    for i in range(1, 65):
        q.set_pin("SourceName", ("Source %d " % i + "very long source name ") * 6, i)
        q.set_pin("DestName", ("Display %d " % i + "very long destination name ") * 6, i)
    assert len(q.pin("SourceName", 64)["String"]) >= 120
    a, b = cell(q, 1, 1), cell(q, 11, 11)
    pts = [(a[0] + (b[0] - a[0]) * k / 60, a[1] + (b[1] - a[1]) * k / 60) for k in range(61)]
    q.drag(pts, seconds=2.0, panel_touch=True)                      # paints the diagonal
    assert is_on(q, 1, 1) and is_on(q, 11, 11)
    for _ in range(3):
        tap(q, arrow(q, "C", 1))
        tap(q, arrow(q, "R", 1))
    tap(q, row_header(q, 40))
    settle(q)
    assert all(cross_pin(q, 40, c, 64) for c in range(1, 65))
    tap(q, col_header(q, 40))
    settle(q)
    assert q.pin("Route", 40)["Value"] == 0
    q.set_pin("ClearAll", True)
    q.advance(1.0)
    b = check(q)
    assert b["frames"] >= 30
    assert len(icon(q)) < 40000
