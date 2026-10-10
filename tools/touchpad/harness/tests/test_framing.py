# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Camera Framing mode (14_mode_framing.lua)
"""Draw a box around the next shot: FramePan / FrameTilt (0..1, the frame
centre within the home view), FrameZoom (0 = whole view, 1 = tightest),
Apply (pulses when a shot is sent), Reset (zoom all the way out), Home,
MinFrame, the flips, HFOV and OpticalZoom, the camera controls with a camera
set. A box under 8 % of the pad is ignored; dragging a corner resizes the
box, dragging inside moves it; double tap = zoom out; the view is the widest
16:9 box on the pad; boxes add up."""
import re

from harness import QSys

PLUGIN = "plugins/.build/NikitaTouchPad-framing.qplug"
DEMO = "Demo (simulated)"

MODE_CONTROLS = ["FramePan", "FrameTilt", "FrameZoom", "Apply", "Reset", "Home", "MinFrame",
                 "InvertPan", "InvertTilt", "HFOV", "OpticalZoom"]
CAMERA_CONTROLS = ["ZoomIn", "ZoomOut", "MaxSpeed", "ZoomSpeed", "CameraStatus"]

# the 500 x 500 default pad: card inset 10, view = the widest 16:9 box on it
VX, VY, VW, VH = 10.0, 115.0, 480.0, 270.0
HOME = (0.5, 0.5, 1.0)
HINT = "Draw a box to frame. Double tap = zoom out"


def boot(**kw):
    kw.setdefault("mode", "Camera Framing")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", PLUGIN)
    q = QSys(**kw)
    q.advance(0.2)
    return q


def near(a, b, tol=1e-3):
    return abs(a - b) <= tol


def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


def compose(view, box, min_frame=0.25, oz=12):
    """The frame (cx, cy, fw) a box (pad px) asks for on a view (cx, cy, fw); the
    frame is never tighter than MinFrame or than the camera's reach 1 / OpticalZoom."""
    px, py, pw = view
    if box is None:
        return view
    x0, y0, x1, y1 = box
    f = clamp(max((x1 - x0) / VW, (y1 - y0) / VH), 0.001, 1)
    bx = ((x0 + x1) / 2 - VX) / VW
    by = ((y0 + y1) / 2 - VY) / VH
    fw = min(max(pw * f, min_frame, 1 / oz), 1)
    cx = clamp(px + (bx - 0.5) * pw, fw / 2, 1 - fw / 2)
    cy = clamp(py + (by - 0.5) * pw, fw / 2, 1 - fw / 2)
    return cx, cy, fw


def expect_outputs(q, frame, min_frame=0.25, flip_pan=False, flip_tilt=False, oz=12):
    cx, cy, fw = frame
    pan = 1 - cx if flip_pan else cx
    tilt = cy if flip_tilt else 1 - cy
    lo = max(min_frame, 1 / oz)
    zoom = clamp((1 - fw) / (1 - lo), 0, 1) if lo < 1 else 0
    assert near(q.pin("FramePan")["Value"], pan), (q.pin("FramePan")["Value"], pan)
    assert near(q.pin("FrameTilt")["Value"], tilt), (q.pin("FrameTilt")["Value"], tilt)
    assert near(q.pin("FrameZoom")["Value"], zoom), (q.pin("FrameZoom")["Value"], zoom)


def outputs(q):
    return q.pin("FramePan")["Value"], q.pin("FrameTilt")["Value"], q.pin("FrameZoom")["Value"]


def line(x0, y0, x1, y1, steps=6):
    return [(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps) for i in range(steps + 1)]


def draw_box(q, x0, y0, x1, y1, steps=6, seconds=0.6, **kw):
    """A finger from (x0, y0) to (x1, y1); a certain lift (Panel Touch) applies at once."""
    kw.setdefault("panel_touch", True)
    return q.drag(line(x0, y0, x1, y1, steps), seconds=seconds, **kw)


BOX_RE = re.compile(r'<rect x="([-\d.]+)" y="([-\d.]+)" width="([-\d.]+)" height="([-\d.]+)" rx="2" '
                    r'fill="none" stroke="(#[0-9A-Fa-f]{6})" stroke-width="2"')


def boxes(svg):
    """[(x, y, w, h, stroke)] of every stroked box (the current shot) in the drawing."""
    return [(float(a), float(b), float(c), float(d), e) for a, b, c, d, e in BOX_RE.findall(svg)]


def view_rect(svg, well):
    m = re.search(r'<rect x="([-\d.]+)" y="([-\d.]+)" width="([-\d.]+)" height="([-\d.]+)" rx="2" fill="%s"' % well, svg)
    assert m, "no view box in the drawing"
    return tuple(float(v) for v in m.groups())


def cam(q, code):
    return q.run("local cam = TouchPad.E.camera\n" + code)


def record_camera(q):
    """Every gotoPosition the Demo camera receives, as cam.sent = { {pan, tilt, zoom} }."""
    q.run("""
      local cam = TouchPad.E.camera
      cam.sent = {}
      local orig = cam.gotoPosition
      cam.gotoPosition = function(self, p, t, z) self.sent[#self.sent + 1] = { p, t, z }; return orig(self, p, t, z) end
    """)


def last_sent(q):
    return cam(q, "return #cam.sent, cam.sent[#cam.sent][1], cam.sent[#cam.sent][2], cam.sent[#cam.sent][3]")


def view(q):
    """The view the pad represents: (px, py, pw) within the home view."""
    return q.run("return TouchPad.inst.px, TouchPad.inst.py, TouchPad.inst.pw")


def degrees(frame, hfov=60):
    cx, cy, fw = frame
    return (cx - 0.5) * hfov, (0.5 - cy) * hfov * 9 / 16, clamp((1 / fw - 1) / 11, 0, 1)


