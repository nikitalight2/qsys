# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Keypad mode (24_mode_keypad.lua)
"""The Keypad draws digits 0-9, clear and enter; a tap presses a key (0.15 s
highlight), a swipe left deletes a digit, Entry carries the digits, Masked
shows dots, AutoSubmit checks the code at the right length, MaxTries failures
lock the pad (Locked, a pin both ways) for LockoutSeconds, and Learn stores
the next entered code into Pin."""
import math
import os
import re

from harness import QSys
from harness.qsys_fake import DEFAULT_PLUGIN, plugin_modes

ACCENT, TEXT, OK, DANGER = "#C513E8", "#F4F2F7", "#2ECC8F", "#F0328C"   # Nikita theme

# The full plugin when it carries the Keypad mode, else the per-mode build
# (python3 tools/touchpad/build.py --modes keypad --out plugins/.build/NikitaTouchPad-keypad.qplug).
PER_MODE = os.path.join(os.path.dirname(os.path.abspath(DEFAULT_PLUGIN)), ".build", "NikitaTouchPad-keypad.qplug")


def plugin_path():
    try:
        if "Keypad" in plugin_modes(DEFAULT_PLUGIN):
            return DEFAULT_PLUGIN
    except Exception:
        pass
    return PER_MODE if os.path.exists(PER_MODE) else DEFAULT_PLUGIN


def boot(**kw):
    kw.setdefault("mode", "Keypad")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", plugin_path())
    q = QSys(**kw)
    q.advance(0.2)
    return q


def key(q, label):
    """Centre of a key in pad px, from the mode's own geometry."""
    x, y = q.run('return TouchPad.inst:keyCenter("%s")' % label)
    return x, y


def press(q, labels, **kw):
    for label in labels:
        q.tap(*key(q, label), **kw)


def circles(svg):
    return [tuple(float(v) for v in m.groups())
            for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)"', svg)]


def accent_rects(svg):
    return re.findall(r'<rect[^>]*fill="%s"[^>]*>' % ACCENT, svg)


def texts(svg):
    return re.findall(r">([^<]*)</text>", svg)


# ------------------------------------------------------------ controls and drawing

def test_keypad_controls_defaults_and_layout_lint():
    q = boot()
    names = q.control_names()
    for n in ["Pin", "Entry", "Masked", "AutoSubmit", "Learn", "Accepted", "Rejected",
              "Locked", "MaxTries", "LockoutSeconds"]:
        assert n in names, n
    assert len(names) == 36                                   # 26 common + 10 keypad
    assert q.pin("Pin")["String"] == "1234"
    assert q.pin("Masked")["Boolean"] is True
    assert q.pin("AutoSubmit")["Boolean"] is True
    assert q.pin("Learn")["Boolean"] is False
    assert q.pin("Locked")["Boolean"] is False
    assert q.pin("MaxTries")["Value"] == 5 and q.pin("LockoutSeconds")["Value"] == 60
    assert q.pin("Entry")["String"] == ""
    assert q.layout_lint([{}, {"Pad Width": 120, "Pad Height": 120}, {"Pad Width": 1600, "Pad Height": 1200},
                          {"Background": "Transparent", "Theme": "Light"}, {"Show Hints": False}]) == []
    assert q.status().startswith("OK")


def test_keypad_idle_drawing_has_twelve_keys_digits_and_hint():
    q = boot()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    labels = texts(svg)
    for d in "1234567890":
        assert d in labels, d
    assert "Enter code" in labels
    assert "Tap a key, swipe left to delete" in labels
    assert svg.count('rx="13"') == 12                         # the twelve key tiles
    assert svg.count("<g transform=") == 2                    # the clear and enter icons
    # keys are laid out 3 x 4 in reading order
    assert key(q, "1")[0] < key(q, "2")[0] < key(q, "3")[0]
    assert key(q, "1")[1] < key(q, "4")[1] < key(q, "7")[1] < key(q, "C")[1]
    assert key(q, "C")[1] == key(q, "0")[1] == key(q, "E")[1]
    assert key(q, "0")[0] == key(q, "2")[0]


def test_keypad_show_hints_off_and_small_pad():
    q = boot(props={"Show Hints": False})
    assert "swipe left" not in q.icon()
    assert q.pin("Gesture")["String"] == "TAP A KEY, SWIPE LEFT TO DELETE"
    small = boot(props={"Pad Width": 120, "Pad Height": 120})
    svg = small.icon()
    assert 'viewBox="0 0 120 120"' in svg and len(texts(svg)) >= 11
    press(small, "12")
    assert small.pin("Entry")["String"] == "12"


# ------------------------------------------------------------ key presses

