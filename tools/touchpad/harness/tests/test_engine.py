# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the engine (50_runtime.lua) in the XY Pad mode
"""Touch state machine, gestures, picker binding, calibration, lock, frames,
status and the error guard, all through the built plugin."""
import math

from harness import QSys


def boot(**kw):
    """A started engine: spec 14.4 arms the handlers 0.1 s after load."""
    kw.setdefault("mode", "XY Pad")
    kw.setdefault("picker", "Color_Picker")
    q = QSys(**kw)
    q.advance(0.2)
    return q


def probe(q, method, counter):
    """Wraps a mode instance method so each call bumps a Lua global counter."""
    q.run('local orig = TouchPad.inst["%s"]; %s = 0; TouchPad.inst["%s"] = function(self, ...) %s = %s + 1; '
          'if orig then return orig(self, ...) end end' % (method, counter, method, counter, counter))


def near(a, b, tol=1e-6):
    return abs(a - b) <= tol


# ------------------------------------------------------------------ start

def test_start_state():
    q = boot()
    assert q.status().startswith("OK - Ready. Picker OK: saturation / value")
    assert q.pin("Status")["Value"] == 0
    assert q.pin("Display")["IsDisabled"] is True
    assert q.icon().startswith("<svg") and q.icons >= 1
    assert q.pin("Touching")["Boolean"] is False
    assert q.pin("Gesture")["String"] == "DRAG ANYWHERE"
    assert "955 x 524" in q.pin("PickerLayout")["String"]
    assert q.output()[0].startswith("Nikita Visual Arts Touch Pad")
    assert q.instructions("load") < 120000


def test_handlers_unarmed_until_start_delay():
    q = QSys(mode="XY Pad", picker="Color_Picker")
    q.picker.set(0.5, 0.5, force=True)            # a start-up echo before the arming delay
    q.advance(0.05)
    assert q.pulses("Press") == 0 and q.pin("Touching")["Boolean"] is False
    q.advance(0.2)
    q.tap(250, 250)
    assert q.pulses("Tap") == 1


# ---------------------------------------------------------------- gestures

def test_tap_pulses_and_outputs():
    q = boot()
    q.tap(250, 125)
    assert q.pulses("Tap") == 1 and q.pulses("Press") == 1 and q.pulses("Release") == 1
    assert near(q.pin("X")["Value"], 0.5) and near(q.pin("Y")["Value"], 0.75)
    assert q.pin("Gesture")["String"] == "TAP"
    assert q.pin("Touching")["Boolean"] is False
    assert q.pulses("DoubleTap") == 0 and q.pulses("LongPress") == 0


def test_double_tap_pulses_tap_for_both_taps():
    q = boot()
    q.double_tap(200, 200, gap=0.15, panel_touch=True)
    assert q.pulses("Tap") == 2 and q.pulses("DoubleTap") == 1
    assert q.pin("Gesture")["String"] == "DOUBLE TAP"
    q.reset_pulses()
    q.advance(1.0)
    q.tap(200, 200, panel_touch=True)              # a third tap long after is a plain tap
    assert q.pulses("Tap") == 1 and q.pulses("DoubleTap") == 0
    # Without Panel Touch (a separate install) the lifts are inferred: the gap must pass
    # ReleaseTime, and a second tap within 6 px of the first reads as the finger peeling
    # off (test_press_hold_shift_is_one_contact), so the taps sit a finger's width apart.
    q2 = boot()
    q2.touch([(200, 200)], silence=0.3)
    q2.tap(210, 200)
    assert q2.pulses("Tap") == 2 and q2.pulses("DoubleTap") == 1


def test_two_quick_taps_far_apart_are_two_taps():
    q = boot()
    q.tap(100, 100, panel_touch=True, silence=0.15)
    q.tap(400, 400, panel_touch=True)
    assert q.pulses("Tap") == 2 and q.pulses("DoubleTap") == 0


def test_long_press_needs_panel_touch():
    q = boot()
    q.long_press(200, 200, seconds=1.0)            # panel_touch=True by default
    assert q.pulses("LongPress") == 1 and q.pulses("Tap") == 0
    assert q.pin("Gesture")["String"] == "LONG PRESS"
    assert q.pulses("Release") == 1
    q2 = boot()                                    # an install without Panel Touch
    q2.touch([(300, 300)], hold=1.0)               # a resting finger reads as a lift
    assert q2.pulses("LongPress") == 0 and q2.pulses("Release") == 1
    assert q2.pulses("Tap") == 1                   # ... and so as a tap


def test_drag_reports_position_distance_angle():
    q = boot()
    pts = [(100 + 30 * i, 400 - 30 * i) for i in range(11)]          # (100,400) -> (400,100)
    q.drag(pts, seconds=1.0)
    assert near(q.pin("X")["Value"], 0.8) and near(q.pin("Y")["Value"], 0.8)
    diag = math.sqrt(500 ** 2 + 500 ** 2)
    assert near(q.pin("DragDistance")["Value"], math.sqrt(300 ** 2 + 300 ** 2) / diag, 1e-6)
    assert near(q.pin("DragAngle")["Value"], 45.0, 1e-6)
    assert q.pin("Gesture")["String"] == "DRAG"
    assert q.pulses("Tap") == 0 and q.pulses("Press") == 1 and q.pulses("Release") == 1
    for name in ("SwipeLeft", "SwipeRight", "SwipeUp", "SwipeDown"):
        assert q.pulses(name) == 0


def test_swipes_in_four_directions():
    q = boot()
    cases = [((100, 250, 400, 250), "SwipeRight", "SWIPE RIGHT"), ((400, 250, 100, 250), "SwipeLeft", "SWIPE LEFT"),
             ((250, 400, 250, 100), "SwipeUp", "SWIPE UP"), ((250, 100, 250, 400), "SwipeDown", "SWIPE DOWN")]
    for (x1, y1, x2, y2), pin, text in cases:
        q.reset_pulses()
        q.swipe(x1, y1, x2, y2, seconds=0.2)
        q.advance(2.0)                             # past the resume window of the drag
        assert q.pulses(pin) == 1, pin
        assert q.pin("Gesture")["String"] == text
        assert q.pulses("Tap") == 0
        others = [p for p in ("SwipeLeft", "SwipeRight", "SwipeUp", "SwipeDown") if p != pin]
        assert all(q.pulses(p) == 0 for p in others)