def test_framing_controls_pins_and_defaults():
    q = boot()
    names = q.control_names()
    for n in MODE_CONTROLS:
        assert n in names, n
    for n in CAMERA_CONTROLS:
        assert n not in names, n                        # Camera Control = None
    assert len(names) == 26 + len(MODE_CONTROLS)
    assert outputs(q) == (0.5, 0.5, 0)
    assert near(q.pin("MinFrame")["Value"], 0.25) and near(q.pin("HFOV")["Value"], 60)
    assert near(q.pin("OpticalZoom")["Value"], 12)
    assert q.pin("Gesture")["String"] == HINT.upper()
    assert q.run("return TouchPad.E.camera") is None
    assert q.layout_lint([{}, {"Camera Control": DEMO}, {"Camera Control": "VISCA over IP"},
                          {"Pad Width": 120, "Pad Height": 120}, {"Pad Width": 1600, "Pad Height": 1200},
                          {"Pad Width": 1600, "Pad Height": 300}]) == []
    outs = q.run("local l = GetControlLayout({Mode={Value='Camera Framing'}, page_index={Value=3}}) return l")
    seen = {k: v["PrettyName"] for k, v in outs.items() if k in ("FramePan", "FrameZoom", "Apply", "Reset", "Home", "InvertPan")}
    assert seen == {"FramePan": "Camera Framing~Frame Pan", "FrameZoom": "Camera Framing~Frame Zoom",
                    "Apply": "Camera Framing~Apply", "Reset": "Camera Framing~Reset",
                    "Home": "Camera Framing~Home", "InvertPan": "Camera Framing~Invert Pan"}
    setup = q.run("local l = GetControlLayout({Mode={Value='Camera Framing'}, page_index={Value=2}}) return l")
    assert setup["MinFrame"]["PrettyName"] == "Camera Framing~Min Frame"
    assert setup["HFOV"]["PrettyName"] == "Camera~HFOV" and setup["OpticalZoom"]["PrettyName"] == "Camera~Optical Zoom"
    pad = q.run("local l = GetControlLayout({Mode={Value='Camera Framing'}, page_index={Value=1}}) return l")
    assert pad["Reset"]["Legend"] == "ZOOM OUT" and pad["Apply"]["Legend"] == "RESEND"
    with_cam = boot(props={"Camera Control": DEMO})
    for n in CAMERA_CONTROLS + ["CameraView"]:
        assert n in with_cam.control_names(), n
    assert with_cam.run("return TouchPad.E.camera ~= nil") is True


def test_framing_box_frames_the_shot():
    q = boot()
    svg = q.icon()
    assert view_rect(svg, "#0E0D12") == (VX, VY, VW, VH)     # the widest 16:9 box on the pad
    assert boxes(svg) == [] and "FRAME x1.0  PAN +0  TILT +0" in svg
    draw_box(q, 70, 160, 310, 295)                          # 240 x 135: half the view
    assert q.pulses("Apply") == 1 and q.pulses("Press") == 1 and q.pulses("Release") == 1
    frame = compose(HOME, (70, 160, 310, 295))
    assert near(frame[2], 0.5)
    expect_outputs(q, frame)
    assert q.pin("Gesture")["String"] == "APPLY"
    svg = q.icon()
    assert all(ord(ch) < 127 for ch in svg)
    assert boxes(svg) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]
    assert svg.count('width="8" height="8"') == 4           # four corner handles
    assert "FRAME x2.0  PAN -7  TILT +3" in svg              # -7.5 and +2.8 degrees at 60 deg HFOV, rounded half up
    # the box in progress shows the 16:9 shot it asks for and no handles
    q.touch(line(350, 150, 470, 250, 4), dt=0.05, panel_touch=True, lift=False)
    svg = q.icon()
    assert "stroke-dasharray" in svg and 'width="8" height="8"' not in svg
    assert HINT not in svg
    q.lift()
    assert q.pulses("Apply") == 2


def test_framing_small_boxes_and_taps_are_ignored():
    q = boot()
    draw_box(q, 200, 200, 230, 260)                         # 30 px wide: under 8 % of 500
    assert q.pulses("Apply") == 0 and outputs(q) == (0.5, 0.5, 0)
    assert q.pin("Gesture")["String"] == "TOO SMALL" and boxes(q.icon()) == []
    draw_box(q, 100, 200, 300, 230)                         # 30 px high
    assert q.pulses("Apply") == 0 and outputs(q) == (0.5, 0.5, 0)
    q.tap(250, 250, panel_touch=True)
    assert q.pulses("Tap") == 1 and q.pulses("Apply") == 0
    draw_box(q, 100, 200, 300, 240)                         # exactly 40 px high: allowed
    assert q.pulses("Apply") == 1
    # a tap or a jitter inside the box changes nothing
    q.reset_pulses()
    q.tap(200, 220, panel_touch=True)
    q.advance(0.5)                                          # (not a double tap)
    q.touch([(200, 220), (204, 223), (207, 226)], dt=0.05, panel_touch=True)
    assert q.pulses("Apply") == 0 and q.pulses("DoubleTap") == 0
    assert boxes(q.icon()) == [(100.0, 200.0, 200.0, 40.0, "#C513E8")]
    expect_outputs(q, compose(HOME, (100, 200, 300, 240)))


