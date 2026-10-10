# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: every mode at its extreme property values
"""Boots every mode with the largest and the smallest pad, the largest
counts (Sources 64, Destinations 64, Zones 32, GridSize 5, Speakers 7.1),
every Theme, every Background and every Camera Control, then drags across
the pad and draws a zig-zag stroke, taps and double taps. Every scenario
asserts the instruction budgets (120,000 per handler, 60,000 per frame),
that the SVG stays under 60,000 characters and ASCII, and that the mode
never reports a recovered error. The layout lint runs over the same
extremes for every page of every mode."""
import os

from harness import QSys, DEFAULT_PLUGIN

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
PLUGIN = os.environ.get("TOUCHPAD_PLUGIN", "") or DEFAULT_PLUGIN

MODES = ["XY Pad", "Swipe Layer", "Joystick", "PTZ Pad", "Camera Framing", "Dial", "Knob", "Fader", "Panner",
         "Zone Select", "Drag & Drop", "Matrix", "Pattern Lock", "Keypad", "Sign-In", "Whiteboard"]
CAMERA_MODES = ["Joystick", "PTZ Pad", "Camera Framing", "Dial"]
THEMES = ["Nikita", "Sunset", "Ocean", "Light", "Custom"]
BACKGROUNDS = ["Solid", "Transparent", "Panel"]
CAMERAS = ["None", "Demo (simulated)", "Q-SYS Camera", "VISCA over IP"]
SVG_LIMIT = 60000
LARGE = {"Pad Width": 1600, "Pad Height": 1200}
SMALL = {"Pad Width": 120, "Pad Height": 120}

# The largest value of every count-like property, per mode (unknown names are not sent).
EXTREME_PROPS = {
    "Zone Select": {"Zones": 32},
    "Drag & Drop": {"Sources": 64, "Destinations": 64},
    "Matrix": {"Sources": 64, "Destinations": 64},
    "Panner": {"Speakers": "7.1"},
    "Fader": {"Orientation": "Horizontal"},
    "Sign-In": {"Sign-In Webhook": "JSON"},
}
# Controls set after boot that enlarge the drawing.
EXTREME_PINS = {
    "Pattern Lock": [("GridSize", 5)],
    "Keypad": [("Masked", True)],
}
CUSTOM_COLOURS = {"Accent Color": "#FF8800", "Background Color": "#102030", "Text Color": "#F0F0F0"}


def boot(mode, props=None, **kw):
    p = dict(EXTREME_PROPS.get(mode, {}))
    if props:
        p.update(props)
    if p.get("Theme") == "Custom":
        p.update(CUSTOM_COLOURS)
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(mode=mode, props=p, **kw)
    q.advance(0.2)
    for name, value in EXTREME_PINS.get(mode, []):
        q.set_pin(name, value)
        q.advance(0.1)
    return q


def icon(q):
    """The pad drawing once the frame-rate cap has let the pending frame out."""
    q.advance(0.1)
    return q.icon()


def check_svg(q, label):
    svg = icon(q)
    assert svg is not None, label + ": no drawing"
    assert svg.startswith("<svg") and svg.rstrip().endswith("</svg>"), label + ": not an SVG"
    assert len(svg) < SVG_LIMIT, "%s: SVG is %d characters" % (label, len(svg))
    assert all(ord(ch) < 127 for ch in svg), label + ": non-ASCII in the SVG"
    assert q.run("return TouchPad.state ~= nil") is True
    view = q.camera_view() if q.has_control("CameraView") else None
    if view is not None:
        assert len(view) < SVG_LIMIT and all(ord(ch) < 127 for ch in view), label + ": camera view too large"
    return svg


def check_health(q, label):
    status = q.status() or ""
    assert not status.startswith("Recovered"), "%s: %s" % (label, status)
    assert not q.errors, "%s: %s" % (label, q.errors[-1][1].splitlines()[0] if q.errors else "")
    return q.budget()                                                # raises BudgetError above the limits