def test_slow_or_short_drag_is_not_a_swipe():
    q = boot()
    q.swipe(100, 250, 400, 250, seconds=1.0, steps=10)                # too slow
    assert q.pulses("SwipeRight") == 0 and q.pin("Gesture")["String"] == "DRAG"
    q.advance(2.0)
    q.swipe(200, 250, 260, 250, seconds=0.1, steps=3)                 # too short (60 px of a 707 px diagonal)
    assert q.pulses("SwipeRight") == 0
    q.advance(2.0)
    q.swipe(100, 100, 400, 400, seconds=0.2)                          # diagonal: no dominant axis
    assert all(q.pulses(p) == 0 for p in ("SwipeLeft", "SwipeRight", "SwipeUp", "SwipeDown"))


def test_inferred_lift_then_resume():
    q = boot()
    probe(q, "onTouchResume", "RESUMED")
    q.touch([(100, 100), (150, 150), (200, 200)], dt=0.05, lift=False)
    assert q.pin("Touching")["Boolean"] is True and q.pulses("Press") == 1
    q.advance(0.5)                                                    # silence past ReleaseTime
    assert q.pin("Touching")["Boolean"] is False and q.pulses("Release") == 1
    q.touch([(210, 210), (240, 240)], dt=0.05, lift=False)            # within 1.5 s, near the last spot
    assert q.run("return RESUMED") == 1
    assert q.pin("Touching")["Boolean"] is True
    assert q.pulses("Press") == 1                                     # no second press
    q.lift()
    assert q.pulses("Release") == 1                                   # and no second release
    assert q.pin("Touching")["Boolean"] is False
    assert near(q.pin("X")["Value"], 0.48)


def test_release_time_knob_governs_inference():
    q = boot()
    q.touch([(100, 100), (150, 150)], lift=False)
    q.advance(0.6)
    assert q.pin("Touching")["Boolean"] is False                      # default 0.25 s
    q.lift()
    q.advance(2.0)
    q.set_pin("ReleaseTime", 1.0)
    q.touch([(300, 300), (350, 350)], lift=False)
    q.advance(0.6)
    assert q.pin("Touching")["Boolean"] is True                       # 1.0 s not yet passed
    q.lift()
    assert q.pin("Touching")["Boolean"] is False


# ------------------------------------------------------------- panel touch

def test_panel_touch_press_release_exact_and_late_reports_dropped():
    q = boot()
    q.touch([(100, 100)], panel_touch=True, lift=False)
    assert q.pulses("Press") == 1 and q.pin("Touching")["Boolean"] is True
    q.advance(2.0)                                                    # no silence lift with Panel Touch
    assert q.pin("Touching")["Boolean"] is True and q.pulses("Release") == 0
    q.lift()
    assert q.pin("PanelTouch")["Boolean"] is False
    assert q.pin("Touching")["Boolean"] is False and q.pulses("Release") == 1
    q.advance(0.2)
    q.picker.set(0.3, 0.3, force=True)                                # a report after the release
    q.advance(0.3)
    assert q.pulses("Press") == 1 and q.pin("Touching")["Boolean"] is False


def test_report_that_beats_its_own_down_still_lands():
    q = boot()
    q.set_pin("PanelTouch", True)
    q.set_pin("PanelTouch", False)
    q.advance(0.5)
    q.picker.set(0.5, 0.25, force=True)                               # the report comes first
    q.advance(0.02)
    assert q.pulses("Press") == 0
    q.set_pin("PanelTouch", True)                                     # then its down
    assert q.pulses("Press") == 1
    assert near(q.pin("X")["Value"], 0.5) and near(q.pin("Y")["Value"], 0.25)
    q.set_pin("PanelTouch", False)
    assert q.pulses("Release") == 1


def test_panel_touch_without_a_report_is_ignored():
    q = boot()
    q.set_pin("PanelTouch", True)                                     # a touch outside the picker
    q.advance(0.3)
    q.set_pin("PanelTouch", False)
    q.advance(0.3)
    assert q.pulses("Press") == 0 and q.pulses("Release") == 0


def test_stuck_guard_releases_after_30_s():
    q = boot()
    q.touch([(100, 100)], panel_touch=True, lift=False)
    q.advance(29.0)
    assert q.pin("Touching")["Boolean"] is True
    q.advance(2.0)
    assert q.pin("Touching")["Boolean"] is False and q.pulses("Release") == 1


# --------------------------------------------------------------- geometry

def test_touch_outside_the_pad_is_ignored_and_stays_ignored():
    q = boot(emulate=True)                                            # Designer: the pad is the left 4/7
    q.tap(600, 250)
    assert q.pulses("Tap") == 0 and q.pulses("Press") == 0
    q.advance(1.0)
    q.touch([(600, 250), (450, 250), (300, 250), (200, 250)], dt=0.08)   # slides onto the pad
    assert q.pulses("Press") == 0 and q.pin("Touching")["Boolean"] is False
    q.advance(1.0)
    q.tap(300, 250)                                                   # a new touch on the pad works
    assert q.pulses("Tap") == 1


def test_park_after_lift_and_echo_ignored():
    q = boot(props={"Debug Print": "All"})
    q.touch([(100, 400)], lift=False)
    assert all(near(p, 0.2) for p in q.picker.position)
    q.advance(0.5)                                                    # the lift is inferred; not parked yet
    assert q.pin("Touching")["Boolean"] is False and all(near(p, 0.2) for p in q.picker.position)
    q.advance(0.5)
    assert q.picker.position == (0.0, 0.0)
    q.lift()
    assert any("park echo ignored" in line for line in q.output())
    assert q.pulses("Press") == 1 and q.pin("Touching")["Boolean"] is False
    assert q.pin("Gesture")["String"] == "TAP"
    q.tap(100, 400)                                                   # the same spot again works
    assert q.pulses("Tap") == 2


def test_designer_axis_split_lands_at_the_first_point():
    q = boot(emulate=True, props={"Debug Print": "All"})
    assert q.touch_mode == "designer"
    q.touch([(300, 100)], lift=False)
    starts = [line for line in q.output() if line.startswith("touch start")]
    assert starts == ["touch start 300.0 100.0 t=0.260"], starts   # the y axis arrived 0.06 s after x
    assert near(q.pin("X")["Value"], 0.6) and near(q.pin("Y")["Value"], 0.8)
    q.lift()


def test_lone_axis_landing_presses_after_the_pairing_window():
    q = boot(emulate=True)
    q.advance(1.0)
    q.touch([(300, 500)], lift=False)                                 # v stays at the park value
    assert q.pulses("Press") == 0                                     # one axis so far: waiting
    q.advance(0.15)
    assert q.pulses("Press") == 1
    assert near(q.pin("X")["Value"], 0.6) and near(q.pin("Y")["Value"], 0.0)
    q.lift()