def test_framing_boxes_add_up():
    q = boot()
    a = (70, 160, 310, 295)
    b = (340, 130, 480, 330)                                # starts outside the first box
    draw_box(q, *a)
    first = compose(HOME, a)
    expect_outputs(q, first)
    draw_box(q, *b)
    second = compose(first, b)
    assert q.pulses("Apply") == 2
    expect_outputs(q, second)
    assert near(second[2], 0.5 * 0.7407, 1e-3)
    assert "FRAME x2.7" in q.icon()
    # the pad now represents the first shot: the second box is the only one drawn
    assert len(boxes(q.icon())) == 1 and boxes(q.icon())[0][2] == 140.0
    # a third box keeps adding up
    draw_box(q, 60, 150, 250, 250)
    third = compose(second, (60, 150, 250, 250))
    expect_outputs(q, third)
    assert q.pulses("Apply") == 3


def test_framing_min_frame_limits_the_zoom():
    q = boot()
    q.set_pin("MinFrame", 0.6)
    a = (70, 160, 310, 295)
    draw_box(q, *a)                                         # asks for 0.5 of the view: gets 0.6
    first = compose(HOME, a, 0.6)
    assert near(first[2], 0.6)
    expect_outputs(q, first, 0.6)
    assert near(q.pin("FrameZoom")["Value"], 1.0)
    svg = q.icon()
    assert boxes(svg) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]   # the box stays as drawn
    # ... and a dashed ghost shows the 16:9 frame the camera really got, around the box centre
    assert '<rect x="46" y="146.5" width="288" height="162" fill="none" stroke="#A79FB3" stroke-width="1" opacity="0.8" stroke-dasharray="4 3"' in svg
    # a tighter box cannot zoom further: the frame is the whole view
    b = (380, 250, 470, 330)
    draw_box(q, *b)
    second = compose(first, b, 0.6)
    assert near(second[2], 0.6) and near(q.pin("FrameZoom")["Value"], 1.0)
    expect_outputs(q, second, 0.6)
    assert 'width="480" height="270" fill="none" stroke="#A79FB3"' in q.icon()
    # MinFrame moved while a frame is set: the outputs follow
    q.set_pin("MinFrame", 0.1)
    loose = compose(first, b, 0.1)
    assert near(loose[2], 0.6 * 0.2963, 1e-3)
    expect_outputs(q, loose, 0.1)
    q.advance(0.1)
    # the box is not 16:9: the ghost is now the 16:9 fit around it (142.2 x 80 around (425, 290))
    assert '<rect x="347.8" y="250" width="142.2" height="80" fill="none" stroke="#A79FB3"' in q.icon()
    q.set_pin("MinFrame", 0.25)
    expect_outputs(q, compose(first, b, 0.25), 0.25)
    assert near(q.pin("FrameZoom")["Value"], 1.0)
    draw_box(q, 180, 220, 240, 262)                         # 60 x 42 of a 0.25 view -> clamped to 0.25
    assert near(q.pin("FrameZoom")["Value"], 1.0)
    expect_outputs(q, compose(compose(first, b, 0.25), (180, 220, 240, 262), 0.25), 0.25)


def test_framing_drag_inside_moves_the_box():
    q = boot()
    a = (70, 160, 310, 295)
    draw_box(q, *a)
    q.drag(line(190, 227, 240, 227, 5), seconds=0.5, panel_touch=True)   # 50 px right from the middle
    assert q.pulses("Apply") == 2
    moved = (120, 160, 360, 295)
    assert boxes(q.icon()) == [(120.0, 160.0, 240.0, 135.0, "#C513E8")]
    expect_outputs(q, compose(HOME, moved))
    assert near(q.pin("FrameZoom")["Value"], compose(HOME, a)[2] and (1 - 0.5) / 0.75)
    # the box cannot leave the view
    q.drag(line(240, 227, 600, 300, 6), seconds=0.5, panel_touch=True)
    assert boxes(q.icon()) == [(250.0, 233.0, 240.0, 135.0, "#C513E8")]
    expect_outputs(q, compose(HOME, (250, 233, 490, 368)))
    assert q.pulses("Apply") == 3


def test_framing_drag_corner_resizes_the_box():
    q = boot()
    draw_box(q, 70, 160, 310, 295)
    q.drag(line(310, 295, 360, 322, 5), seconds=0.5, panel_touch=True)  # the bottom-right corner
    assert q.pulses("Apply") == 2
    assert boxes(q.icon()) == [(70.0, 160.0, 290.0, 162.0, "#C513E8")]
    expect_outputs(q, compose(HOME, (70, 160, 360, 322)))
    # dragging the top-left corner past the opposite one flips the box
    q.drag(line(70, 160, 420, 360, 7), seconds=0.5, panel_touch=True)
    assert boxes(q.icon()) == [(360.0, 322.0, 60.0, 40.0, "#C513E8")]
    # a resize never goes under the minimum box
    q.drag(line(420, 360, 365, 330, 5), seconds=0.5, panel_touch=True)
    assert boxes(q.icon()) == [(360.0, 322.0, 40.0, 40.0, "#C513E8")]
    assert q.pulses("Apply") == 4
    expect_outputs(q, compose(HOME, (360, 322, 400, 362)))


def test_framing_double_tap_zooms_out():
    q = boot()
    draw_box(q, 70, 160, 310, 295)
    draw_box(q, 340, 130, 480, 330)
    assert outputs(q) != (0.5, 0.5, 0)
    q.reset_pulses()
    q.double_tap(250, 250, gap=0.15, panel_touch=True)
    assert q.pulses("DoubleTap") == 1 and q.pulses("Reset") == 1 and q.pulses("Apply") == 0
    assert outputs(q) == (0.5, 0.5, 0)
    assert q.pin("Gesture")["String"] == "RESET"
    svg = q.icon()
    assert boxes(svg) == [] and "FRAME x1.0" in svg
    # the next box is relative to the whole view again
    draw_box(q, 70, 160, 310, 295)
    expect_outputs(q, compose(HOME, (70, 160, 310, 295)))