def drag_across(q, label):
    """A drag from near the top-left corner to near the bottom-right one, then a lift."""
    W, H = q.pad_size
    pts = [(W * 0.05 + W * 0.9 * i / 12, H * 0.05 + H * 0.9 * i / 12) for i in range(13)]
    q.drag(pts, seconds=0.6, lift=False)
    check_svg(q, label + " mid-drag")
    q.lift()
    q.advance(2.0)
    check_svg(q, label + " after the drag")


def draw_zigzag(q, label, rows=10):
    """A zig-zag stroke with many points (a drawing on Sign-In, Whiteboard, Pattern Lock; a paint
    on Zone Select and Matrix; a long drag everywhere else)."""
    W, H = q.pad_size
    pts = [(W * (0.1 + 0.8 * (i % 2)), H * (0.1 + 0.8 * i / (2 * rows))) for i in range(2 * rows + 1)]
    q.drag(pts, seconds=1.2)
    q.advance(2.0)
    check_svg(q, label + " after the draw")


def exercise(q, label, full=True):
    check_svg(q, label + " idle")
    drag_across(q, label)
    if full:
        draw_zigzag(q, label)
        W, H = q.pad_size
        q.tap(W / 2, H / 2)
        q.advance(2.0)
        q.double_tap(W * 0.3, H * 0.7)
        q.advance(2.0)
        q.swipe(W * 0.1, H / 2, W * 0.9, H / 2, seconds=0.2)
        q.advance(2.0)
        check_svg(q, label + " after taps and a swipe")
        q.set_pin("Lock", True)
        check_svg(q, label + " locked")
        q.set_pin("Lock", False)
        check_svg(q, label + " unlocked")
    return check_health(q, label)


# ---------------------------------------------------------------- pad sizes

def test_extremes_large_pad_drag_and_draw_in_every_mode():
    for mode in MODES:
        q = boot(mode, LARGE)
        assert q.pad_size == (1600, 1200)
        exercise(q, mode + " 1600x1200")
        q.close()


def test_extremes_small_pad_drag_and_draw_in_every_mode():
    for mode in MODES:
        q = boot(mode, SMALL)
        assert q.pad_size == (120, 120)
        exercise(q, mode + " 120x120")
        q.close()


def test_extremes_large_pad_in_designer_geometry():
    for mode in MODES:
        q = boot(mode, LARGE, emulate=True)
        exercise(q, mode + " 1600x1200 designer", full=False)
        q.close()


# ---------------------------------------------------------------- themes and backgrounds

def test_extremes_every_theme_in_every_mode():
    for mode in MODES:
        for theme in THEMES:
            q = boot(mode, {"Theme": theme})
            label = "%s theme %s" % (mode, theme)
            check_svg(q, label)
            if theme == "Custom":
                assert q.run("return TouchPad.E.T.accent") == "#FF8800", label + ": custom accent not applied"
                assert q.run("return TouchPad.E.T.bg") == "#102030", label + ": custom background not applied"
            exercise(q, label, full=False)
            q.close()


def test_extremes_every_background_in_every_mode():
    for mode in MODES:
        for background in BACKGROUNDS:
            q = boot(mode, dict(LARGE, Background=background))
            exercise(q, "%s background %s" % (mode, background), full=False)
            q.close()


# ---------------------------------------------------------------- cameras