def test_swap_and_flip_properties():
    q = boot(props={"Flip X": True})
    q.tap(100, 250)
    assert near(q.pin("X")["Value"], 0.8)
    q2 = boot(props={"Swap Axes": True})
    q2.tap(100, 400)                                                  # u = 0.2, v = 0.2: symmetric point
    assert near(q2.pin("X")["Value"], 0.2) and near(q2.pin("Y")["Value"], 0.2)
    q2.advance(1.0)
    q2.tap(100, 250)                                                  # u = 0.2, v = 0.5 -> swapped
    assert near(q2.pin("X")["Value"], 0.5) and near(q2.pin("Y")["Value"], 0.2)


# ------------------------------------------------------------ calibration

def test_calibration_two_taps_produce_a_line_and_apply():
    q = boot()
    q.calibration = (0.1, 0.1, 0.8, 0.8)                              # the panel maps the pad to a smaller square
    q.set_pin("Calibrate", True)
    assert "Calibration" in q.status() and "targets" not in q.status()
    svg = q.icon()
    assert "Calibration: Tap the top-left target" in svg
    q.tap(60, 60)
    assert "bottom-right" in q.status()
    q.tap(440, 440)
    line = q.pin("Calibration")["String"]
    assert line.startswith("P "), line
    x0, y0, w, h = [float(v) for v in line.split()[1:]]
    assert near(x0, 0.1, 1e-3) and near(y0, 0.1, 1e-3) and near(w, 0.8, 1e-3) and near(h, 0.8, 1e-3)
    assert q.pin("Calibrate")["Boolean"] is False
    assert q.status().startswith("Calibrated: P")
    assert q.pulses("Tap") == 0                                       # calibration taps are not gestures
    q.advance(1.0)
    q.tap(250, 125)
    assert near(q.pin("X")["Value"], 0.5, 1e-3) and near(q.pin("Y")["Value"], 0.75, 1e-3)


def test_calibration_designer_line_and_text_edit():
    q = boot(emulate=True)
    q.set_pin("Calibrate", True)
    q.tap(60, 60)
    q.advance(1.0)
    q.tap(440, 440)
    assert q.pin("Calibration")["String"].startswith("D ")
    q.advance(1.0)
    q.set_pin("Calibration", "D 0.0 0.0 0.2857 1.0")                   # pad = left 2/7 of the surface
    q.tap(250, 250)                                                   # finger at u = 2/7, the pad's right edge
    assert near(q.pin("X")["Value"], 1.0, 1e-3)


def test_calibration_ignores_far_taps_and_times_out():
    q = boot()
    q.set_pin("Calibrate", True)
    q.tap(250, 250)                                                   # the centre is near no target
    assert "closer" in q.status()
    assert q.pin("Calibrate")["Boolean"] is True
    q.advance(61.0)
    assert q.pin("Calibrate")["Boolean"] is False
    assert "cancelled" in q.status()
    assert q.pin("Calibration")["String"] == ""


# ------------------------------------------------------------------- lock

def test_lock_swallows_touches_and_draws_the_overlay():
    q = boot()
    probe(q, "onLock", "LOCKS")
    q.set_pin("Lock", True)
    assert "Locked" in q.icon() and q.run("return LOCKS") == 1
    q.tap(250, 250)
    assert q.pulses("Tap") == 0 and q.pulses("Press") == 0
    assert q.pin("Touching")["Boolean"] is False
    q.set_pin("Lock", False)
    assert "Locked" not in q.icon() and q.run("return LOCKS") == 2
    q.advance(1.0)
    q.tap(250, 250)
    assert q.pulses("Tap") == 1


def test_lock_mid_touch_ends_it_silently():
    q = boot()
    q.touch([(100, 100), (150, 150)], panel_touch=True, lift=False)
    q.set_pin("Lock", True)
    assert q.pin("Touching")["Boolean"] is False
    q.lift()
    assert q.pulses("Release") == 0


# ----------------------------------------------------------------- frames

def test_frame_rate_cap_over_two_seconds():
    q = boot(props={"Max Frame Rate": "20"})
    before = q.icons
    pts = [(50 + 4 * i, 50 + 4 * i) for i in range(101)]
    q.drag(pts, seconds=2.0, lift=False)
    assert q.icons - before <= 41, q.icons - before
    assert q.icons - before >= 30
    q.lift()


def test_frame_rate_property_changes_the_cap():
    q = boot(props={"Max Frame Rate": "10"})
    before = q.icons
    pts = [(50 + 4 * i, 50 + 4 * i) for i in range(101)]
    q.drag(pts, seconds=2.0, lift=False)
    assert q.icons - before <= 21
    q.lift()


def test_unchanged_frame_is_not_resent():
    q = boot()
    n = q.icons
    q.run("TouchPad.E.invalidate()")
    q.advance(0.5)
    q.run("TouchPad.E.invalidate()")
    q.advance(0.5)
    assert q.icons == n
    q.tap(100, 100)
    q.advance(2.0)
    m = q.icons
    q.tap(100, 100)                                                   # ends in the same drawing
    q.advance(2.0)
    assert q.icons - m == 2                                           # finger down, finger up; nothing after


def test_icon_channel_style_writes_style_not_legend():
    q = boot(props={"Icon Channel": "Style"})
    d = q.pin("Display")
    assert d["Legend"] == "" and '"IconData":"' in d["Style"] and '"Legend":""' in d["Style"]
    assert q.icon().startswith("<svg")
    assert d["IsDisabled"] is True


def test_display_stays_disabled_after_every_frame():
    q = boot()
    q.run("Controls.Display.IsDisabled = false")
    q.tap(200, 200)
    assert q.pin("Display")["IsDisabled"] is True


# -------------------------------------------------------- picker binding

def test_status_missing_picker():
    q = boot(props={"Color Picker": "Nope"})
    assert q.status() == "No picker named Nope"
    assert q.pin("Status")["Value"] == 2


def test_status_wrong_script_access():
    q = QSys(mode="XY Pad", picker=None, props={"Color Picker": "Pick"}, runtime=False)
    q.add_component("Pick", "color_picker")                           # listed, but nothing readable
    q._dispatch("load", q._chunk)
    assert q.status() == "Set the picker's Script Access to All: Pick"


def test_status_wrong_type():
    q = QSys(mode="XY Pad", picker=None, props={"Color Picker": "Gain1"}, runtime=False)
    q.add_component("Gain1", "gain", {"gain": {"Value": 0, "Min": -100, "Max": 20}, "mute": {"Boolean": False}})
    q._dispatch("load", q._chunk)
    assert q.status() == "Gain1 is not a Color Picker"