def test_framing_home_reset_and_apply_pins():
    q = boot()
    draw_box(q, 70, 160, 310, 295)
    q.reset_pulses()
    q.set_pin("Home", True)                                 # an external pulse: true then false
    q.set_pin("Home", False)
    assert outputs(q) == (0.5, 0.5, 0) and boxes(q.icon()) == []
    assert q.pulses("Home") == 1 and q.pulses("Reset") == 0  # only the external edge
    assert q.pin("Gesture")["String"] == "HOME"
    draw_box(q, 70, 160, 310, 295)
    q.trigger("Reset")                                      # the Pad page button: handler with Boolean false
    assert outputs(q) == (0.5, 0.5, 0) and q.pin("Gesture")["String"] == "RESET"
    assert q.pulses("Reset") == 0
    draw_box(q, 70, 160, 310, 295)
    q.set_pin("InvertPan", True)
    q.reset_pulses()
    sent = q.run("return TouchPad.inst.applyAt")
    q.advance(1.0)
    q.trigger("Apply")                                      # re-sends the current shot
    assert q.run("return TouchPad.inst.applyAt") > sent and q.pulses("Apply") == 0
    expect_outputs(q, compose(HOME, (70, 160, 310, 295)), flip_pan=True)
    q.set_pin("Apply", True)                                # an external pulse re-sends too
    q.set_pin("Apply", False)
    assert q.pulses("Apply") == 1


def test_framing_flips_mirror_the_outputs():
    q = boot()
    a = (70, 160, 310, 295)
    draw_box(q, *a)
    frame = compose(HOME, a)
    q.set_pin("InvertPan", True)
    q.advance(0.1)
    expect_outputs(q, frame, flip_pan=True)
    assert "FLIP PAN" in q.icon() and "FLIP TILT" not in q.icon()
    q.set_pin("InvertTilt", True)
    q.advance(0.1)
    expect_outputs(q, frame, flip_pan=True, flip_tilt=True)
    assert "FLIP PAN FLIP TILT" in q.icon()
    assert "PAN +8  TILT -3" in q.icon()                    # the degrees mirror too
    q.set_pin("InvertPan", False)
    q.set_pin("InvertTilt", False)
    q.advance(0.1)
    expect_outputs(q, frame)
    assert "FLIP" not in q.icon()


def test_framing_inferred_lift_applies_later_unless_resumed():
    q = boot()
    q.touch(line(70, 160, 310, 295, 6), dt=0.1, lift=False)
    q.advance(0.5)                                          # inferred lift after 0.25 s: the shot is pending
    assert q.pulses("Apply") == 0 and outputs(q) == (0.5, 0.5, 0)
    svg = q.icon()
    assert "SENDING..." in svg and "stroke-dasharray" in svg
    q.touch([(318, 300)], lift=False)                       # resumed near the corner: the lift is taken back
    q.advance(0.15)
    assert "SENDING..." not in q.icon() and q.pulses("Apply") == 0
    q.touch(line(318, 300, 360, 322, 4), dt=0.05, lift=False)   # and the corner follows the finger
    q.advance(0.5)                                          # inferred again
    assert q.pulses("Apply") == 0
    q.advance(1.6)                                          # 1.5 s later the shot goes out
    assert q.pulses("Apply") == 1
    assert boxes(q.icon()) == [(70.0, 160.0, 290.0, 162.0, "#C513E8")]
    expect_outputs(q, compose(HOME, (70, 160, 360, 322)))
    assert "SENDING..." not in q.icon()
    # a resumed finger that does not move still lets the shot out
    q.touch(line(350, 150, 470, 250, 4), dt=0.1, lift=False)
    q.advance(0.5)
    q.touch([(472, 252)], lift=False)                       # resumed, no real movement
    q.advance(0.5)
    assert q.pulses("Apply") == 1
    q.advance(1.6)
    assert q.pulses("Apply") == 2
    # a new touch far away sends a pending shot at once
    q.touch(line(60, 150, 250, 250, 4), dt=0.1, lift=False)
    q.advance(0.5)
    assert q.pulses("Apply") == 2
    q.touch([(400, 350)], lift=False)
    assert q.pulses("Apply") == 3
    q.lift()