def test_keypad_tap_presses_a_key_highlights_it_and_updates_entry():
    q = boot()
    x, y = key(q, "5")
    q.touch([(x, y)], lift=False)
    q.advance(0.3)                                            # inferred lift -> tap -> press
    assert q.pin("Entry")["String"] == "5"
    assert q.pin("Gesture")["String"] == "KEY 5"
    svg = q.icon()
    flashed = accent_rects(svg)
    assert len(flashed) == 1 and 'x="174.5"' in flashed[0] and 'y="191"' in flashed[0]
    q.advance(0.2)                                            # the 0.15 s highlight is over
    assert accent_rects(q.icon()) == []
    q.lift()
    press(q, "09")
    assert q.pin("Entry")["String"] == "509"
    assert q.pulses("Tap") == 3 and q.pulses("Accepted") == 0 and q.pulses("Rejected") == 0


def test_keypad_panel_touch_press_and_double_tap_enter_two_digits():
    q = boot()
    q.tap(*key(q, "3"), panel_touch=True)
    assert q.pin("Entry")["String"] == "3"
    q.double_tap(*key(q, "7"), gap=0.3, panel_touch=True)
    assert q.pin("Entry")["String"] == "377"
    assert q.pulses("DoubleTap") == 1 and q.pulses("Tap") == 3


def test_keypad_resting_finger_marks_the_key_and_a_drag_does_not_press():
    q = boot()
    x, y = key(q, "8")
    q.touch([(x, y)], lift=False)
    svg = q.icon()
    assert 'stroke="%s"' % ACCENT in svg                      # the key under the finger
    q.touch([(x + 60, y + 60)], lift=False)
    assert 'stroke="%s"' % ACCENT not in q.icon()
    q.lift()
    assert q.pin("Entry")["String"] == ""


def test_keypad_clear_key_and_swipe_left_delete():
    q = boot()
    press(q, "123")
    assert q.pin("Entry")["String"] == "123"
    q.swipe(420, 300, 80, 300)
    assert q.pulses("SwipeLeft") == 1
    assert q.pin("Entry")["String"] == "12" and q.pin("Gesture")["String"] == "DELETE"
    q.swipe(80, 300, 420, 300)                                # a swipe right does nothing
    assert q.pin("Entry")["String"] == "12"
    press(q, "C")
    assert q.pin("Entry")["String"] == "" and q.pin("Gesture")["String"] == "CLEAR"
    q.swipe(420, 300, 80, 300)                                # nothing left to delete
    assert q.pin("Entry")["String"] == ""
    assert q.pulses("Accepted") == 0 and q.pulses("Rejected") == 0


def test_keypad_entry_is_capped_at_sixteen_digits():
    q = boot()
    q.set_pin("AutoSubmit", False)
    press(q, "12345678901234567890")
    assert q.pin("Entry")["String"] == "1234567890123456"


# ------------------------------------------------------------ masked display

def test_keypad_masked_shows_dots_and_unmasked_shows_digits():
    q = boot()
    press(q, "12")
    svg = q.icon()
    dots = [c for c in circles(svg) if c[2] == 7.0]
    assert len(dots) == 2 and dots[0][1] == dots[1][1]
    assert "12" not in texts(svg) and "1234" not in svg
    assert 'fill="%s"' % TEXT in svg
    q.set_pin("Masked", False)
    q.advance(0.05)
    svg = q.icon()
    assert "12" in texts(svg)
    assert [c for c in circles(svg) if c[2] == 7.0] == []
    q.set_pin("Masked", True)
    q.advance(0.05)
    assert "12" not in texts(q.icon())
    assert q.pin("Entry")["String"] == "12"                   # the pin always carries the digits


# ------------------------------------------------------------ submit

def test_keypad_autosubmit_accepts_the_code_at_its_length():
    q = boot()
    press(q, "123")
    assert q.pulses("Accepted") == 0 and q.pulses("Rejected") == 0
    q.touch([key(q, "4")], lift=False)
    q.advance(0.3)
    assert q.pulses("Accepted") == 1 and q.pulses("Rejected") == 0
    assert q.pin("Gesture")["String"] == "ACCEPTED"
    svg = q.icon()
    assert "Accepted" in texts(svg) and 'stroke="%s"' % OK in svg
    q.lift()
    q.advance(1.0)                                            # the 0.8 s feedback is over
    assert "Accepted" not in texts(q.icon()) and "Enter code" in texts(q.icon())
    assert q.pin("Entry")["String"] == "1234"                 # the last code stays for scripts
    assert q.pin("Locked")["Boolean"] is False


