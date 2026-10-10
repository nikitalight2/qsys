# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Drag & Drop mode (21_mode_dragdrop.lua)
"""Sources on the left, screens on the right: drag a source onto a screen or
tap a source then a screen; a double tap on the same source tile sends it to
every screen (call screens kept out while AllowCalls is on); lists page at
most 12 sources / 16 screens per page with arrows; Route n is a pin both
ways; a picked source is put down after 8 s."""
import os
import re

from harness import QSys

MODE = "Drag & Drop"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))


def find_plugin():
    """The first plugin that defines the mode: $TOUCHPAD_PLUGIN, the per-mode
    build, then the full plugin."""
    candidates = [os.environ.get("TOUCHPAD_PLUGIN", ""),
                  os.path.join(REPO, "plugins", ".build", "NikitaTouchPad-dragdrop.qplug"),
                  os.path.join(REPO, "plugins", "NikitaTouchPad.qplug")]
    for path in candidates:
        if path and os.path.exists(path):
            with open(path, "rb") as fh:
                if b'Modes["Drag & Drop"]' in fh.read():
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
    q.advance(0.2)
    return q


def icon(q):
    """The pad drawing once the frame-rate cap has let the pending frame out."""
    q.advance(0.1)
    return q.icon()


def centre(q, kind, i):
    """Centre of a tile on the current page of its list (pad px)."""
    r = q.run("return TouchPad.inst:tileCentre('%s', %d)" % (kind, i))
    assert r is not None and r[0] is not None, "tile %s %d is not on the current page" % (kind, i)
    return r[0], r[1]


def arrow(q, kind, direction):
    r = q.run("return TouchPad.inst:arrowCentre('%s', %d)" % (kind, direction))
    assert r is not None and r[0] is not None, "list %s has no arrows" % kind
    return r[0], r[1]


def page_info(q, kind):
    page, pages, sizes = q.run("return TouchPad.inst:pageInfo('%s')" % kind)
    return int(page), int(pages), [int(s) for s in sizes.split(",")]


def picked(q):
    return q.run("return TouchPad.inst:pickedSource()")


def routes(q, n):
    return [int(q.pin("Route", j)["Value"]) for j in range(1, n + 1)]


def drag_to(q, src, dst_xy, steps=8, **kw):
    sx, sy = centre(q, "S", src)
    dx, dy = dst_xy
    pts = [(sx + (dx - sx) * k / steps, sy + (dy - sy) * k / steps) for k in range(steps + 1)]
    kw.setdefault("panel_touch", True)
    kw.setdefault("seconds", 0.8)
    return q.drag(pts, **kw)


def name_all(q, n_src, n_dst, length=120):
    for i in range(1, n_src + 1):
        q.set_pin("SourceName", ("Laptop %d " % i + "very long source name ") * 6, i)
        assert len(q.pin("SourceName", i)["String"]) >= length
    for j in range(1, n_dst + 1):
        q.set_pin("DestName", ("Display %d " % j + "very long screen name ") * 6, j)


def test_dragdrop_controls_and_pins():
    q = boot(4, 3)
    names = q.control_names()
    for n in ("SourceName 4", "SourceActive 4", "DestName 3", "Route 3", "Routed 3", "RouteName 3",
              "ClearRoutes", "TapOnly", "AllowCalls"):
        assert n in names, n
    assert "SourceName 5" not in names and "Route 4" not in names
    assert q.pin("AllowCalls")["Boolean"] is True                  # default on
    assert q.pin("SourceActive", 2)["Boolean"] is True              # signal present unless wired
    assert q.pin("TapOnly")["Boolean"] is False
    assert routes(q, 3) == [0, 0, 0]
    assert q.pin("RouteName", 1)["String"] == ""
    assert q.layout_lint(matrix=[{}, {"Sources": 64, "Destinations": 64}, {"Sources": 1, "Destinations": 1},
                                 {"Sources": 16, "Destinations": 17}]) == []


def test_dragdrop_idle_drawing_names_hint_and_gesture():
    q = boot(4, 3)
    svg = icon(q)
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    assert "SOURCES" in svg and "SCREENS" in svg
    for label in ("Source 1", "Source 4", "Screen 1", "Screen 3"):
        assert ">%s<" % label in svg, label                        # unnamed tiles carry a default name
    assert "Drag a source to a screen" in svg
    assert q.pin("Gesture")["String"] == "DRAG A SOURCE TO A SCREEN"
    assert "stroke-dasharray" not in svg and "chevron" not in svg  # no paging for 4 x 3
    q.set_pin("SourceName", "Laptop", 1)
    q.set_pin("DestName", "Front Display", 1)
    svg = icon(q)
    assert ">Laptop<" in svg and ">Source 1<" not in svg and ">Front Display<" in svg