def test_refresh_rebinds_and_picker_text_overrides():
    q = boot(picker=None)
    assert q.status().startswith("No Color Picker in the design")
    q.picker = q.add_picker("Late")
    q.set_pin("Refresh", True)
    assert q.status() == "OK - Ready. Picker OK: saturation / value"
    q.tap(250, 250)
    assert q.pulses("Tap") == 1
    q.add_picker("Other", ("hsv.saturation", "hsv.value"))
    q.set_pin("Picker", "Other")
    assert q.status() == "OK - Ready. Picker OK: hsv.saturation / hsv.value"
    q.picker = q.components["Other"]
    q.advance(1.0)
    q.tap(100, 100)
    assert q.pulses("Tap") == 2
    q.set_pin("Picker", "Nope")
    assert q.status() == "No picker named Nope"


def test_two_pickers_need_a_name():
    q = QSys(mode="XY Pad", picker="A", runtime=False)
    q.add_picker("B")
    q._dispatch("load", q._chunk)
    assert q.status() == "2 Color Pickers in the design: name one in the Color Picker property"
    assert q.pin("Status")["Value"] == 1
    q.advance(0.2)
    q.set_pin("Picker", "B")
    assert q.status().startswith("OK")


def test_discovery_hsv_underscore_names():
    q = boot(picker_names=("hsv_s", "hsv_v"))
    assert q.status() == "OK - Ready. Picker OK: hsv_s / hsv_v"
    q.tap(250, 125)
    assert q.pulses("Tap") == 1 and near(q.pin("Y")["Value"], 0.75)


def test_discovery_capitalised_names():
    q = boot(picker_names=("Saturation", "Value"))
    assert q.status() == "OK - Ready. Picker OK: Saturation / Value"
    q.tap(250, 125)
    assert q.pulses("Tap") == 1 and near(q.pin("X")["Value"], 0.5)


def test_discovery_dotted_names_and_debug_list():
    q = boot(picker_names=("hsv.saturation", "hsv.value"), props={"Debug Print": "All"})
    assert q.status() == "OK - Ready. Picker OK: hsv.saturation / hsv.value"
    assert any(line.startswith("picker Color_Picker controls: hsv.saturation, hsv.value, hue") for line in q.output())
    q.tap(100, 100)
    assert q.pulses("Tap") == 1


def test_hex_output_fallback_is_coarse_but_works():
    q = boot(picker_names=("foo", "bar"))                             # no axis names at all
    assert q.status().startswith("OK - Picker bound through its colour output (coarse)")
    assert q.pin("Status")["Value"] == 1
    q.F.surface_reports = True
    q.tap(250, 125)
    assert q.pulses("Tap") == 1
    assert near(q.pin("X")["Value"], 0.5, 0.01) and near(q.pin("Y")["Value"], 0.75, 0.01)


# ---------------------------------------------------------- error guard

def test_mode_error_is_recovered_and_the_next_tap_works():
    q = boot()
    q.run('TouchPad.inst.onTouchStart = function() error("boom in the mode") end')
    q.tap(100, 100)
    assert q.status().startswith("Recovered from an error: ") and "boom in the mode" in q.status()
    assert q.pin("Status")["Value"] == 2
    assert q.errors == []                                             # caught by the guard, not the harness
    assert any("Touch Pad: error in onTouchStart" in line for line in q.output())
    assert q.pulses("Tap") == 1                                       # the rest of the touch still ran
    q.run("TouchPad.inst.onTouchStart = nil")
    q.advance(1.0)
    q.tap(300, 300)
    assert q.pulses("Tap") == 2
    assert q.status().startswith("OK - Ready")


def test_draw_error_keeps_the_pad_alive():
    q = boot()
    q.run('TouchPad.inst.draw = function() error("draw failed") end')
    q.tap(100, 100)
    assert q.status().startswith("Recovered from an error") and "draw failed" in q.status()
    assert q.icon().startswith("<svg")                                # the engine's frame still went out
    assert q.pulses("Tap") == 1


def test_control_input_reaches_the_mode_but_own_writes_do_not():
    q = boot()
    q.run('NAMES = {}; TouchPad.inst.onControl = function(self, name, index, ctl) NAMES[#NAMES + 1] = name .. ":" .. tostring(index) end')
    q.set_pin("Tap", True)
    q.set_pin("Tap", False)
    q.set_pin("SwipeLeft", True)
    assert q.run("return table.concat(NAMES, ',')") == "Tap:1,Tap:1,SwipeLeft:1"
    q.run("NAMES = {}")
    q.tap(200, 200)                                                   # the engine's own Tap pulse is an echo
    assert q.run("return #NAMES") == 0


def test_after_and_every_timers_are_guarded():
    q = boot()
    q.run('TouchPad.E.after(0.1, function() error("late boom") end)')
    q.advance(0.2)
    assert q.status().startswith("Recovered from an error") and "late boom" in q.status()
    q.run('H = TouchPad.E.every(0.1, function() TICKS = (TICKS or 0) + 1 end)')
    q.advance(0.55)
    assert q.run("return TICKS") == 5
    q.run("H:cancel()")
    q.advance(1.0)
    assert q.run("return TICKS") == 5
    assert q.errors == []


# ------------------------------------------------------------ debug, misc

def test_debug_print_gestures_and_all():
    q = boot(props={"Debug Print": "Gestures"})
    q.tap(100, 100)
    out = q.output()
    assert any(line.startswith("touch start 100.0 100.0") for line in out)
    assert any(line.startswith("gesture tap") for line in out)
    assert not any(line.startswith("report ") for line in out)
    q2 = boot(props={"Debug Print": "All"})
    q2.tap(100, 100)
    assert any(line.startswith("report u=0.2000 v=0.8000") for line in q2.output())


def test_timer_now_fallback_clock():
    q = QSys(mode="XY Pad", picker="Color_Picker", runtime=False)
    q.run("Timer.Now = nil")                                          # no usable clock on this platform
    q._dispatch("load", q._chunk)
    q.advance(0.3)
    q.tap(250, 125, panel_touch=True)
    assert q.pulses("Tap") == 1 and near(q.pin("X")["Value"], 0.5)
    assert q.run("return Q.now()") > 0