def test_framing_demo_camera_frames_the_shot():
    q = boot(props={"Camera Control": DEMO})
    assert "Demo camera" in q.pin("CameraStatus")["String"]
    assert "DEMO CAM" in q.camera_view()
    assert "ZOOM x1.0" in q.icon()
    q.run("""
      local cam = TouchPad.E.camera
      cam.sent = {}
      local orig = cam.gotoPosition
      cam.gotoPosition = function(self, p, t, z) self.sent[#self.sent + 1] = { p, t, z }; return orig(self, p, t, z) end
    """)
    draw_box(q, 70, 160, 310, 295)                          # centre (-7.5, +2.8) deg, zoom factor 2
    sent = cam(q, "return #cam.sent, cam.sent[#cam.sent][1], cam.sent[#cam.sent][2], cam.sent[#cam.sent][3]")
    assert sent[0] == 1 and near(sent[1], -7.5) and near(sent[2], 2.8125) and near(sent[3], 1 / 11)
    q.advance(2.0)
    assert near(cam(q, "return cam.pan"), -7.5, 0.01) and near(cam(q, "return cam.tilt"), 2.8125, 0.01)
    assert near(cam(q, "return cam.zoomPos"), 1 / 11, 1e-6)
    assert "ZOOM x2.0" in q.icon() and "P -8" in q.camera_view()
    # the flips mirror the direction sent to the camera
    q.set_pin("InvertPan", True)
    q.advance(1.0)
    q.trigger("Apply")
    sent = cam(q, "return #cam.sent, cam.sent[#cam.sent][1], cam.sent[#cam.sent][2]")
    assert sent[0] == 2 and near(sent[1], 7.5) and near(sent[2], 2.8125)
    q.set_pin("InvertPan", False)
    # Zoom + from the Pad page: the camera zooms and the pad adopts its view
    q.set_pin("ZoomIn", True)
    q.advance(1.0)                                          # 0.5/s x ZoomSpeed 50 % = 0.25
    q.set_pin("ZoomIn", False)
    q.advance(0.5)
    z = cam(q, "return cam.zoomPos")
    assert near(z, 1 / 11 + 0.25, 0.02)
    factor = 1 + z * 11
    assert "ZOOM x%.1f" % factor in q.icon()
    assert near(q.pin("FrameZoom")["Value"], min(1, (1 - 1 / factor) / 0.75), 1e-3)
    assert near(q.run("return TouchPad.inst.pw"), 1 / factor, 1e-3)
    assert boxes(q.icon()) == []                            # the view is the camera's now
    # the next box is relative to that view
    draw_box(q, 70, 160, 310, 295)                          # half of that view, but never under MinFrame
    fw = max(0.25, 0.5 / factor)
    assert near(cam(q, "return cam.sent[#cam.sent][3]"), min(1, (1 / fw - 1) / 11), 1e-3)
    assert near(q.pin("FrameZoom")["Value"], 1.0)
    # home sends the camera home; double tap zooms it all the way out
    q.set_pin("Home", True)
    q.set_pin("Home", False)
    q.advance(3.0)
    assert near(cam(q, "return cam.pan"), 0, 0.01) and near(cam(q, "return cam.zoomPos"), 0, 1e-6)
    draw_box(q, 70, 160, 310, 295)
    q.advance(2.0)
    assert near(cam(q, "return cam.pan"), -7.5, 0.01)
    q.double_tap(400, 350, gap=0.15, panel_touch=True)
    sent = cam(q, "return cam.sent[#cam.sent][1], cam.sent[#cam.sent][2], cam.sent[#cam.sent][3]")
    assert near(sent[0], 0) and near(sent[1], 0) and near(sent[2], 0)
    q.advance(2.0)
    assert near(cam(q, "return cam.pan"), 0, 0.01) and near(cam(q, "return cam.zoomPos"), 0, 1e-6)
    assert outputs(q) == (0.5, 0.5, 0)


def test_framing_lock_drops_the_gesture_and_stops_the_camera():
    q = boot(props={"Camera Control": DEMO})
    draw_box(q, 70, 160, 310, 295)
    assert q.pulses("Apply") == 1
    q.touch(line(190, 227, 260, 227, 4), dt=0.05, panel_touch=True, lift=False)   # moving the box
    assert boxes(q.icon())[0][0] == 140.0
    q.set_pin("Lock", True)
    q.advance(0.05)
    assert "Locked" in q.icon()
    assert boxes(q.icon()) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]   # the box is back where it was
    assert cam(q, "return cam.target") is None and cam(q, "return cam.panSpeed") == 0
    q.lift()
    assert q.pulses("Apply") == 1
    q.set_pin("Lock", False)
    q.advance(0.05)
    assert "Locked" not in q.icon()
    draw_box(q, 340, 130, 480, 330)                         # the next box works
    assert q.pulses("Apply") == 2


def test_framing_designer_mode():
    q = boot(emulate=True)
    q.drag(line(70, 160, 310, 295, 6), seconds=0.6)         # Designer: no Panel Touch, the lift is inferred
    assert q.pulses("Apply") == 0
    q.advance(1.6)
    assert q.pulses("Apply") == 1
    expect_outputs(q, compose(HOME, (70, 160, 310, 295)))
    assert boxes(q.icon()) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]


def test_framing_view_hints_themes_and_sizes():
    q = boot()
    assert HINT in q.icon()
    q.touch(line(70, 160, 200, 250, 3), dt=0.05, panel_touch=True, lift=False)
    assert HINT not in q.icon()
    q.lift()
    assert HINT in q.icon()
    quiet = boot(props={"Show Hints": False})
    assert HINT not in quiet.icon()
    assert quiet.pin("Gesture")["String"] == HINT.upper()
    light = boot(props={"Theme": "Light", "Background": "Transparent"})
    svg = light.icon()
    assert "#2F6FEB" in svg and svg.count('<rect x="0" y="0"') == 0
    assert view_rect(svg, "#E8EAEE") == (VX, VY, VW, VH)
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300})
    x, y, w, h = view_rect(wide.icon(), "#0E0D12")          # the widest 16:9 box on a 1580 x 280 card
    assert near(w, 280 * 16 / 9, 0.06) and h == 280.0 and y == 10.0 and near(x, 10 + (1580 - w) / 2, 0.1)
    tall = boot(props={"Pad Width": 300, "Pad Height": 1200})
    x, y, w, h = view_rect(tall.icon(), "#0E0D12")
    assert w == 280.0 and near(h, 157.5, 0.06) and x == 10.0 and near(y, 10 + (1180 - 157.5) / 2, 0.1)
    tall.drag(line(20, 530, 280, 680, 5), seconds=0.5, panel_touch=True)   # a box on the tall pad's view
    assert tall.pulses("Apply") == 1
    small = boot(props={"Pad Width": 120, "Pad Height": 120})
    svg = small.icon()
    assert 'viewBox="0 0 120 120"' in svg and all(ord(ch) < 127 for ch in svg)
    small.drag(line(10, 40, 100, 90, 4), seconds=0.4, panel_touch=True)
    assert small.pulses("Apply") == 1 and small.pin("FrameZoom")["Value"] > 0