def test_dragdrop_tap_source_then_screen_routes():
    q = boot(4, 3)
    q.set_pin("SourceName", "Laptop", 1)
    q.set_pin("DestName", "Front Display", 1)
    sx, sy = centre(q, "S", 1)
    q.tap(sx, sy, panel_touch=True)
    assert picked(q) == 1
    assert q.pin("Gesture")["String"] == "NOW TAP A SCREEN"
    assert "Now tap a screen" in icon(q)
    assert 'stroke-width="3"' in icon(q)                           # the picked outline
    dx, dy = centre(q, "D", 1)
    q.tap(dx, dy, panel_touch=True)
    assert q.pin("Route", 1)["Value"] == 1
    assert q.pin("RouteName", 1)["String"] == "Laptop"
    assert q.pulses("Routed", 1) == 1 and q.pulses("Routed", 2) == 0
    assert q.pin("Gesture")["String"] == "LAPTOP -> FRONT DISPLAY"
    assert picked(q) == 1                                           # still picked: tap another screen
    dx2, dy2 = centre(q, "D", 2)
    q.tap(dx2, dy2, panel_touch=True)
    assert routes(q, 3) == [1, 1, 0] and q.pulses("Routed", 2) == 1
    assert q.pin("Gesture")["String"] == "LAPTOP -> SCREEN 2"
    svg = icon(q)
    assert svg.count(">Laptop<") == 3                               # source tile + two routed screens


def test_dragdrop_drag_source_onto_screen():
    q = boot(4, 3)
    q.set_pin("SourceName", "Apple TV", 2)
    q.set_pin("DestName", "Projector", 3)
    sx, sy = centre(q, "S", 2)
    dx, dy = centre(q, "D", 3)
    pts = [(sx + (dx - sx) * k / 8, sy + (dy - sy) * k / 8) for k in range(9)]
    q.drag(pts, seconds=0.8, panel_touch=True, lift=False)
    assert q.run("return TouchPad.inst:isCarrying()") is True
    assert q.pin("Gesture")["String"] == "DROP ON A SCREEN"
    svg = icon(q)
    assert svg.count(">Apple TV<") == 2                             # the tile and the carried ghost
    assert 'opacity="0.92"' in svg
    assert routes(q, 3) == [0, 0, 0]                                # nothing until the drop
    q.lift()
    assert routes(q, 3) == [0, 0, 2]
    assert q.pin("RouteName", 3)["String"] == "Apple TV"
    assert q.pulses("Routed", 3) == 1
    assert q.pin("Gesture")["String"] == "APPLE TV -> PROJECTOR"
    assert picked(q) is None                                        # a drop ends the pick
    assert q.run("return TouchPad.inst:isCarrying()") is False
    svg = icon(q)
    assert 'opacity="0.92"' not in svg and svg.count(">Apple TV<") == 2


def test_dragdrop_drop_on_empty_space_puts_the_source_down():
    q = boot(2, 2)
    drag_to(q, 1, (250, 480))                                       # the hint strip, no tile
    assert routes(q, 2) == [0, 0] and picked(q) is None
    assert q.pulses("Routed", 1) == 0 and q.pulses("Routed", 2) == 0
    assert q.pin("Gesture")["String"] == "DRAG A SOURCE TO A SCREEN"


def test_dragdrop_double_tap_sends_to_every_screen_but_calls():
    q = boot(2, 6)
    q.set_pin("SourceName", "Laptop", 1)
    for j, name in enumerate(("Front", "Teams Room", "Side", "zoom-rm", "Webex Codec", "Call 1"), start=1):
        q.set_pin("DestName", name, j)
    sx, sy = centre(q, "S", 1)
    q.double_tap(sx, sy, gap=0.15, panel_touch=True)
    assert routes(q, 6) == [1, 0, 1, 0, 0, 0]
    assert q.pulses("Routed", 1) == 1 and q.pulses("Routed", 3) == 1 and q.pulses("Routed", 2) == 0
    assert q.pulses("DoubleTap") == 1
    assert q.pin("Gesture")["String"] == "LAPTOP -> ALL SCREENS"
    assert picked(q) is None
    assert q.pin("RouteName", 3)["String"] == "Laptop" and q.pin("RouteName", 2)["String"] == ""