def test_keypad_autosubmit_rejects_a_wrong_code_and_counts_the_attempt():
    q = boot()
    q.touch([key(q, "1")], lift=False)
    q.advance(0.3)
    q.lift()
    press(q, "23")
    q.touch([key(q, "5")], lift=False)
    q.advance(0.3)
    assert q.pulses("Rejected") == 1 and q.pulses("Accepted") == 0
    svg = q.icon()
    assert "Try again" in texts(svg) and 'stroke="%s"' % DANGER in svg
    q.lift()
    q.advance(1.0)
    assert "Attempt 1 of 5" in texts(q.icon())
    assert q.pin("Locked")["Boolean"] is False
    press(q, "1234")                                          # a success resets the count
    assert q.pulses("Accepted") == 1
    q.advance(1.0)
    assert "Attempt" not in q.icon()


def test_keypad_autosubmit_off_needs_enter_and_extra_digits_fail():
    q = boot()
    q.set_pin("AutoSubmit", False)
    press(q, "1234")
    assert q.pulses("Accepted") == 0 and q.pin("Entry")["String"] == "1234"
    press(q, "E")
    assert q.pulses("Accepted") == 1 and q.pin("Gesture")["String"] == "ACCEPTED"
    press(q, "12345E")
    assert q.pulses("Rejected") == 1 and q.pulses("Accepted") == 1
    press(q, "E")                                             # an empty entry submits nothing
    assert q.pulses("Rejected") == 1 and q.pulses("Accepted") == 1


def test_keypad_several_codes_and_blank_pin():
    q = boot()
    q.set_pin("Pin", "12, 345678, abc, 99999999999999999")
    press(q, "12")
    assert q.pulses("Accepted") == 1                          # a match submits at once
    press(q, "345678")
    assert q.pulses("Accepted") == 2 and q.pulses("Rejected") == 0
    press(q, "345679")                                        # checked at the longest code's length
    assert q.pulses("Rejected") == 1 and q.pulses("Accepted") == 2
    q.set_pin("Pin", "")
    q.advance(1.0)                                            # past the 0.8 s "Try again"
    assert "No code set" in texts(q.icon())
    press(q, "1234")
    assert q.pulses("Rejected") == 1 and q.pulses("Accepted") == 2
    press(q, "E")
    assert q.pulses("Rejected") == 2


# ------------------------------------------------------------ lockout

def test_keypad_locks_after_max_tries_for_lockout_seconds():
    q = boot()
    q.set_pin("MaxTries", 3)
    press(q, "1235")
    press(q, "1235")
    assert q.pin("Locked")["Boolean"] is False and q.pulses("Rejected") == 2
    press(q, "1235")
    assert q.pulses("Rejected") == 3
    assert q.pin("Locked")["Boolean"] is True
    assert q.pin("Gesture")["String"] == "LOCKED"
    svg = q.icon()
    assert "Locked" in texts(svg) and "Try again in 60 s" in texts(svg)
    assert '<g opacity="0.35">' in svg                        # the keys are dimmed
    assert "swipe left" not in svg
    # while locked nothing works, not even the right code, and nothing pulses
    press(q, "1234E")
    assert q.pulses("Accepted") == 0 and q.pulses("Rejected") == 3
    assert q.pin("Entry")["String"] == "1235"
    q.swipe(420, 300, 80, 300)
    assert q.pin("Entry")["String"] == "1235"
    left = q.run("return TouchPad.inst.lockUntil") - q.now    # exact seconds of lockout left
    remaining = math.ceil(left - 1e-6)                        # what the pad prints
    assert 50 < remaining <= 60                               # the taps above took a few seconds
    assert "Try again in %d s" % remaining in texts(q.icon())
    q.advance(30)
    assert "Try again in %d s" % (remaining - 30) in texts(q.icon())
    assert q.pin("Locked")["Boolean"] is True
    q.advance(left - 30 - 0.3)
    assert q.pin("Locked")["Boolean"] is True                 # not a moment early
    q.advance(1.0)
    assert q.pin("Locked")["Boolean"] is False                # exactly LockoutSeconds after the lock
    assert "Locked" not in texts(q.icon()) and "Enter code" in texts(q.icon())
    press(q, "1234")
    assert q.pulses("Accepted") == 1


def test_keypad_lockout_seconds_knob_sets_the_lockout():
    q = boot()
    q.set_pin("MaxTries", 1)
    q.set_pin("LockoutSeconds", 10)
    press(q, "0000")
    assert q.pin("Locked")["Boolean"] is True
    assert "Try again in 10 s" in texts(q.icon())
    q.advance(9.5)
    assert q.pin("Locked")["Boolean"] is True
    q.advance(1.0)
    assert q.pin("Locked")["Boolean"] is False
    press(q, "0000")                                          # the count restarted: locked again
    assert q.pin("Locked")["Boolean"] is True and q.pulses("Rejected") == 2
    q.advance(11)
    assert q.pin("Locked")["Boolean"] is False
    assert q.errors == []