def test_extremes_every_camera_control_in_every_camera_mode():
    for mode in CAMERA_MODES:
        for camera in CAMERAS:
            props = dict(LARGE)
            props["Camera Control"] = camera
            if camera == "Q-SYS Camera":
                props["Camera Name"] = "Cam1"
            q = boot(mode, props)
            if camera == "Q-SYS Camera":
                q.add_component("Cam1", "camera_controller",
                                controls={"pan.left": {"Boolean": False}, "pan.right": {"Boolean": False},
                                          "tilt.up": {"Boolean": False}, "tilt.down": {"Boolean": False},
                                          "zoom.in": {"Boolean": False}, "zoom.out": {"Boolean": False},
                                          "pan.speed": {"Value": 0.5, "Min": 0, "Max": 1},
                                          "tilt.speed": {"Value": 0.5, "Min": 0, "Max": 1},
                                          "zoom.speed": {"Value": 0.5, "Min": 0, "Max": 1}})
                q.set_pin("Refresh", True)
                q.advance(0.5)
            label = "%s camera %s" % (mode, camera)
            assert q.has_control("CameraView") == (camera == "Demo (simulated)"), label
            assert q.has_control("CameraIP") == (camera == "VISCA over IP"), label
            assert q.has_control("ZoomIn") == (camera != "None"), label
            if camera != "None":
                q.set_pin("ZoomIn", True)
                q.advance(0.3)
                q.set_pin("ZoomIn", False)
                q.advance(0.3)
                q.set_pin("Home", True) if q.has_control("Home") else None
                q.advance(1.0)
            exercise(q, label)
            if camera == "Demo (simulated)":
                assert q.camera_view() is not None and "<svg" in q.camera_view(), label + ": no camera view"
            q.close()


# ---------------------------------------------------------------- counts

def test_extremes_largest_counts_fill_every_page_and_pin():
    q = boot("Drag & Drop", LARGE)
    assert len(q.run("return TouchPad.E.ctls('SourceName')")) == 64 and len(q.run("return TouchPad.E.ctls('Route')")) == 64
    for i in range(1, 65):
        q.set_pin("SourceName", "Laptop %d with a rather long name" % i, i)
        q.set_pin("DestName", "Display %d in the far room" % i, i)
    exercise(q, "Drag & Drop 64x64 named")
    q.close()
    q = boot("Matrix", LARGE)
    assert len(q.run("return TouchPad.E.ctls('Cross')")) == 64 * 64
    for i in range(1, 65):
        q.set_pin("SourceName", "Source %d" % i, i)
        q.set_pin("DestName", "Destination %d" % i, i)
    for i in range(1, 65):
        q.set_pin("Route", 64 - (i % 64), i)
    exercise(q, "Matrix 64x64 routed")
    q.close()
    q = boot("Zone Select", LARGE)
    assert len(q.run("return TouchPad.E.ctls('ZoneSelected')")) == 32
    for i in range(1, 33):
        q.set_pin("ZoneName", "Zone %d of thirty-two" % i, i)
    q.set_pin("SelectAll", True)
    q.advance(0.3)
    exercise(q, "Zone Select 32 named")
    q.close()
    q = boot("Panner", LARGE)
    assert len(q.run("return TouchPad.E.ctls('SpeakerGain')")) == 8
    exercise(q, "Panner 7.1")
    q.close()
    q = boot("Pattern Lock", LARGE)
    assert q.pin("GridSize")["Value"] == 5
    q.set_pin("Pattern", "1-2-3-4-5-10-15-20-25")
    exercise(q, "Pattern Lock 5x5")
    q.close()


# ---------------------------------------------------------------- layout lint

def test_extremes_layout_lint_every_mode():
    matrix = [{}, dict(LARGE), dict(SMALL),
              {"Zones": 32, "Sources": 64, "Destinations": 64},
              dict(LARGE, Zones=32, Sources=64, Destinations=64),
              dict(SMALL, Zones=32, Sources=64, Destinations=64),
              {"Speakers": "7.1"}, {"Orientation": "Horizontal"}]
    for theme in THEMES:
        entry = {"Theme": theme}
        if theme == "Custom":
            entry.update(CUSTOM_COLOURS)
        matrix.append(entry)
    for background in BACKGROUNDS:
        matrix.append({"Background": background})
    for camera in CAMERAS:
        matrix.append({"Camera Control": camera})
    for mode in MODES:
        q = QSys(mode=mode, plugin=PLUGIN, picker=None, runtime=False)
        names = set(q.control_names())
        problems = q.layout_lint(matrix=matrix)
        assert problems == [], "%s: %s" % (mode, problems[:5])
        assert names, mode
        q.close()