def test_dragdrop_allow_calls_off_includes_call_screens():
    q = boot(2, 3)
    q.set_pin("DestName", "Teams Room", 2)
    q.set_pin("AllowCalls", False)
    sx, sy = centre(q, "S", 2)
    q.double_tap(sx, sy, gap=0.15, panel_touch=True)
    assert routes(q, 3) == [2, 2, 2]
    assert q.pulses("Routed", 2) == 1
    # a word that merely contains a call word ("recall", "zooming") is no call screen
    q.set_pin("AllowCalls", True)
    q.set_pin("DestName", "Recall zooming", 2)
    q.set_pin("ClearRoutes", True)
    q.advance(0.5)
    q.double_tap(sx, sy, gap=0.15, panel_touch=True)
    assert routes(q, 3) == [2, 2, 2]


def test_dragdrop_double_tap_means_two_taps_on_the_same_tile():
    q = boot(6, 2, props={"Pad Width": 240, "Pad Height": 500})   # narrow pad: small, close tiles
    s1 = centre(q, "S", 1)
    s2 = centre(q, "S", 2)
    assert abs(s1[1] - s2[1]) < 40 or abs(s1[0] - s2[0]) < 40      # within the engine's double distance
    q.tap(*s1, panel_touch=True, silence=0.15)
    q.tap(*s2, panel_touch=True)
    assert routes(q, 2) == [0, 0]                                   # two taps, no broadcast
    assert picked(q) == 2
    assert q.pin("Gesture")["String"] == "NOW TAP A SCREEN"
    # ... and two taps on one tile within 0.4 s are a double tap even if the engine is not sure
    q.advance(1)
    q.tap(*s1, panel_touch=True, silence=0.15)
    q.tap(s1[0] + 20, s1[1], panel_touch=True)
    assert routes(q, 2) == [1, 1]


def test_dragdrop_tap_picked_source_again_puts_it_down():
    q = boot(3, 2)
    sx, sy = centre(q, "S", 3)
    q.tap(sx, sy, panel_touch=True)
    assert picked(q) == 3
    q.advance(0.6)                                                  # past the double-tap window
    q.tap(sx, sy, panel_touch=True)
    assert picked(q) is None and routes(q, 2) == [0, 0]
    assert q.pin("Gesture")["String"] == "DRAG A SOURCE TO A SCREEN"
    assert 'stroke-width="3"' not in icon(q)


def test_dragdrop_picked_source_is_put_down_after_8_seconds():
    q = boot(3, 2)
    sx, sy = centre(q, "S", 2)
    q.tap(sx, sy, panel_touch=True)
    q.advance(7.0)
    assert picked(q) == 2
    q.advance(1.5)
    assert picked(q) is None
    assert q.pin("Gesture")["String"] == "DRAG A SOURCE TO A SCREEN"
    assert "Drag a source to a screen" in icon(q)
    dx, dy = centre(q, "D", 1)
    q.tap(dx, dy, panel_touch=True)
    assert routes(q, 2) == [0, 0]
    assert q.pin("Gesture")["String"] == "PICK A SOURCE FIRST"
    # a tap-route restarts the 8 s
    q.tap(sx, sy, panel_touch=True)
    q.advance(6)
    q.tap(dx, dy, panel_touch=True)
    q.advance(6)
    assert picked(q) == 2
    q.advance(3)
    assert picked(q) is None


def test_dragdrop_route_pin_written_from_outside():
    q = boot(4, 2)
    q.set_pin("SourceName", "Doc Cam", 3)
    q.set_pin("Route", 3, 1)
    assert q.pin("RouteName", 1)["String"] == "Doc Cam"
    assert q.pulses("Routed", 1) == 1
    svg = icon(q)
    assert svg.count(">Doc Cam<") == 2                              # the screen shows its source
    q.set_pin("Route", 3, 1, fire=True)                             # the same value again
    assert q.pulses("Routed", 1) == 1
    q.set_pin("Route", 99, 1)                                       # clamped to the source count
    assert q.pin("Route", 1)["Value"] == 4 and q.pin("RouteName", 1)["String"] == "Source 4"
    assert q.pulses("Routed", 1) == 2
    q.set_pin("Route", 0, 1)
    assert q.pin("RouteName", 1)["String"] == "" and q.pulses("Routed", 1) == 3
    assert icon(q).count(">Doc Cam<") == 1
    # renaming a routed source renames the route
    q.set_pin("Route", 2, 2)
    q.set_pin("SourceName", "PC", 2)
    assert q.pin("RouteName", 2)["String"] == "PC"
    assert q.pulses("Routed", 2) == 1