def test_every_handler_under_the_budget():
    q = boot(props={"Debug Print": "All", "Pad Width": 1600, "Pad Height": 1200})
    q.tap(100, 100, panel_touch=True)
    q.double_tap(300, 300, panel_touch=True)
    q.swipe(100, 600, 1500, 600, seconds=0.2, panel_touch=True)
    q.long_press(800, 600, seconds=1.0)
    q.drag([(100 + 14 * i, 100 + 10 * i) for i in range(100)], seconds=2.0, panel_touch=True)
    q.set_pin("Lock", True)
    q.set_pin("Lock", False)
    q.set_pin("Calibrate", True)
    q.tap(190, 140)
    q.tap(1410, 1060)
    q.set_pin("Refresh", True)
    b = q.budget()                                                    # raises BudgetError on a breach
    assert b["max_handler"] < 120000 and b["max_frame"] < 60000
    assert b["frames"] > 10


def test_animate_runs_tick_at_the_frame_rate():
    q = boot(props={"Max Frame Rate": "20"})
    q.run('TICKS = 0; DT = 0; TouchPad.inst.tick = function(self, dt) TICKS = TICKS + 1; DT = DT + dt end')
    q.run("TouchPad.E.animate(true)")
    q.advance(1.0)
    ticks = q.run("return TICKS")
    assert 18 <= ticks <= 21, ticks
    assert near(q.run("return DT"), 1.0, 0.06)
    q.run("TouchPad.E.animate(false)")
    q.advance(1.0)
    assert q.run("return TICKS") == ticks


# ------------------------------------------------------------ E surface

def test_engine_api_surface_is_exactly_the_contract():
    q = boot()
    keys = q.run("local t = {} for k in pairs(TouchPad.E) do t[#t + 1] = k end table.sort(t) return table.concat(t, ',')")
    assert keys == ("H,T,W,after,animate,cameraFactory,ctl,ctls,dbg,every,file,font,hint,http,invalidate,json,"
                    "log,now,out,props,pulse,setGesture,status"), keys                 # E.camera is nil for now
    assert q.run("return TouchPad.E.W, TouchPad.E.H") == (500, 500)
    assert q.run("return TouchPad.E.T.accent") == "#C513E8"
    assert q.run('return TouchPad.E.props["Mode"], TouchPad.E.props["Max Frame Rate"]') == ("XY Pad", "20")
    assert q.run("return TouchPad.E.hint") is True
    assert q.run("return TouchPad.E.camera") is None
    assert q.run('return TouchPad.E.cameraFactory("Demo (simulated)", {})') is None   # no camera module yet
    assert q.run("return TouchPad.E.font == Font") is True
    assert q.run('return #TouchPad.E.ctls("X"), TouchPad.E.ctl("X") == Controls.X, TouchPad.E.ctl("X", 1) == Controls.X') == (1, True, True)
    assert q.run('return TouchPad.E.out("X", 0.25)') is True
    assert near(q.pin("X")["Value"], 0.25)
    assert q.run('return TouchPad.E.out("X", 0.25)') is False               # unchanged: no write
    assert q.run('return TouchPad.E.out("X", 7)') is True and q.pin("X")["Value"] == 1   # clamped to the range
    q.run('TouchPad.E.pulse("SwipeUp")')
    assert q.pulses("SwipeUp") == 1
    q.run('TouchPad.E.setGesture("hello there")')
    assert q.pin("Gesture")["String"] == "HELLO THERE"
    q.run('TouchPad.E.status("Custom note", "warn")')
    assert q.status() == "Custom note" and q.pin("Status")["Value"] == 1
    assert near(q.run("return TouchPad.E.now()"), q.now)
    q.run('TouchPad.E.log("logged line")')
    assert "logged line" in q.output()


def test_engine_json_and_file_helpers():
    q = boot()
    assert q.run('return TouchPad.E.json.encode({ a = 1, b = { "x", "y" } })') == '{"a":1,"b":["x","y"]}'
    assert q.run('return TouchPad.E.json.decode(\'{"zones":[{"x":0.5,"y":1}], "ok":true}\').zones[1].x') == 0.5
    assert q.run('return Q.jsonDecodePure(\'[1, "two", {"three": [3.5, null, false]}, "\\\\u00e9"]\')[3].three[1]') == 3.5
    assert q.run("return (Q.jsonDecodePure('{bad'))") is None
    assert q.run("return TouchPad.E.file.base()") == "media"
    assert q.run('return TouchPad.E.file.mkdir("media/Test")') is True
    assert q.run('return (TouchPad.E.file.write("media/Test/a.txt", "one\\n"))') is True
    assert q.run('return (TouchPad.E.file.append("media/Test/a.txt", "two\\n"))') is True
    assert q.read_file("media/Test/a.txt") == "one\ntwo\n"
    assert q.run('return (TouchPad.E.file.read("media/Test/a.txt"))') == "one\ntwo\n"
    assert q.run('return (TouchPad.E.file.read("media/Test/missing.txt"))') is None
    assert q.run('return (TouchPad.E.file.write("/etc/passwd", "x"))') is None
    e = boot(emulate=True)
    assert e.run("return TouchPad.E.file.base()") == "design"


def test_engine_http_and_socket_helpers():
    q = boot()
    q.http_reply = (201, '{"ok":true}', None)
    q.run('TouchPad.E.http.post("https://example.test/hook", "{\\"a\\":1}", nil, function(code, data, err) HTTP = code .. ":" .. data end)')
    q.advance(0.1)
    assert q.run("return HTTP") == '201:{"ok":true}'
    post = q.http_posts[0]
    assert post["url"] == "https://example.test/hook" and post["method"] == "POST" and post["body"] == '{"a":1}'
    assert post["headers"]["Content-Type"] == "application/json"
    q.run('UDP = Q.udp({ ip = "10.0.0.5", port = 52381, onData = function(d) GOT = d end }); UDP:send("\\1\\2")')
    assert q.udp_sent == [("10.0.0.5", 52381, b"\x01\x02")]
    q.inject_udp(b"\x90\x50\xff")
    assert q.run("return GOT == '\\144\\80\\255'") is True
    q.run('TCP = Q.tcp({ ip = "10.0.0.6", port = 5678, onData = function(d) TGOT = d end, onEvent = function(e) TEVT = e end })')
    assert q.run("return TCP:send('x')") is False                           # not connected yet
    q.advance(0.1)
    assert q.run("return TCP.connected") is True and q.tcp_connects == [("10.0.0.6", 5678)]
    assert q.run("return TCP:send('\\129\\1\\4\\7\\2\\255')") is True
    assert q.tcp_sent[-1] == ("10.0.0.6", 5678, b"\x81\x01\x04\x07\x02\xff")
    q.inject_tcp(b"\x90\x41\xff")
    assert q.run("return TGOT == '\\144\\65\\255'") is True
    q.tcp_event("Closed")
    assert q.run("return TCP.connected") is False and q.run("return TEVT") == "EOF"
    q.run("TCP:close(); UDP:close()")
    assert q.errors == []