def test_keypad_locked_pin_works_both_ways():
    q = boot()
    q.set_pin("Locked", True)                                 # a script locks the keypad
    q.advance(0.05)
    assert "Locked" in texts(q.icon()) and "Try again in 60 s" in texts(q.icon())
    press(q, "1234")
    assert q.pulses("Accepted") == 0 and q.pin("Entry")["String"] == ""
    q.set_pin("Locked", False)                                # and clears it early
    q.advance(0.05)
    assert "Locked" not in texts(q.icon())
    press(q, "1234")
    assert q.pulses("Accepted") == 1
    # a lockout earned by failures is also cleared by the pin, and the count resets
    q.set_pin("MaxTries", 2)
    press(q, "0000")
    press(q, "0000")
    assert q.pin("Locked")["Boolean"] is True
    q.advance(5)
    q.set_pin("Locked", False)
    assert q.pin("Locked")["Boolean"] is False
    q.advance(60)                                             # the old countdown does not fire
    assert q.pin("Locked")["Boolean"] is False
    press(q, "0000")
    assert q.pin("Locked")["Boolean"] is False                # attempt 1 of 2 again
    q.advance(1.0)                                            # past the 0.8 s "Try again"
    assert "Attempt 1 of 2" in texts(q.icon())
    press(q, "1234")
    assert q.pulses("Accepted") == 2


# ------------------------------------------------------------ learn

def test_keypad_learn_stores_the_next_code_into_pin():
    q = boot()
    q.set_pin("Learn", True)
    q.advance(0.05)
    assert "New code, then Enter" in texts(q.icon())
    press(q, "9876")                                          # no auto submit while learning
    assert q.pin("Pin")["String"] == "1234" and q.pin("Entry")["String"] == "9876"
    assert q.pulses("Accepted") == 0 and q.pulses("Rejected") == 0
    assert "Learn" in texts(q.icon())
    q.touch([key(q, "E")], lift=False)
    q.advance(0.3)
    assert q.pin("Pin")["String"] == "9876"
    assert q.pin("Learn")["Boolean"] is False
    assert q.pulses("Accepted") == 0 and q.pulses("Rejected") == 0
    assert "Code stored" in texts(q.icon()) and q.pin("Gesture")["String"] == "CODE STORED"
    q.lift()
    press(q, "9876")
    assert q.pulses("Accepted") == 1
    press(q, "1234")                                          # the old code is gone
    assert q.pulses("Rejected") == 1
    assert q.errors == []


# ------------------------------------------------------------ lock, themes, budget

def test_keypad_engine_lock_overlay_swallows_keys():
    q = boot()
    press(q, "12")
    q.set_pin("Lock", True)
    q.advance(0.05)
    svg = q.icon()
    assert 'opacity="0.72"' in svg and "Locked" in texts(svg)
    press(q, "34")
    assert q.pin("Entry")["String"] == "12" and q.pulses("Accepted") == 0
    q.set_pin("Lock", False)
    q.advance(0.05)
    assert 'opacity="0.72"' not in q.icon()
    press(q, "34")
    assert q.pulses("Accepted") == 1


def test_keypad_themes_and_transparent_background():
    light = boot(props={"Theme": "Light"})
    svg = light.icon()
    assert "#FFFFFF" in svg and "#1B1F24" in svg and ACCENT not in svg
    clear = boot(props={"Background": "Transparent", "Corner Radius": 0, "Theme": "Ocean"})
    svg = clear.icon()
    assert svg.count('<rect x="0" y="0"') == 0 and "#13232B" in svg
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300})
    assert 'viewBox="0 0 1600 300"' in wide.icon()
    press(wide, "1234")
    assert wide.pulses("Accepted") == 1


def test_keypad_frames_and_handlers_stay_within_budget():
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    q.set_pin("AutoSubmit", False)
    q.set_pin("Pin", ",".join(str(1000 + i) for i in range(32)))
    press(q, "1234567890C")
    press(q, "1031E")
    assert q.pulses("Accepted") == 1
    q.drag([(60 + 15 * i, 300 + 8 * i) for i in range(100)], seconds=2.0)
    q.set_pin("MaxTries", 1)
    press(q, "0000E")
    assert q.pin("Locked")["Boolean"] is True
    q.advance(61)
    b = q.budget()
    assert b["frames"] >= 20
    assert b["max_frame"] < 60000 and b["max_handler"] < 120000
    assert len(q.icon()) < 15000
    assert q.errors == []