def test_dragdrop_route_from_the_pad_does_not_echo_as_a_pin_write():
    q = boot(2, 2)
    sx, sy = centre(q, "S", 1)
    dx, dy = centre(q, "D", 2)
    q.tap(sx, sy, panel_touch=True)
    q.tap(dx, dy, panel_touch=True)
    assert q.pulses("Routed", 2) == 1                               # one pulse, not one per echo
    q.advance(2)
    assert q.pulses("Routed", 2) == 1
    assert q.pin("Route", 2)["Value"] == 1


def test_dragdrop_clear_routes():
    q = boot(3, 3)
    q.set_pin("Route", 1, 1)
    q.set_pin("Route", 2, 3)
    q.reset_pulses()
    sx, sy = centre(q, "S", 2)
    q.tap(sx, sy, panel_touch=True)
    q.set_pin("ClearRoutes", True)
    assert routes(q, 3) == [0, 0, 0]
    assert [q.pin("RouteName", j)["String"] for j in (1, 2, 3)] == ["", "", ""]
    assert q.pulses("Routed", 1) == 1 and q.pulses("Routed", 2) == 0 and q.pulses("Routed", 3) == 1
    assert q.pin("Gesture")["String"] == "ALL CLEARED"
    assert picked(q) is None
    q.set_pin("ClearRoutes", False)                                 # the trailing edge clears nothing twice
    assert q.pulses("Routed", 1) == 1
    q.advance(2)
    q.trigger("ClearRoutes")                                        # a bare trigger clears too
    assert q.pin("Gesture")["String"] == "ALL CLEARED"


def test_dragdrop_tap_only_ignores_drags():
    q = boot(3, 2)
    q.set_pin("TapOnly", True)
    assert q.pin("Gesture")["String"] == "TAP A SOURCE, THEN A SCREEN"
    assert "Tap a source, then a screen" in icon(q)
    dx, dy = centre(q, "D", 1)
    drag_to(q, 1, (dx, dy))
    assert routes(q, 2) == [0, 0] and picked(q) is None
    sx, sy = centre(q, "S", 1)
    q.tap(sx, sy, panel_touch=True)
    q.tap(dx, dy, panel_touch=True)
    assert routes(q, 2) == [1, 0]
    q.set_pin("TapOnly", False)
    dx2, dy2 = centre(q, "D", 2)
    drag_to(q, 3, (dx2, dy2))
    assert routes(q, 2) == [1, 3]
    assert q.pin("Gesture")["String"] == "SOURCE 3 -> SCREEN 2"


def test_dragdrop_signal_dims_a_source():
    q = boot(2, 2)
    assert 'opacity="0.45"' not in icon(q)
    q.set_pin("SourceActive", False, 1)
    svg = icon(q)
    assert svg.count('<g opacity="0.45">') == 1
    assert svg.index('opacity="0.45"') < svg.index(">Source 1<")   # the dimmed group wraps tile 1
    sx, sy = centre(q, "S", 1)
    dx, dy = centre(q, "D", 1)
    q.tap(sx, sy, panel_touch=True)
    q.tap(dx, dy, panel_touch=True)
    assert routes(q, 2) == [1, 0]                                   # dimmed, still routable
    q.set_pin("SourceActive", True, 1)
    assert 'opacity="0.45"' not in icon(q)


def test_dragdrop_icons_follow_whole_words_in_names():
    q = boot(5, 3)
    for i, name in enumerate(("Teams Room PC", "Wireless Share", "Doc Cam", "Zoomed Picture", "Music Player"), 1):
        q.set_pin("SourceName", name, i)
    q.set_pin("DestName", "Projector", 1)
    q.set_pin("DestName", "Room Camera", 2)
    svg = icon(q)
    paths = q.run("return Shapes.WORD_ICON.teams, Shapes.WORD_ICON.wireless, Shapes.WORD_ICON.music")
    icon_d = lambda n: q.run("local s = Svg.new(100, 100); Shapes.icon(s, '%s', 50, 50, 24, '#fff'); "
                             "return table.concat(s.parts)" % n)
    for name in ("teams", "wireless", "doccam", "laptop", "music", "projector", "room"):
        body = re.search(r'<path d="([^"]+)"', icon_d(name)).group(1)
        assert body in svg, name                                    # "Zoomed" is not "zoom": laptop default
    assert re.search(r'<path d="([^"]+)"', icon_d("zoom")).group(1) not in svg
    assert re.search(r'<path d="([^"]+)"', icon_d("display")).group(1) in svg   # unnamed screen 3