# ------------------------------------------------ review findings (engine)
# Each test below reproduces a reported defect; the name says what must hold.

def count_lines(q, needle):
    return sum(1 for line in q.output() if needle in line)


def test_calibrate_during_live_touch_releases_touching():
    q = boot()
    probe(q, "onTouchEnd", "ENDS")
    q.touch([(100, 100), (150, 150), (200, 200)], panel_touch=True, lift=False)
    assert q.pin("Touching")["Boolean"] is True and q.pulses("Press") == 1
    q.set_pin("Calibrate", True)
    assert q.pin("Touching")["Boolean"] is False                      # the live touch ended with the mode told
    assert q.run("return ENDS") == 1 and q.pulses("Release") == 1
    assert q.run("return TouchPad.inst.down") is False
    assert q.status() == "Calibration: tap the top-left target"       # the old touch was not a calibration tap
    q.lift()
    assert q.pulses("Release") == 1 and q.pulses("Tap") == 0
    q.advance(2.0)
    assert q.pin("Touching")["Boolean"] is False
    assert q.pin("Calibrate")["Boolean"] is True                      # calibration goes on
    q.set_pin("Calibrate", False)
    q.advance(0.5)
    q.tap(250, 250, panel_touch=True)
    assert q.pulses("Tap") == 1 and q.pulses("Press") == 2


def test_calibration_ended_mid_touch_drops_the_touch():
    q = boot()
    probe(q, "onTouchStart", "STARTS")
    probe(q, "onTouchEnd", "ENDS")
    q.set_pin("Calibrate", True)
    q.touch([(250, 250)], panel_touch=True, lift=False)
    assert q.pulses("Press") == 0 and q.run("return STARTS") == 0
    q.set_pin("Calibrate", False)                                      # the finger is still down
    q.lift()
    assert q.pulses("Release") == 0 and q.pulses("Tap") == 0
    assert q.run("return STARTS") == 0 and q.run("return ENDS") == 0
    assert q.pin("Touching")["Boolean"] is False
    q.advance(0.5)
    q.tap(250, 250, panel_touch=True)                                  # the next touch is a normal tap
    assert q.pulses("Tap") == 1 and q.run("return STARTS") == 1 and q.run("return ENDS") == 1


def test_resumed_swipe_pulses_swipe_once():
    q = boot()
    probe(q, "onGesture", "GESTURES")
    probe(q, "onTouchEnd", "ENDS")
    q.swipe(100, 250, 400, 250, seconds=0.2, lift=False)
    q.advance(0.35)                                                   # inferred lift: the swipe is classified once
    assert q.pulses("SwipeRight") == 1 and q.run("return GESTURES") == 1
    q.touch([(405, 252)], lift=False)                                 # the finger settles and shifts: a resume
    assert q.pin("Touching")["Boolean"] is True and q.pulses("Press") == 1
    q.lift()
    assert q.pulses("SwipeRight") == 1 and q.run("return GESTURES") == 1
    assert q.run("return ENDS") == 2 and q.pulses("Release") == 1 and q.pulses("Tap") == 0
    assert q.pin("Gesture")["String"] == "SWIPE RIGHT"


def test_designer_far_tap_in_same_column_is_a_new_touch():
    q = boot(emulate=True)
    probe(q, "onTouchResume", "RESUMED")
    q.drag([(100 + 10 * i, 100 + 10 * i) for i in range(11)], seconds=0.5, lift=False)
    q.advance(0.4)                                                    # inferred lift, resume window open
    assert q.pulses("Release") == 1 and q.pin("Touching")["Boolean"] is False
    q.tap(210, 480)                                                   # Designer sends u first, then v
    assert q.run("return RESUMED") == 0
    assert q.pulses("Press") == 2 and q.pulses("Tap") == 1
    assert near(q.pin("X")["Value"], 0.42, 1e-3) and near(q.pin("Y")["Value"], 0.04, 1e-3)


def test_panel_far_tap_in_same_column_is_a_new_touch():
    q = boot()
    probe(q, "onTouchResume", "RESUMED")
    q.drag([(100 + 10 * i, 100 + 10 * i) for i in range(11)], seconds=0.5, lift=False)
    q.advance(0.4)
    q.tap(210, 480)
    assert q.run("return RESUMED") == 0 and q.pulses("Tap") == 1 and q.pulses("Press") == 2


def test_press_hold_shift_is_one_contact():
    q = boot()
    q.touch([(200, 200)], lift=False)
    q.advance(0.27)                                                   # 0.32 s after the report: lift inferred at 0.25
    assert q.pulses("Release") == 1 and q.pulses("Tap") == 1
    q.touch([(203, 202)], lift=False)                                 # the finger peels off with a 3 px shift
    q.lift()
    assert q.pulses("Press") == 1 and q.pulses("Tap") == 1 and q.pulses("DoubleTap") == 0
    assert q.pin("Gesture")["String"] == "TAP"
    q.advance(1.0)
    assert q.picker.position == (0.0, 0.0)                            # parked again after the shift
    # Two taps a finger's width apart are still a double tap without Panel Touch.
    q2 = boot()
    q2.touch([(200, 200)], silence=0.3)
    q2.tap(210, 200)
    assert q2.pulses("Tap") == 2 and q2.pulses("DoubleTap") == 1


def test_quick_tap_report_and_release_same_turn_is_a_tap():
    q = boot()
    q.set_pin("PanelTouch", True)
    q.advance(0.03)
    q.picker.set(0.4, 0.6, force=True)                                # report and release in one engine turn
    q.set_pin("PanelTouch", False)
    q.advance(0.5)
    assert q.pulses("Press") == 1 and q.pulses("Tap") == 1 and q.pulses("Release") == 1
    assert near(q.pin("X")["Value"], 0.4) and near(q.pin("Y")["Value"], 0.6)
    assert q.pin("Touching")["Boolean"] is False


def test_liftoff_report_with_release_same_turn_is_applied():
    q = boot()
    q.touch([(100, 100), (120, 120)], panel_touch=True, lift=False)
    q.picker.set(*q.to_picker(125, 125), force=True)                  # lift-off report ...
    q.set_pin("PanelTouch", False)                                    # ... and the release in one turn
    q.advance(0.5)
    assert q.pulses("Release") == 1
    assert near(q.pin("X")["Value"], 0.25) and near(q.pin("Y")["Value"], 0.75)
    q.touch([(400, 400)], panel_touch=True)                           # a fresh tap is not a 390 px drag
    assert q.pulses("Press") == 2 and q.pulses("Tap") == 1
    assert near(q.pin("X")["Value"], 0.8) and q.pin("Gesture")["String"] == "TAP"