def test_framing_frames_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30", "Camera Control": DEMO})
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(100)], seconds=2.0, panel_touch=True)
    assert q.pulses("Apply") == 1
    q.set_pin("ZoomIn", True)
    q.drag([(1535 - 12 * i, 1150 - 9 * i) for i in range(100)], seconds=2.0, panel_touch=True)
    q.set_pin("ZoomIn", False)
    q.advance(1.0)
    q.drag([(300 + 10 * i, 300 + 10 * i) for i in range(60)], seconds=1.5, panel_touch=True)
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 15000
    assert len(q.camera_view()) < 20000


def test_framing_resumed_finger_outside_the_box_sends_the_pending_shot_first():
    # Designer flow: the lift is inferred, the shot is pending; the finger comes
    # back outside the box and draws a box that ends too small
    q = boot()
    q.touch(line(70, 160, 310, 295, 6), dt=0.1, lift=False)
    q.advance(0.5)
    assert q.pulses("Apply") == 0 and "SENDING..." in q.icon()
    q.touch([(335, 315)], lift=False)                       # resumed 32 px off the lift, outside the box and
    q.advance(0.15)                                         # its handles: the resumed finger starts a new box
    assert q.pulses("Apply") == 1                           # ... and the pending shot went out first
    assert "SENDING..." not in q.icon() and q.run("return TouchPad.inst.gesture") == "draw"
    q.touch(line(335, 315, 352, 328, 3), dt=0.05, lift=False)
    assert q.pulses("Apply") == 1
    q.advance(2.0)                                          # the new box is too small: ignored
    assert q.pin("Gesture")["String"] == "TOO SMALL" and q.pulses("Apply") == 1
    first = compose(HOME, (70, 160, 310, 295))
    expect_outputs(q, first)
    assert view(q) == HOME                                  # the view was not re-based on the ignored box
    svg = q.icon()
    assert boxes(svg) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")] and "stroke-dasharray" not in svg
    assert "FRAME x2.0  PAN -7  TILT +3" in svg
    # the next box composes on the shot the camera really has
    q.touch(line(340, 130, 480, 330, 5), dt=0.1, lift=False)
    q.advance(2.0)
    assert q.pulses("Apply") == 2
    expect_outputs(q, compose(first, (340, 130, 480, 330)))
    # a resumed finger that draws a big box: the pending shot goes out, then the new one
    q.touch(line(60, 150, 250, 250, 5), dt=0.1, lift=False)
    q.advance(0.5)
    assert q.pulses("Apply") == 2
    q.touch([(272, 270)], lift=False)                       # resumed near the lift, off the 17 px corner handle
    q.touch(line(272, 270, 420, 360, 5), dt=0.05, lift=False)
    assert q.pulses("Apply") == 3 and q.run("return TouchPad.inst.gesture") == "draw"
    q.advance(2.0)
    assert q.pulses("Apply") == 4


def test_framing_zoom_while_a_shot_is_pending_composes_it_on_the_zoomed_view():
    q = boot(props={"Camera Control": DEMO})
    record_camera(q)
    q.touch(line(70, 160, 310, 295, 6), dt=0.1, lift=False)
    q.advance(0.5)                                          # pending
    q.set_pin("ZoomIn", True)
    q.advance(0.4)
    q.set_pin("ZoomIn", False)
    q.advance(0.3)                                          # the pad adopted the camera's zoom
    z = cam(q, "return cam.zoomPos")
    assert z > 0.05
    pw = 1 / (1 + z * 11)
    px, py, got = view(q)
    assert px == 0.5 and py == 0.5 and near(got, pw, 1e-6)
    assert cam(q, "return #cam.sent") == 0 and q.pulses("Apply") == 0
    assert outputs(q) == (0.5, 0.5, 0)                      # nothing claimed before the shot is sent
    svg = q.icon()
    assert "SENDING..." in svg and "stroke-dasharray" in svg
    assert boxes(svg) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]    # the box is still there
    q.advance(1.5)                                          # the pending timer sends it: a region of the zoomed view
    shot = compose((0.5, 0.5, pw), (70, 160, 310, 295))
    n, pan, tilt, zz = last_sent(q)
    pan0, tilt0, z0 = degrees(shot)
    assert n == 1 and near(pan, pan0) and near(tilt, tilt0) and near(zz, z0)
    assert q.pulses("Apply") == 1
    expect_outputs(q, shot)
    q.advance(3.0)
    assert near(cam(q, "return cam.pan"), pan0, 0.01) and near(cam(q, "return cam.zoomPos"), z0, 1e-6)
    assert cam(q, "return #cam.sent") == 1