def test_dragdrop_long_names_are_fitted_and_cached():
    q = boot(4, 3)
    name_all(q, 4, 3)
    svg = icon(q)
    assert "..." in svg and len(svg) < 12000
    assert all(ord(ch) < 127 for ch in svg)
    frames0 = q.budget()["frames"]
    sx, sy = centre(q, "S", 1)
    q.tap(sx, sy, panel_touch=True)
    q.tap(*centre(q, "D", 1), panel_touch=True)
    g = q.pin("Gesture")["String"]
    assert g.startswith("LAPTOP 1 VERY LONG") and " -> DISPLAY 1 VERY LONG" in g and len(g) < 100
    assert q.budget()["frames"] > frames0
    assert q.budget()["max_frame"] < 60000
    q.set_pin("SourceName", "Short", 1)                             # a rename drops the cached fit
    assert ">Short<" in icon(q)


def test_dragdrop_paging_64_by_64():
    q = boot(64, 64)
    name_all(q, 64, 64)
    pS, nS, sizesS = page_info(q, "S")
    pD, nD, sizesD = page_info(q, "D")
    assert pS == 1 and pD == 1
    assert max(sizesS) <= 12 and max(sizesD) <= 16
    assert sum(sizesS) == 64 and sum(sizesD) == 64
    assert max(sizesS) - min(sizesS) <= 1 and max(sizesD) - min(sizesD) <= 1   # pages share evenly
    assert nS == len(sizesS) and nD == len(sizesD)
    svg = icon(q)
    assert len(svg) < 40000
    assert "1 / %d" % nS in svg and "1 / %d" % nD in svg
    assert svg.count('<g opacity="0.3">') == 2                     # both "previous" halves are off
    for i in range(1, sizesS[0] + 1):
        assert centre(q, "S", i)
    assert q.run("return TouchPad.inst:tileCentre('S', %d)" % (sizesS[0] + 1)) is None
    _, _, w, h = q.run("return TouchPad.inst:tileCentre('D', 1)")
    assert w >= 56 and h >= 56
    # the right arrow turns the page; the left one on page 1 does nothing
    q.tap(*arrow(q, "S", -1), panel_touch=True)
    assert page_info(q, "S")[0] == 1
    q.tap(*arrow(q, "S", 1), panel_touch=True)
    assert page_info(q, "S")[0] == 2
    assert q.pin("Gesture")["String"] == "SOURCES PAGE 2 OF %d" % nS
    assert centre(q, "S", sizesS[0] + 1)
    for _ in range(nS):
        q.tap(*arrow(q, "S", 1), panel_touch=True)
    assert page_info(q, "S")[0] == nS                               # stops at the last page
    assert centre(q, "S", 64)
    assert "%d / %d" % (nS, nS) in icon(q)
    q.tap(*arrow(q, "D", 1), panel_touch=True)
    assert page_info(q, "D")[0] == 2
    assert q.pin("Gesture")["String"] == "SCREENS PAGE 2 OF %d" % nD
    assert q.budget()["max_frame"] < 60000 and q.budget()["max_handler"] < 120000


def test_dragdrop_drop_on_the_arrows_turns_the_page_and_keeps_the_source():
    q = boot(20, 40)
    _, nD, sizesD = page_info(q, "D")
    assert nD >= 2
    drag_to(q, 3, arrow(q, "D", 1))
    assert page_info(q, "D")[0] == 2
    assert picked(q) == 3
    assert q.pin("Gesture")["String"] == "NOW TAP A SCREEN"
    assert routes(q, 40) == [0] * 40
    target = sizesD[0] + 2                                          # second screen of page 2
    q.tap(*centre(q, "D", target), panel_touch=True)
    assert q.pin("Route", target)["Value"] == 3
    assert q.pin("Gesture")["String"] == "SOURCE 3 -> SCREEN %d" % target
    # dragging onto a screen of the new page works as well
    drag_to(q, 4, centre(q, "D", target + 1))
    assert q.pin("Route", target + 1)["Value"] == 4
    assert picked(q) is None
    # a drop on the arrows of the sources list turns that list too
    drag_to(q, 5, arrow(q, "S", 1))
    assert page_info(q, "S")[0] == 2 and picked(q) == 5


def test_dragdrop_swipe_on_a_list_turns_its_page():
    q = boot(30, 30)
    q.swipe(230, 250, 30, 250, seconds=0.2, panel_touch=True)       # left swipe over the sources
    assert page_info(q, "S")[0] == 2 and page_info(q, "D")[0] == 1
    q.swipe(30, 250, 230, 250, seconds=0.2, panel_touch=True)
    assert page_info(q, "S")[0] == 1
    q.swipe(480, 250, 270, 250, seconds=0.2, panel_touch=True)
    assert page_info(q, "D")[0] == 2
    assert q.pulses("SwipeLeft") == 2 and q.pulses("SwipeRight") == 1