def test_refresh_mid_drag_ends_the_touch_for_the_mode():
    q = boot()
    probe(q, "onTouchEnd", "ENDS")
    q.run("ABORTED = nil; local o = TouchPad.inst.onTouchEnd; TouchPad.inst.onTouchEnd = function(self, x, y, t, info) ABORTED = info.aborted; return o(self, x, y, t, info) end")
    q.touch([(100, 100), (150, 150)], panel_touch=True, lift=False)
    q.set_pin("Refresh", True)
    assert q.status().startswith("OK - Ready")
    assert q.pin("Touching")["Boolean"] is False and q.run("return ENDS") == 1 and q.run("return ABORTED") is True
    assert q.pulses("Press") == 1 and q.pulses("Release") == 1
    assert q.run("return TouchPad.inst.down") is False
    q.touch([(200, 200), (220, 220)], lift=False)                     # the same finger keeps moving: no new touch
    assert q.pulses("Press") == 1
    q.set_pin("PanelTouch", False)
    q.advance(0.5)
    assert q.pulses("Release") == 1 and q.picker.position == (0.0, 0.0)


def test_refresh_with_pending_report_makes_no_phantom_press():
    q = boot()
    q.picker.set(0.5, 0.5, force=True)                                # a report ...
    q.set_pin("Refresh", True)                                        # ... and a rebind in the same turn
    q.advance(1.0)
    assert q.pulses("Press") == 0 and q.pulses("Tap") == 0 and q.pin("Touching")["Boolean"] is False


def test_lock_mid_drag_parks_the_picker():
    q = boot(emulate=True)
    q.touch([(100, 100), (150, 150), (200, 200)], lift=False)
    q.set_pin("Lock", True)
    q.advance(3.0)
    q.set_pin("Lock", False)
    q.advance(3.0)
    assert q.picker.position == (0.0, 0.0)
    q.tap(200, 200)                                                   # Designer resends the spot only because it was parked
    assert q.pulses("Tap") == 1


def test_lock_during_paused_window_parks():
    q = boot()
    q.touch([(100, 100), (150, 150), (200, 200)], lift=False)
    q.advance(0.5)                                                    # inferred lift, paused
    q.set_pin("Lock", True)
    q.advance(3.0)
    q.set_pin("Lock", False)
    q.advance(3.0)
    assert q.picker.position == (0.0, 0.0)


def test_lock_with_panel_touch_parks_after_the_release():
    q = boot(props={"Debug Print": "All"})
    q.touch([(100, 100), (150, 150)], panel_touch=True, lift=False)
    q.set_pin("Lock", True)
    q.advance(1.0)
    assert q.picker.position != (0.0, 0.0)                            # never while the finger is down
    q.lift()
    q.advance(1.0)
    q.set_pin("Lock", False)
    q.advance(1.0)
    assert q.picker.position == (0.0, 0.0)
    assert any(line.startswith("park ") for line in q.output())


def test_stuck_guard_keeps_following_a_resting_finger():
    q = boot()
    q.touch([(100, 100)], panel_touch=True, lift=False)
    q.advance(31.0)
    assert q.pulses("Release") == 1 and q.pin("Touching")["Boolean"] is False
    assert q.picker.position != (0.0, 0.0)                            # not parked under the finger
    q.touch([(120, 120), (140, 140)], lift=False)                     # the same contact moves again
    assert q.pulses("Press") == 2 and q.pin("Touching")["Boolean"] is True
    assert near(q.pin("X")["Value"], 0.28)
    q.set_pin("PanelTouch", False)
    q.advance(0.5)
    assert q.pulses("Release") == 2 and q.picker.position == (0.0, 0.0)


def test_panel_touch_designer_split_waits_for_both_axes():
    q = boot()
    q.advance(0.3)
    q.touch([(250, 250)], mode="designer", panel_touch=True)          # Saturation and Value 60 ms apart
    assert q.pulses("Tap") == 1 and q.pulses("Press") == 1
    assert q.pulses("SwipeUp") == 0 and q.pin("Gesture")["String"] == "TAP"
    assert near(q.pin("X")["Value"], 0.5) and near(q.pin("Y")["Value"], 0.5)
    starts = [line for line in q.output() if line.startswith("touch start")]
    assert starts == []                                               # Debug Print is off; see the next test
    q2 = boot(props={"Debug Print": "Gestures"})
    q2.advance(0.3)
    q2.touch([(250, 250)], mode="designer", panel_touch=True)
    starts = [line for line in q2.output() if line.startswith("touch start")]
    assert starts == ["touch start 250.0 250.0 t=0.560"], starts
    q3 = boot()                                                       # the release before the second axis still lands
    q3.advance(0.3)
    q3.set_pin("PanelTouch", True)
    q3.picker.set_axis("x", 0.5)
    q3.advance(0.02)
    q3.set_pin("PanelTouch", False)
    q3.advance(0.5)
    assert q3.pulses("Tap") == 1 and near(q3.pin("X")["Value"], 0.5) and near(q3.pin("Y")["Value"], 0.0)


def test_bind_names_the_controls_when_no_axis_is_recognised():
    q = QSys(mode="XY Pad", picker="Color_Picker", picker_names=("hsv.x", "hsv.y"), props={"Debug Print": "All"}, runtime=False)
    q.picker.controls["color_picker_surface"].String = ""             # no hex output either
    q._dispatch("load", q._chunk)
    assert q.status() == "Color_Picker has no recognised axis controls (controls: hsv.x, hsv.y, hue, color_picker_surface)", q.status()
    assert q.pin("Status")["Value"] == 2
    assert any(line.startswith("picker Color_Picker controls: hsv.x, hsv.y, hue, color_picker_surface") for line in q.output())


def test_refresh_rebinds_on_any_event():
    q = boot(picker=None)
    q.add_picker("Late")
    q.trigger("Refresh")                                              # the handler runs with Boolean still false
    assert q.status() == "OK - Ready. Picker OK: saturation / value"
    q.set_pin("Picker", "Nope")
    q.set_pin("Refresh", True)
    q.set_pin("Refresh", False)                                       # the trailing edge of a pulse does not rescan twice
    assert q.status() == "No picker named Nope"