def test_framing_zoom_while_drawing_is_adopted_at_the_lift():
    q = boot(props={"Camera Control": DEMO})
    record_camera(q)
    q.touch(line(70, 160, 190, 227, 3), dt=0.05, panel_touch=True, lift=False)
    assert q.run("return TouchPad.inst.gesture") == "draw"
    q.set_pin("ZoomIn", True)
    q.advance(0.2)
    q.set_pin("ZoomIn", False)
    q.advance(0.3)
    z = cam(q, "return cam.zoomPos")
    assert z > 0.02
    assert view(q) == HOME                                  # not re-based on the half-drawn box
    q.touch(line(190, 227, 310, 295, 3), dt=0.05, panel_touch=True, lift=False)
    q.lift()
    assert boxes(q.icon()) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]
    pw = 1 / (1 + z * 11)
    assert near(view(q)[2], pw, 1e-6)                       # the box is a region of what the camera saw
    shot = compose((0.5, 0.5, pw), (70, 160, 310, 295))
    n, pan, tilt, zz = last_sent(q)
    pan0, tilt0, z0 = degrees(shot)
    assert n == 1 and near(pan, pan0) and near(tilt, tilt0) and near(zz, z0)
    assert abs(pan0 + 4.84) < 0.3 and abs(tilt0 - 1.81) < 0.2     # not the doubled -15.5 / +7.8
    expect_outputs(q, shot)
    assert q.pulses("Apply") == 1
    # a zoom during a box that ends too small is adopted as the view, the shot kept
    q.touch(line(400, 150, 410, 155, 2), dt=0.05, panel_touch=True, lift=False)
    q.set_pin("ZoomIn", True)
    q.advance(0.2)
    q.set_pin("ZoomIn", False)
    q.advance(0.3)
    q.touch([(418, 162)], dt=0.05, panel_touch=True, lift=False)
    q.lift()
    assert q.pin("Gesture")["String"] == "TOO SMALL" and q.pulses("Apply") == 1
    z2 = cam(q, "return cam.zoomPos")
    assert near(view(q)[2], 1 / (1 + z2 * 11), 1e-6) and boxes(q.icon()) == []
    assert near(view(q)[0], shot[0]) and near(view(q)[1], shot[1])
    assert cam(q, "return #cam.sent") == 1


def test_framing_optical_reach_limits_the_frame():
    q = boot(props={"Camera Control": DEMO})
    record_camera(q)
    q.set_pin("OpticalZoom", 2)                             # a 2x camera: the tightest frame is 0.5
    a = (70, 160, 310, 295)
    draw_box(q, *a)
    first = compose(HOME, a, oz=2)
    assert near(first[2], 0.5) and near(last_sent(q)[3], 1.0)
    expect_outputs(q, first, oz=2)
    assert near(q.pin("FrameZoom")["Value"], 1.0)
    b = (340, 130, 480, 330)
    draw_box(q, *b)                                         # asks for 0.37: the camera cannot
    second = compose(first, b, oz=2)
    assert near(second[2], 0.5) and near(last_sent(q)[3], 1.0)
    expect_outputs(q, second, oz=2)
    svg = q.icon()
    assert "FRAME x2.0" in svg and "ZOOM x2.0" in svg       # the readout never overstates the camera
    assert near(view(q)[2], 0.5)
    c = (60, 150, 250, 250)
    draw_box(q, *c)                                         # composed on the 0.5 view the camera really has
    third = compose(second, c, oz=2)
    n, pan, tilt, zz = last_sent(q)
    assert n == 3 and near(pan, (third[0] - 0.5) * 60) and near(tilt, (0.5 - third[1]) * 60 * 9 / 16) and near(zz, 1.0)
    expect_outputs(q, third, oz=2)
    # a camera without zoom only pans
    q.set_pin("OpticalZoom", 1)
    q.double_tap(400, 350, gap=0.15, panel_touch=True)
    draw_box(q, *a)
    pan_only = compose(HOME, a, oz=1)
    assert pan_only[2] == 1
    n, pan, tilt, zz = last_sent(q)
    assert near(pan, (pan_only[0] - 0.5) * 60) and zz == 0
    expect_outputs(q, pan_only, oz=1)
    assert q.pin("FrameZoom")["Value"] == 0 and "FRAME x1.0" in q.icon()
    # the default 12x camera reaches further than MinFrame: the pad is unchanged
    q.set_pin("OpticalZoom", 12)
    q.set_pin("MinFrame", 0.1)
    expect_outputs(q, compose(HOME, a, 0.1, oz=12), 0.1)


def test_framing_lock_drops_a_pending_shot():
    q = boot()
    q.touch(line(70, 160, 310, 295, 5), dt=0.1, lift=False)
    q.advance(2.0)                                          # applied (a 16:9 box: no ghost frame drawn)
    first = compose(HOME, (70, 160, 310, 295))
    assert q.pulses("Apply") == 1
    q.touch(line(340, 130, 480, 330, 5), dt=0.1, lift=False)
    q.advance(0.5)                                          # pending
    assert "SENDING..." in q.icon()
    q.set_pin("Lock", True)
    q.advance(2.0)
    q.set_pin("Lock", False)
    q.advance(0.05)
    # nothing was sent: the pad is as before the gesture, with the first box
    assert q.pulses("Apply") == 1
    svg = q.icon()
    assert boxes(svg) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]
    assert "stroke-dasharray" not in svg and "SENDING..." not in svg and svg.count('width="8" height="8"') == 4
    expect_outputs(q, first)
    assert view(q) == HOME
    # the first box is still live: dragging inside moves it
    q.touch(line(190, 227, 240, 227, 4), dt=0.1, lift=False)
    q.advance(2.0)
    assert q.pulses("Apply") == 2 and boxes(q.icon()) == [(120.0, 160.0, 240.0, 135.0, "#C513E8")]
    expect_outputs(q, compose(HOME, (120, 160, 360, 295)))
    # a nudge dropped by Lock after the pad re-based mid-draw: view and box come back too
    q.touch(line(400, 150, 430, 170, 3), dt=0.1, lift=False)
    assert view(q) != HOME                                  # re-based on the current shot while drawing
    q.set_pin("Lock", True)
    q.advance(2.0)
    q.set_pin("Lock", False)
    q.advance(0.05)
    assert view(q) == HOME and boxes(q.icon()) == [(120.0, 160.0, 240.0, 135.0, "#C513E8")]
    assert q.pulses("Apply") == 2