def test_dragdrop_resume_takes_back_an_inferred_drop():
    q = boot(3, 3)
    q.set_pin("Route", 2, 1)
    q.reset_pulses()
    sx, sy = centre(q, "S", 1)
    dx, dy = centre(q, "D", 1)
    pts = [(sx + (dx - sx) * k / 8, sy + (dy - sy) * k / 8) for k in range(9)]
    q.drag(pts, seconds=0.8)                                        # no Panel Touch: the lift is inferred
    assert q.pin("Route", 1)["Value"] == 1 and q.pulses("Routed", 1) == 1
    assert q.pin("RouteName", 1)["String"] == "Source 1"
    q.touch([(dx + 4, dy + 4)], lift=False)                         # the finger was still down: resumed
    assert q.pin("Route", 1)["Value"] == 2                          # the drop is taken back
    assert q.pin("RouteName", 1)["String"] == "Source 2"
    assert q.run("return TouchPad.inst:isCarrying()") is True
    assert q.pin("Gesture")["String"] == "DROP ON A SCREEN"
    dx3, dy3 = centre(q, "D", 3)
    q.touch([(dx + (dx3 - dx) * k / 4, dy + (dy3 - dy) * k / 4) for k in range(1, 5)], lift=False)
    q.lift()
    assert routes(q, 3) == [2, 0, 1]
    assert q.pulses("Routed", 3) == 1
    assert q.pin("Gesture")["String"] == "SOURCE 1 -> SCREEN 3"
    q.advance(2)                                                    # no resume: the route stays
    assert routes(q, 3) == [2, 0, 1]


def test_dragdrop_lock_puts_the_source_down():
    q = boot(3, 2)
    sx, sy = centre(q, "S", 1)
    q.tap(sx, sy, panel_touch=True)
    assert picked(q) == 1
    q.set_pin("Lock", True)
    q.advance(0.1)
    assert picked(q) is None and "Locked" in icon(q)
    q.set_pin("Lock", False)
    q.advance(0.1)
    assert "Locked" not in icon(q) and 'stroke-width="3"' not in icon(q)
    # a drag cut short by the lock drops nothing
    q.set_pin("PanelTouch", True)
    q.touch([(sx, sy), (sx + 40, sy + 10), (sx + 80, sy + 20)], lift=False)
    q.set_pin("Lock", True)
    q.set_pin("PanelTouch", False)
    q.advance(0.5)
    assert routes(q, 2) == [0, 0] and q.run("return TouchPad.inst:isCarrying()") is False
    q.set_pin("Lock", False)


def test_dragdrop_layouts_for_odd_pads():
    tall = boot(6, 4, props={"Pad Width": 200, "Pad Height": 600})
    assert icon(tall).index("SOURCES") < icon(tall).index("SCREENS")
    sx, sy = centre(tall, "S", 6)
    dx, dy = centre(tall, "D", 1)
    assert sy < dy                                                  # stacked: sources above screens
    wide = boot(12, 16, props={"Pad Width": 1600, "Pad Height": 300})
    assert page_info(wide, "S")[1] == 1 and page_info(wide, "D")[1] == 1
    assert len(icon(wide)) < 40000
    tiny = boot(64, 64, props={"Pad Width": 120, "Pad Height": 120})
    assert icon(tiny) and all(ord(ch) < 127 for ch in icon(tiny))
    assert page_info(tiny, "S")[1] >= 2
    tiny.tap(*arrow(tiny, "S", 1), panel_touch=True)
    assert page_info(tiny, "S")[0] == 2
    nohint = boot(2, 2, props={"Show Hints": False})
    assert "Drag a source" not in icon(nohint)
    assert nohint.pin("Gesture")["String"] == "DRAG A SOURCE TO A SCREEN"
    big = boot(64, 64, props={"Pad Width": 1600, "Pad Height": 1200})
    assert page_info(big, "S")[1] >= 2 and max(page_info(big, "S")[2]) <= 12


def test_dragdrop_budget_with_64_names_of_120_characters():
    q = boot(64, 64, props={"Max Frame Rate": "30"})
    name_all(q, 64, 64)
    sx, sy = centre(q, "S", 5)
    pts = [(sx + (450 - sx) * k / 60, sy + (400 - sy) * k / 60) for k in range(61)]
    q.drag(pts, seconds=2.0, panel_touch=True)
    for _ in range(3):
        q.tap(*arrow(q, "D", 1), panel_touch=True)
    q.tap(*arrow(q, "S", 1), panel_touch=True)
    drag_to(q, 15, arrow(q, "D", 1))
    q.set_pin("ClearRoutes", True)
    b = q.budget()
    assert b["frames"] >= 30
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(icon(q)) < 40000