def test_http_udp_tcp_callback_errors_are_recovered():
    q = boot()
    q.run('TouchPad.E.http.post("https://example.test/hook", "{}", nil, function() error("cb boom") end)')
    q.advance(0.1)
    assert q.errors == [] and "cb boom" in q.status()
    q.run('UDP = Q.udp({ ip = "10.0.0.5", port = 52381, onData = function() error("udp boom") end })')
    q.inject_udp(b"\x90\x50\xff")
    assert q.errors == [] and "udp boom" in q.status()
    q.run('TCP = Q.tcp({ ip = "10.0.0.6", port = 5678, onData = function() error("tcp boom") end, onEvent = function(e) if e == "EOF" then error("evt boom") end end })')
    q.advance(0.1)
    q.inject_tcp(b"\x90\x41\xff")
    assert q.errors == [] and "tcp boom" in q.status()
    q.tcp_event("Closed")
    assert q.errors == [] and "evt boom" in q.status()
    q.run("TCP:close(); UDP:close()")
    q.advance(1.0)
    q.tap(100, 100)
    assert q.pulses("Tap") == 1 and q.status().startswith("OK - Ready")


def big_component(q, name, ctype, n):
    q.add_component(name, ctype)
    for i in range(n):
        q.F.add_control(name, "input.%d.output.%d.gain" % (i // 45 + 1, i % 45 + 1), "Knob", -100, 20, 0)


def test_binding_a_large_component_is_cheap():
    q = boot()
    big_component(q, "BigMixer", "mixer", 2025)
    q.set_pin("Picker", "BigMixer")
    assert q.status() == "BigMixer is not a Color Picker"
    assert q.instructions("ctl:Picker") < 40000
    q2 = QSys(mode="XY Pad", picker=None, props={"Color Picker": "BigMixer"}, runtime=False)
    big_component(q2, "BigMixer", "mixer", 2025)
    q2._dispatch("load", q2._chunk)
    assert q2.status() == "BigMixer is not a Color Picker"
    assert q2.instructions("load") < 120000
    q3 = QSys(mode="XY Pad", picker="Wide", runtime=False)            # a picker type with 2,100 extra controls
    for i in range(2100):
        q3.F.add_control("Wide", "extra.%d" % i, "Knob", 0, 1, 0)
    q3._dispatch("load", q3._chunk)
    assert q3.status() == "OK - Ready. Picker OK: saturation / value"
    assert q3.instructions("load") < 120000
    q3.advance(0.2)
    q3.tap(250, 250)
    assert q3.pulses("Tap") == 1


def test_persistent_draw_error_does_not_flood():
    q = boot()
    q.run('DRAWS = 0; TouchPad.inst.draw = function(self, c) DRAWS = DRAWS + 1; TouchPad.E.invalidate(); error("draw loop") end')
    q.tap(100, 100)
    q.advance(1.5)
    assert q.run("return DRAWS") <= 5, q.run("return DRAWS")
    assert count_lines(q, "error in draw") <= 2
    assert q.status().startswith("Recovered from an error (x") and "draw loop" in q.status()
    q.run("TouchPad.inst.draw = function(self, c) DRAWS = DRAWS + 1 end")
    q.advance(2.0)
    q.tap(300, 300)
    assert q.pulses("Tap") == 2 and q.status().startswith("OK - Ready")
    q.run('TouchPad.E.animate(true); TouchPad.inst.tick = function() TouchPad.E.invalidate() end')
    q.run('TouchPad.inst.draw = function(self, c) DRAWS = DRAWS + 1; error("anim loop") end')
    n = q.run("return DRAWS")
    q.advance(3.0)
    assert q.run("return DRAWS") - n <= 5


def test_huge_calibration_text_is_cheap():
    q = boot()
    q.set_pin("Calibration", "junk line\n" * 20000)
    assert q.instructions("ctl:Calibration") < 20000
    q.set_pin("Calibration", "P 0.1 0.1 0.8 0.8\n" + "junk\n" * 20000)
    assert q.run("return TouchPad.cal.P[3]") == 0.8
    q2 = QSys(mode="XY Pad", picker="Color_Picker", runtime=False)
    q2.run('Controls.Calibration.String = string.rep("junk line\\n", 20000)')
    q2._dispatch("load", q2._chunk)
    assert q2.instructions("load") < 120000 and q2.status().startswith("OK - Ready")


def test_long_error_message_is_truncated():
    q = boot()
    q.run('TouchPad.inst.onTouchStart = function() error(string.rep("x", 5000)) end')
    q.tap(100, 100)
    assert len(q.status()) < 200 and q.status().startswith("Recovered from an error")
    assert all(len(line) < 5000 for line in q.output())


def test_frames_without_crypto_stay_within_budget():
    q = QSys(mode="XY Pad", picker="Color_Picker", runtime=False)
    q.run("Crypto = nil")
    q._dispatch("load", q._chunk)
    q.advance(0.2)
    q.drag([(50 + 15 * i, 50 + 11 * i) for i in range(30)], seconds=1.5)
    assert q.icon().startswith("<svg") and "Drag anywhere" in q.icon()
    b = q.budget()                                                    # raises on a breach
    assert b["max_frame"] < 60000 and b["frames"] >= 10
    big = QSys(mode="XY Pad", picker="Color_Picker", props={"Pad Width": 1600, "Pad Height": 1200}, runtime=False)
    big.run("Crypto = nil")
    big._dispatch("load", big._chunk)
    big.advance(0.2)
    big.drag([(50 + 15 * i, 50 + 11 * i) for i in range(30)], seconds=1.5)
    assert big.budget()["max_frame"] < 60000
    assert big.run("return Q.base64('any carnal pleasure.')") == "YW55IGNhcm5hbCBwbGVhc3VyZS4="
    assert big.run("return Q.base64('')") == "" and big.run("return Q.base64('a')") == "YQ=="


def test_bind_and_first_frame_errors_land_on_status():
    q = QSys(mode="XY Pad", picker="Color_Picker", props={"Color Picker": "Color_Picker"}, runtime=False)
    q.run('Component.GetComponents = function() error("listing boom") end')
    q._dispatch("load", q._chunk)
    assert q.errors == [] and q.status().startswith("OK - Ready")      # pcall inside Q.components
    q.run('Q.components = function() error("deep boom") end')
    q.advance(0.2)
    q.set_pin("Refresh", True)
    assert q.errors == [] and "deep boom" in q.status()
    q2 = QSys(mode="XY Pad", picker="Color_Picker", runtime=False)
    q2.run("Controls.Display = nil")                                   # the first frame cannot be written
    q2._dispatch("load", q2._chunk)
    assert q2.errors == [] and q2.status().startswith("Recovered from an error") and "nil" in q2.status()