def test_framing_apply_pin_sends_a_pending_shot_once():
    q = boot(props={"Camera Control": DEMO})
    record_camera(q)
    q.touch(line(70, 160, 310, 295, 6), dt=0.1, lift=False)
    q.advance(0.5)                                          # pending
    q.set_pin("Apply", True)
    q.set_pin("Apply", False)
    assert cam(q, "return #cam.sent") == 1 and q.pulses("Apply") == 1
    svg = q.icon()
    assert "SENDING..." not in svg and "stroke-dasharray" not in svg
    expect_outputs(q, compose(HOME, (70, 160, 310, 295)))
    q.advance(2.0)                                          # the pending timer was cancelled
    assert cam(q, "return #cam.sent") == 1 and q.pulses("Apply") == 1
    # the RESEND button does the same
    q.touch(line(340, 130, 480, 330, 5), dt=0.1, lift=False)
    q.advance(0.5)
    q.trigger("Apply")
    assert cam(q, "return #cam.sent") == 2
    q.advance(2.0)
    assert cam(q, "return #cam.sent") == 2 and q.pulses("Apply") == 1


def test_framing_too_small_box_keeps_the_previous_box():
    q = boot()
    a = (70, 160, 310, 295)
    draw_box(q, *a)
    first = compose(HOME, a)
    draw_box(q, 400, 150, 420, 165)                         # 20 x 15: ignored
    assert q.pin("Gesture")["String"] == "TOO SMALL" and q.pulses("Apply") == 1
    expect_outputs(q, first)
    assert view(q) == HOME                                  # the view was not re-based
    svg = q.icon()
    assert boxes(svg) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")] and svg.count('width="8" height="8"') == 4
    # the first box can still be moved and resized
    q.drag(line(190, 227, 240, 227, 5), seconds=0.5, panel_touch=True)
    assert boxes(q.icon()) == [(120.0, 160.0, 240.0, 135.0, "#C513E8")] and q.pulses("Apply") == 2
    expect_outputs(q, compose(HOME, (120, 160, 360, 295)))
    q.drag(line(360, 295, 400, 320, 5), seconds=0.5, panel_touch=True)
    assert boxes(q.icon()) == [(120.0, 160.0, 280.0, 160.0, "#C513E8")] and q.pulses("Apply") == 3
    # the same after boxes added up: the view stays the one of the last shot
    draw_box(q, 340, 130, 480, 330)
    second = compose(compose(HOME, (120, 160, 400, 320)), (340, 130, 480, 330))
    expect_outputs(q, second)
    v = view(q)
    draw_box(q, 60, 150, 75, 160)
    assert q.pin("Gesture")["String"] == "TOO SMALL" and view(q) == v
    expect_outputs(q, second)
    assert boxes(q.icon())[0][:4] == (340.0, 130.0, 140.0, 200.0)


def test_framing_resize_keeps_the_anchored_corner():
    q = boot()
    draw_box(q, 20, 160, 100, 220)                          # 10 px from the view's left edge
    assert boxes(q.icon()) == [(20.0, 160.0, 80.0, 60.0, "#C513E8")]
    # the bottom-right corner dragged past the anchored left edge: the box flips
    # to the other side of the anchor at the minimum width, the anchor stays
    q.drag(line(100, 220, 12, 230, 5), seconds=0.5, panel_touch=True)
    assert boxes(q.icon()) == [(20.0, 160.0, 40.0, 70.0, "#C513E8")]
    assert q.pulses("Apply") == 2
    expect_outputs(q, compose(HOME, (20, 160, 60, 230)))
    # the same at the view's right and bottom edges
    draw_box(q, 400, 300, 480, 380)
    q.drag(line(400, 300, 488, 384, 5), seconds=0.5, panel_touch=True)   # top-left corner to beyond the anchor
    assert boxes(q.icon()) == [(440.0, 340.0, 40.0, 40.0, "#C513E8")]
    # a corner dragged well outside the view just stops at its edge
    q.drag(line(440, 340, 0, 0, 5), seconds=0.5, panel_touch=True)
    assert boxes(q.icon()) == [(10.0, 115.0, 470.0, 265.0, "#C513E8")]
    assert q.pulses("Apply") == 5


def test_framing_held_trigger_pins_count_once():
    q = boot(props={"Camera Control": DEMO})
    record_camera(q)
    q.set_pin("Home", True)                                 # held
    q.advance(0.3)
    draw_box(q, 70, 160, 310, 295)
    assert q.pulses("Apply") == 1 and len(boxes(q.icon())) == 1
    q.advance(0.5)
    q.set_pin("Home", False)                                # released long after: not a second Home
    first = compose(HOME, (70, 160, 310, 295))
    assert boxes(q.icon()) == [(70.0, 160.0, 240.0, 135.0, "#C513E8")]
    expect_outputs(q, first)
    assert q.pin("Gesture")["String"] == "APPLY"
    q.trigger("Home")                                       # a Pad page press still works
    assert boxes(q.icon()) == [] and outputs(q) == (0.5, 0.5, 0) and q.pin("Gesture")["String"] == "HOME"
    # Reset held
    draw_box(q, 70, 160, 310, 295)
    q.set_pin("Reset", True)
    q.advance(2.0)
    draw_box(q, 70, 160, 310, 295)
    q.set_pin("Reset", False)
    assert q.pin("Gesture")["String"] == "APPLY" and len(boxes(q.icon())) == 1
    expect_outputs(q, first)
    # Apply held: one send, not one per edge
    n0 = cam(q, "return #cam.sent")
    q.set_pin("Apply", True)
    q.advance(1.0)
    q.set_pin("Apply", False)
    assert cam(q, "return #cam.sent") == n0 + 1
    q.trigger("Apply")
    assert cam(q, "return #cam.sent") == n0 + 2
    # a plain pulse still counts once and the trailing edge never again
    q.set_pin("Reset", True)
    q.set_pin("Reset", False)
    assert outputs(q) == (0.5, 0.5, 0) and q.pin("Gesture")["String"] == "RESET"