def cold_stats(q):
    cnt, spent, cap = q.run("return TouchPad.inst:coldStats()")
    return int(cnt), int(spent), int(cap)


def warm(q, frames=40):
    """Lets the follow-up frames fill every placeholder tile."""
    for _ in range(frames):
        q.advance(0.05)


def test_dragdrop_budget_on_wide_pads_with_120_character_names():
    # a 1600 px pad fits ~100 characters of a name on a tile: the per-frame
    # cold budget scales with the tile width, so the frame stays under 60,000
    for (n_src, n_dst, w, h, turns) in ((12, 16, 1600, 1200, 0), (12, 16, 1200, 800, 0), (64, 64, 1600, 1200, 3)):
        q = boot(n_src, n_dst, props={"Pad Width": w, "Pad Height": h})
        name_all(q, n_src, n_dst)
        q.advance(0.1)
        cnt, spent, cap = cold_stats(q)
        assert 1 <= cnt <= 6 and spent <= cap
        if w == 1600:
            assert cnt <= 3                                     # 779 px tiles: three per frame
        warm(q)
        svg = icon(q)
        assert svg.count("...") >= n_src if n_src <= 12 else svg.count("...") >= 12   # every visible tile filled
        for _ in range(turns):
            q.tap(*arrow(q, "D", 1), panel_touch=True)
            q.tap(*arrow(q, "S", 1), panel_touch=True)
            q.advance(0.05)
            assert q.budget()["max_frame"] < 60000
            warm(q)
        b = q.budget()
        assert b["max_frame"] < 60000 and b["max_handler"] < 120000
        assert b["max_frame"] < 50000, b["max_frame"]              # margin, not just the limit
    # ... and a 500 px pad still renders six tiles of a cold page in one frame
    q = boot(64, 64)
    name_all(q, 64, 64)
    q.advance(0.1)
    cnt, spent, cap = cold_stats(q)
    assert cnt >= 6
    warm(q)
    assert q.budget()["max_frame"] < 60000


def test_dragdrop_quick_drop_on_a_later_page_keeps_that_page():
    q = boot(20, 40)
    q.tap(*arrow(q, "D", 1), panel_touch=True)
    assert page_info(q, "D")[0] == 2
    # a drop in 0.3 s is also a swipe to the engine; the page must not turn
    drag_to(q, 3, centre(q, "D", 16), seconds=0.3)
    assert q.pin("Route", 16)["Value"] == 3
    assert q.pin("Gesture")["String"] == "SOURCE 3 -> SCREEN 16"
    assert q.pulses("SwipeRight") == 1
    assert page_info(q, "D")[0] == 2
    drag_to(q, 4, centre(q, "D", 17), seconds=0.3)
    assert q.pin("Route", 17)["Value"] == 4 and page_info(q, "D")[0] == 2
    # a quick drop on the arrows turns the page once, not twice
    _, n_pages, _ = page_info(q, "D")
    assert n_pages >= 3
    drag_to(q, 5, arrow(q, "D", 1), seconds=0.3)
    assert page_info(q, "D")[0] == 3 and picked(q) == 5
    # the same with inferred lifts (no Panel Touch wiring)
    q2 = boot(20, 40)
    q2.tap(*arrow(q2, "D", 1))
    sx, sy = centre(q2, "S", 3)
    dx, dy = centre(q2, "D", 16)
    q2.drag([(sx + (dx - sx) * k / 8, sy + (dy - sy) * k / 8) for k in range(9)], seconds=0.3)
    assert q2.pin("Route", 16)["Value"] == 3 and page_info(q2, "D")[0] == 2
    # a quick swipe that drops nothing still pages the list it ran over
    q2.swipe(480, 250, 270, 250, seconds=0.2)
    assert page_info(q2, "D")[0] == 3


def test_dragdrop_jittery_tap_on_the_picked_source_puts_it_down():
    q = boot(3, 2)
    sx, sy = centre(q, "S", 3)
    q.tap(sx, sy, panel_touch=True)
    assert picked(q) == 3
    q.advance(0.6)
    q.touch([(sx, sy), (sx + 2, sy + 1)], panel_touch=True, lift=False)   # a real finger moves a little
    assert q.run("return TouchPad.inst:isCarrying()") is False
    assert q.pin("Gesture")["String"] == "NOW TAP A SCREEN"
    assert 'opacity="0.92"' not in icon(q)                          # no ghost flashes
    q.lift()
    assert picked(q) is None and routes(q, 2) == [0, 0]
    assert q.pin("Gesture")["String"] == "DRAG A SOURCE TO A SCREEN"
    # a jittery tap on a source picks it, a jittery tap on a screen routes it
    q.advance(0.6)
    q.touch([(sx, sy), (sx - 3, sy + 2)], panel_touch=True)
    assert picked(q) == 3
    dx, dy = centre(q, "D", 2)
    q.touch([(dx, dy), (dx + 2, dy - 2)], panel_touch=True)
    assert routes(q, 2) == [0, 3]
    # ... and a press that moves past the drag threshold carries
    q.touch([(sx, sy), (sx + 6, sy), (sx + 20, sy + 4)], panel_touch=True, lift=False)
    assert q.run("return TouchPad.inst:isCarrying()") is True
    assert q.pin("Gesture")["String"] == "DROP ON A SCREEN" and 'opacity="0.92"' in icon(q)
    q.lift()


def test_dragdrop_tap_only_during_a_drag_puts_the_source_down():
    q = boot(3, 2)
    sx, sy = centre(q, "S", 1)
    q.set_pin("PanelTouch", True)
    q.touch([(sx, sy), (sx + 40, sy + 10), (sx + 80, sy + 20)], lift=False)
    assert picked(q) == 1 and q.run("return TouchPad.inst:isCarrying()") is True
    q.set_pin("TapOnly", True)
    q.set_pin("PanelTouch", False)
    q.advance(0.5)
    assert picked(q) is None and q.run("return TouchPad.inst:isCarrying()") is False
    assert q.pin("Gesture")["String"] == "TAP A SOURCE, THEN A SCREEN"
    assert "Tap a source, then a screen" in icon(q) and "Drop on a screen" not in icon(q)
    assert routes(q, 2) == [0, 0]
    q.advance(10)
    assert picked(q) is None
    # a drag cut short by the lock leaves the idle hint behind too
    q.set_pin("TapOnly", False)
    q.set_pin("PanelTouch", True)
    q.touch([(sx, sy), (sx + 40, sy + 10), (sx + 80, sy + 20)], lift=False)
    q.set_pin("Lock", True)
    q.set_pin("PanelTouch", False)
    q.set_pin("Lock", False)
    q.advance(0.5)
    assert picked(q) is None
    assert "Drag a source to a screen" in icon(q) and "Drop on a screen" not in icon(q)


def test_dragdrop_broadcast_flash_skips_the_call_screens_it_skipped():
    q = boot(2, 3)
    q.set_pin("DestName", "Teams Room", 2)
    q.set_pin("Route", 2, 2)
    q.reset_pulses()
    accent2 = q.run("return TouchPad.E.T.accent2")
    sx, sy = centre(q, "S", 1)
    q.double_tap(sx, sy, gap=0.15, panel_touch=True)
    assert routes(q, 3) == [1, 2, 1] and q.pulses("Routed", 2) == 0
    svg = icon(q)
    assert svg.count('fill="%s"' % accent2) == 2                     # screens 1 and 3 glow, not the Teams Room
    assert svg.index('fill="%s"' % accent2) > svg.index(">Screen 1<") - 400
    q.advance(1.0)
    assert 'fill="%s"' % accent2 not in icon(q)                      # the glow is over
    # with AllowCalls off every screen glows
    q.set_pin("AllowCalls", False)
    q.double_tap(sx, sy, gap=0.15, panel_touch=True)
    assert routes(q, 3) == [1, 1, 1]
    assert icon(q).count('fill="%s"' % accent2) == 3


def test_dragdrop_put_down_timer_waits_for_a_resting_finger():
    q = boot(3, 2)
    s1, s2 = centre(q, "S", 1), centre(q, "S", 2)
    q.tap(*s1, panel_touch=True)
    assert picked(q) == 1
    q.advance(7.5)                                                   # the timer is due in ~0.15 s
    q.touch([s2], panel_touch=True, hold=0.55, lift=False)           # a slow press: no tap, no drag
    assert picked(q) == 1                                            # not put down under the finger
    q.lift()
    q.advance(0.6)
    assert picked(q) is None                                         # ... but right after it lifts
    assert q.pin("Gesture")["String"] == "DRAG A SOURCE TO A SCREEN"
    assert 'stroke-width="3"' not in icon(q)
    # a routing tap at that moment keeps the source and restarts the 8 s
    q.tap(*s1, panel_touch=True)
    q.advance(7.5)
    dx, dy = centre(q, "D", 1)
    q.tap(dx, dy, panel_touch=True)
    assert routes(q, 2) == [1, 0] and picked(q) == 1
    q.advance(7)
    assert picked(q) == 1
    q.advance(1.5)
    assert picked(q) is None
