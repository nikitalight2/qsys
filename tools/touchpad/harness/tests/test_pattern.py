# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Pattern Lock mode (23_mode_pattern.lua)
"""A dot grid (3x3 to 5x5); a drag joins dots and the lift checks the drawn
pattern against `Pattern`. Unlocked / Failed pulse, LastPattern records the
drawing, Learn stores the next pattern, Locked goes on after MaxTries failures
for LockoutSeconds and works from its pin both ways, Masked hides the trail
(a row of small dots under the top line counts the joined dots) and AutoSubmit
checks as soon as the drawing is as long as the secret (never while learning).
A pattern has at least two dots: a one-dot drawing (a tap on a dot) is dropped
without a check or a try, and a one-dot Pattern text is no secret."""
import os
import re
import sys

from harness import QSys
from harness.qsys_fake import DEFAULT_PLUGIN, plugin_modes

OK, DANGER = "#2ECC8F", "#F0328C"          # the Nikita theme's ok / danger colours

# The full plugin when it carries the Pattern Lock mode, else the per-mode build
# (python3 tools/touchpad/build.py --modes pattern --out plugins/.build/NikitaTouchPad-pattern.qplug).
PER_MODE = os.path.join(os.path.dirname(os.path.abspath(DEFAULT_PLUGIN)), ".build", "NikitaTouchPad-pattern.qplug")


def has_pattern(path):
    try:
        return os.path.exists(path) and "Pattern Lock" in plugin_modes(path)
    except Exception:
        return False


def plugin_path():
    """run_tests.py --plugin (it only lints that file, so honour it here too),
    else the newer of the full plugin and the per-mode build with Pattern Lock."""
    argv = sys.argv
    for i, a in enumerate(argv):
        if a == "--plugin" and i + 1 < len(argv) and has_pattern(argv[i + 1]):
            return argv[i + 1]
        if a.startswith("--plugin=") and has_pattern(a[len("--plugin="):]):
            return a[len("--plugin="):]
    candidates = [p for p in (DEFAULT_PLUGIN, PER_MODE) if has_pattern(p)]
    if not candidates:
        return DEFAULT_PLUGIN
    return max(candidates, key=os.path.getmtime)


def boot(**kw):
    kw.setdefault("mode", "Pattern Lock")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", plugin_path())
    q = QSys(**kw)
    q.advance(0.2)
    return q


def dot(q, k):
    """Centre of dot k in pad px, read from the mode instance."""
    return q.run("local d = TouchPad.inst.dots[%d] return d.x, d.y" % k)


def path_points(q, dots, steps=4):
    """A finger path through the given dots with `steps` points per segment."""
    out = []
    for i, k in enumerate(dots):
        x1, y1 = dot(q, k)
        if i == 0:
            out.append((x1, y1))
            continue
        x0, y0 = dot(q, dots[i - 1])
        for s in range(1, steps + 1):
            out.append((x0 + (x1 - x0) * s / steps, y0 + (y1 - y0) * s / steps))
    return out


def draw(q, dots, **kw):
    """Draws through the dots slowly enough not to be a swipe (0.1 s per point)."""
    kw.setdefault("panel_touch", True)
    kw.setdefault("dt", 0.1)
    q.touch(path_points(q, dots), **kw)


def circles(svg):
    return [tuple(float(v) for v in m.groups())
            for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)"', svg)]


def test_pattern_controls_pins_and_idle_drawing():
    q = boot()
    names = q.control_names()
    for name in ("GridSize", "Pattern", "Unlocked", "Failed", "Locked", "MaxTries", "LockoutSeconds",
                 "LastPattern", "Learn", "Masked", "AutoSubmit"):
        assert name in names, name
    assert len(names) == 26 + 11
    assert q.pin("GridSize")["Value"] == 3 and q.pin("MaxTries")["Value"] == 5
    assert q.pin("LockoutSeconds")["Value"] == 60 and q.pin("Locked")["Boolean"] is False
    assert q.pin("Gesture")["String"] == "DRAW YOUR PATTERN"
    assert q.status().startswith("OK")
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    assert len(circles(svg)) == 9                              # nine idle dots, nothing else
    assert dot(q, 1) == (70.0, 70.0) and dot(q, 5) == (250.0, 250.0) and dot(q, 9) == (430.0, 430.0)
    assert "Set a pattern first" in svg                        # no secret yet
    assert "<polyline" not in svg
    q.set_pin("Pattern", "1-5-9")
    q.advance(0.1)
    assert "Draw your pattern" in q.icon() and "Set a pattern first" not in q.icon()
    assert q.layout_lint() == []


def test_pattern_correct_pattern_unlocks_and_feedback_fades():
    q = boot()
    q.set_pin("Pattern", "1-5-9-6")
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 1 and q.pulses("Failed") == 0
    assert q.pin("LastPattern")["String"] == "1-5-9-6"
    assert q.pin("Gesture")["String"] == "UNLOCKED"
    assert q.pin("Locked")["Boolean"] is False
    svg = q.icon()
    assert "Unlocked" in svg and OK in svg and "<polyline" in svg   # green feedback with the trail
    assert "Draw your pattern" not in svg
    q.advance(1.0)                                             # feedback lasts 0.8 s
    svg = q.icon()
    assert OK not in svg and "<polyline" not in svg and "Unlocked" not in svg
    assert "Draw your pattern" in svg


def test_pattern_accepts_digit_string_and_separators():
    q = boot()
    q.set_pin("Pattern", "1596")
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 1
    q.advance(1.0)
    q.set_pin("Pattern", " 3, 5 ,7 ")
    draw(q, [3, 5, 7])
    assert q.pulses("Unlocked") == 2 and q.pulses("Failed") == 0


def test_pattern_wrong_pattern_fails_and_counts_tries():
    q = boot()
    q.set_pin("Pattern", "1-5-9-6")
    draw(q, [1, 2, 3])
    assert q.pulses("Failed") == 1 and q.pulses("Unlocked") == 0
    assert q.pin("LastPattern")["String"] == "1-2-3"
    assert q.pin("Gesture")["String"] == "FAILED"
    assert q.pin("Locked")["Boolean"] is False
    svg = q.icon()
    assert "Try 1 of 5" in svg and DANGER in svg
    q.advance(1.0)
    assert "Try 1 of 5" in q.icon() and DANGER not in q.icon()   # the count stays, the red fades
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 1                           # a success resets the count
    q.advance(1.0)
    assert "Try " not in q.icon()


def test_pattern_skipped_dot_between_two_dots_is_added():
    q = boot()
    q.set_pin("Pattern", "1-2-3")
    q.touch([dot(q, 1), dot(q, 3)], panel_touch=True)          # jumps straight to 3: 2 lies between
    assert q.pin("LastPattern")["String"] == "1-2-3" and q.pulses("Unlocked") == 1
    q.advance(1.0)
    q.touch([dot(q, 1), dot(q, 9)], panel_touch=True)          # diagonal: 5 lies between
    assert q.pin("LastPattern")["String"] == "1-5-9"
    q.advance(1.0)
    q.touch([dot(q, 7), dot(q, 1)], panel_touch=True)          # upwards: 4 lies between
    assert q.pin("LastPattern")["String"] == "7-4-1"
    q.advance(1.0)
    q.touch([dot(q, 2), dot(q, 1), dot(q, 3)], panel_touch=True)   # 2 already in: 1 -> 3 does not repeat it
    assert q.pin("LastPattern")["String"] == "2-1-3"
    q.advance(1.0)
    q.touch([dot(q, 2), dot(q, 9)], panel_touch=True)          # a knight's move skips nothing
    assert q.pin("LastPattern")["String"] == "2-9"


def test_pattern_hit_radius_and_no_repeats():
    q = boot()
    q.set_pin("Pattern", "2-5-6")
    spacing = 180.0
    x5, y5 = dot(q, 5)
    far = (x5 + 0.3 * spacing, y5 - 0.3 * spacing)            # 0.42 spacings from dot 5: not added
    q.touch([dot(q, 2), far, dot(q, 6)], panel_touch=True)
    assert q.pin("LastPattern")["String"] == "2-6" and q.pulses("Failed") == 1
    q.advance(1.0)
    near = (x5 + 0.15 * spacing, y5 - 0.15 * spacing)         # 0.21 spacings: added
    q.touch([dot(q, 2), near, dot(q, 6)], panel_touch=True)
    assert q.pin("LastPattern")["String"] == "2-5-6" and q.pulses("Unlocked") == 1
    q.advance(1.0)
    draw(q, [2, 5, 2, 5, 6])                                   # going back does not repeat a dot
    assert q.pin("LastPattern")["String"] == "2-5-6" and q.pulses("Unlocked") == 2
    q.advance(1.0)
    q.tap(250, 160, panel_touch=True)                          # a tap away from every dot checks nothing
    assert q.pulses("Failed") == 1 and q.pulses("Unlocked") == 2 and q.pulses("Tap") == 1


def test_pattern_lockout_after_max_tries():
    q = boot()
    q.set_pin("Pattern", "1-5-9-6")
    q.set_pin("MaxTries", 2)
    q.set_pin("LockoutSeconds", 10)
    draw(q, [1, 2, 3])
    assert q.pulses("Failed") == 1 and q.pin("Locked")["Boolean"] is False
    draw(q, [1, 2, 3])
    assert q.pulses("Failed") == 2 and q.pin("Locked")["Boolean"] is True
    svg = q.icon()
    assert "Try again in" in svg and "Locked" in svg
    assert q.pin("Gesture")["String"] == "LOCKED 10 S"
    # while locked nothing pulses, not even the right pattern
    draw(q, [1, 5, 9, 6])
    draw(q, [1, 2, 3])
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 2
    assert q.pin("LastPattern")["String"] == "1-2-3"
    assert q.pulses("Press") == 4                              # the engine still saw the touches
    q.advance(4.0)
    assert re.search(r"Try again in [1-5] s", q.icon())       # the countdown is drawn
    q.advance(6.5)                                             # the lockout is over
    assert q.pin("Locked")["Boolean"] is False
    assert "Try again in" not in q.icon() and "Draw your pattern" in q.icon()
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 1
    q.advance(1.0)
    draw(q, [1, 2, 3])                                         # the try count started afresh
    assert q.pin("Locked")["Boolean"] is False and "Try 1 of 2" in q.icon()


def test_pattern_locked_pin_works_both_ways():
    q = boot()
    q.set_pin("Pattern", "1-5-9-6")
    q.set_pin("LockoutSeconds", 20)
    q.set_pin("Locked", True)                                  # a script locks the pad
    q.advance(0.05)
    assert "Try again in 20 s" in q.icon()
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    q.set_pin("Locked", False)                                 # ... and clears it early
    q.advance(0.05)
    assert "Try again in" not in q.icon()
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 1
    q.advance(1.0)
    q.set_pin("Locked", True)                                  # a script lock also times out
    q.advance(20.5)
    assert q.pin("Locked")["Boolean"] is False
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 2
    q.advance(1.0)
    # the pad's own lockout can be cleared from the pin
    q.set_pin("MaxTries", 1)
    draw(q, [1, 2])
    assert q.pin("Locked")["Boolean"] is True
    q.set_pin("Locked", False)
    draw(q, [1, 5, 9, 6])
    assert q.pulses("Unlocked") == 3


def test_pattern_learn_stores_the_next_pattern():
    q = boot()
    q.set_pin("Learn", True)
    q.advance(0.05)
    assert "Draw the new pattern" in q.icon()
    draw(q, [3, 5, 7, 8])
    assert q.pin("Pattern")["String"] == "3-5-7-8"
    assert q.pin("LastPattern")["String"] == "3-5-7-8"
    assert q.pin("Learn")["Boolean"] is False                  # one pattern only
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    assert "Pattern stored" in q.icon() and OK in q.icon()
    assert q.pin("Gesture")["String"] == "PATTERN STORED"
    q.advance(1.0)
    draw(q, [3, 5, 7, 8])
    assert q.pulses("Unlocked") == 1
    q.advance(1.0)
    draw(q, [1, 5, 9])
    assert q.pulses("Failed") == 1 and q.pin("Pattern")["String"] == "3-5-7-8"


def test_pattern_masked_display_hides_the_trail():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    r = q.run("return TouchPad.inst.r")
    assert r == 18.0
    draw(q, [1, 5], lift=False)
    svg = q.icon()
    assert "<polyline" in svg and (70.0, 70.0, r) in circles(svg)      # trail and lit dots
    assert (70.0, 70.0, round(r * 1.9, 1)) in circles(svg)             # the halo
    q.lift()
    q.advance(1.0)
    q.set_pin("Masked", True)
    draw(q, [1, 5], lift=False)
    svg = q.icon()
    assert "<polyline" not in svg
    assert (70.0, 70.0, round(r * 1.9, 1)) not in circles(svg) # no halo on the lit dot
    assert svg.count("#C513E8") == 2                           # the accent only on the two masking dots
    assert len([c for c in circles(svg) if c[2] == 4.0]) == 2   # two masking dots
    draw(q, [9], lift=False)
    assert len([c for c in circles(q.icon()) if c[2] == 4.0]) == 3
    q.lift()
    assert q.pulses("Unlocked") == 1 and q.pin("LastPattern")["String"] == "1-5-9"
    assert "<polyline" not in q.icon()                         # the feedback stays masked too


def test_pattern_auto_submit_checks_before_the_lift():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    draw(q, [1, 5, 9, 6], lift=False)
    assert q.pulses("Unlocked") == 0                           # off by default: lift = check
    q.lift()
    assert q.pulses("Failed") == 1
    q.advance(1.0)
    q.set_pin("AutoSubmit", True)
    draw(q, [1, 5], lift=False)
    assert q.pulses("Unlocked") == 0
    draw(q, [9], lift=False)
    assert q.pulses("Unlocked") == 1                           # three dots: checked at once
    assert q.pin("LastPattern")["String"] == "1-5-9"
    draw(q, [6], lift=False)                                   # more dots change nothing
    q.lift()
    assert q.pulses("Unlocked") == 1 and q.pulses("Failed") == 1
    assert q.pin("LastPattern")["String"] == "1-5-9"


def test_pattern_grid_size_four_and_five():
    q = boot()
    q.set_pin("GridSize", 4)
    q.advance(0.05)
    assert len(circles(q.icon())) == 16
    q.set_pin("Pattern", "1-6-11-16")
    q.touch([dot(q, 1), dot(q, 16)], panel_touch=True)         # the diagonal adds 6 and 11
    assert q.pin("LastPattern")["String"] == "1-6-11-16" and q.pulses("Unlocked") == 1
    q.advance(1.0)
    q.touch([dot(q, 1), dot(q, 13)], panel_touch=True)         # down the first column: 5 and 9
    assert q.pin("LastPattern")["String"] == "1-5-9-13"
    q.advance(1.0)
    q.set_pin("GridSize", 5)
    q.advance(0.05)
    assert len(circles(q.icon())) == 25
    q.set_pin("Pattern", "1-7-13-19-25-99")                    # 99 does not exist: dropped
    draw(q, [1, 7, 13, 19, 25])
    assert q.pulses("Unlocked") == 2
    q.advance(1.0)
    q.set_pin("GridSize", 3)
    q.advance(0.05)
    assert len(circles(q.icon())) == 9
    draw(q, [1, 5, 9])                                         # 13..25 are gone: "1-7"
    assert q.pulses("Failed") == 2                             # (the first was "1-5-9-13" above)
    assert q.run("return #TouchPad.inst.secret") == 2


def test_pattern_inferred_lift_waits_for_a_resume():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    q.touch(path_points(q, [1, 5]), lift=False)                # no Panel Touch wired
    q.advance(0.5)                                             # silence: the lift is inferred
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    assert "<polyline" in q.icon()                             # the trail waits
    q.touch(path_points(q, [5, 9])[1:], lift=False)            # the finger resumes nearby
    q.advance(0.5)
    assert q.pulses("Failed") == 0
    q.advance(1.5)                                             # the resume window is over
    assert q.pulses("Unlocked") == 1 and q.pin("LastPattern")["String"] == "1-5-9"
    q.advance(1.0)
    q.touch(path_points(q, [1, 2]), lift=False)
    q.advance(0.5)
    # A new touch submits the pending drawing first. Its first report, so soon
    # after an un-resumed pause, is taken for a lift-off shift by the engine:
    # the finger rests on dot 1 for a moment before moving on.
    q.touch([dot(q, 1)] + path_points(q, [1, 5, 9]))
    assert q.pulses("Failed") == 1 and q.pulses("Unlocked") == 1
    q.advance(1.7)                                             # ... and its own inferred lift waits again
    assert q.pulses("Unlocked") == 2


def test_pattern_pad_lock_drops_the_drawing():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    draw(q, [1, 5], lift=False)
    q.set_pin("Lock", True)
    q.advance(0.05)
    assert "Locked" in q.icon() and "<polyline" not in q.icon()
    q.lift()
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    assert q.pin("LastPattern")["String"] == ""
    q.set_pin("Lock", False)
    draw(q, [1, 5, 9])
    assert q.pulses("Unlocked") == 1


def test_pattern_show_hints_off_and_empty_secret_never_unlocks():
    q = boot(props={"Show Hints": False})
    assert "Set a pattern first" not in q.icon() and "Draw your pattern" not in q.icon()
    draw(q, [1, 5, 9])
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 1   # no secret: a failure
    q.set_pin("Pattern", "x-y")                                # no digits: still no secret
    q.advance(1.0)
    draw(q, [1, 5, 9])
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 2
    assert "Draw your pattern" not in q.icon()


def test_pattern_themes_sizes_and_budget():
    light = boot(props={"Theme": "Light", "Background": "Panel"})
    light.set_pin("Pattern", "1-5-9")
    draw(light, [1, 2])
    assert "#D92D20" in light.icon()                           # the Light theme's danger colour
    small = boot(props={"Pad Width": 120, "Pad Height": 120})
    small.set_pin("Pattern", "1-5-9")
    draw(small, [1, 5, 9])
    assert small.pulses("Unlocked") == 1 and len(circles(small.icon())) >= 9
    wide = boot(props={"Pad Width": 1600, "Pad Height": 300})
    assert dot(wide, 1)[0] > 600 and len(circles(wide.icon())) == 9
    big = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    big.set_pin("GridSize", 5)
    big.set_pin("MaxTries", 10)
    big.set_pin("Pattern", "1-2-3-4-5-10-15-20-25-24-23-22-21-16-11-6-7-8-9-14-19-18-17-12-13")
    big.touch(path_points(big, [1, 5, 25, 21, 6, 9, 19, 17, 12, 13], steps=12), panel_touch=True)
    assert big.pulses("Unlocked") == 1                         # every skipped dot on the way was added
    big.advance(1.0)
    big.touch(path_points(big, [1, 25, 5, 21, 3, 23, 11, 15], steps=12), panel_touch=True)
    assert big.pulses("Failed") == 1
    b = big.budget()
    assert b["max_handler"] < 60000 and b["max_frame"] < 30000
    assert len(big.icon()) < 8000


# ---------------------------------------------------------------------------
# Regression tests from the review of the first version.


def texts(svg):
    return [(float(m.group(1)), float(m.group(2)), float(m.group(3)), m.group(4))
            for m in re.finditer(r'<text x="([-\d.]+)" y="([-\d.]+)"[^>]*font-size="([\d.]+)"[^>]*>([^<]*)</text>', svg)]


def text_box(t):
    """(top, bottom) of a text's glyph box: baseline y, size -> about y - 0.72 size .. y."""
    return t[1] - 0.72 * t[2], t[1]


def test_pattern_pending_check_that_locks_stops_the_new_touch():
    """No Panel Touch: a wrong drawing is lifted by silence (its check is pending),
    and a new touch far away lands inside the resume window. The new touch
    submits the pending drawing first; when that check reaches MaxTries the
    pad locks and the new touch must not go on drawing or checking."""
    q = boot()
    q.set_pin("Pattern", "1-5-9-6")
    q.set_pin("MaxTries", 1)
    q.set_pin("LockoutSeconds", 30)
    q.touch(path_points(q, [9, 8]), lift=False)                # wrong, no Panel Touch
    q.advance(0.5)                                             # inferred lift: the check waits
    assert q.pulses("Failed") == 0 and q.pin("Locked")["Boolean"] is False
    q.touch(path_points(q, [1, 5, 9, 6]), lift=False)          # a press far from dot 8, not a resume
    assert q.pulses("Failed") == 1 and q.pin("Locked")["Boolean"] is True
    assert q.run("return TouchPad.inst.active") is False       # the new touch was dropped
    assert q.run("return #TouchPad.inst.path") == 0
    q.advance(0.5)
    q.advance(1.7)                                             # where its own check would have run
    assert q.pin("Locked")["Boolean"] is True
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 1
    assert q.pin("LastPattern")["String"] == "9-8"
    assert "Try again in" in q.icon() and "<polyline" not in q.icon()
    # The same guard inside one touch: an AutoSubmit check that locks the pad
    # ends the drawing; the finger going on and lifting changes nothing.
    q.set_pin("Locked", False)
    q.set_pin("AutoSubmit", True)
    q.set_pin("Pattern", "1-5-9")
    draw(q, [1, 2, 3], lift=False)                             # three dots: checked and locked at once
    assert q.pulses("Failed") == 2 and q.pin("Locked")["Boolean"] is True
    draw(q, [6, 9], lift=False)
    q.lift()
    assert q.pulses("Failed") == 2 and q.pulses("Unlocked") == 0
    assert q.pin("LastPattern")["String"] == "1-2-3"


def test_pattern_auto_submit_never_cuts_a_learned_pattern_short():
    q = boot()
    q.set_pin("Pattern", "1-2-3")
    q.set_pin("AutoSubmit", True)
    q.set_pin("Learn", True)
    q.advance(0.05)
    draw(q, [1, 5, 9, 6, 3], lift=False)                       # longer than the old secret
    assert q.pin("Pattern")["String"] == "1-2-3"               # nothing stored before the lift
    assert q.pin("Learn")["Boolean"] is True
    q.lift()
    assert q.pin("Pattern")["String"] == "1-5-9-6-3" and q.pin("LastPattern")["String"] == "1-5-9-6-3"
    assert q.pin("Learn")["Boolean"] is False
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    q.advance(1.0)
    draw(q, [1, 5, 9], lift=False)                             # AutoSubmit is back for checks
    assert q.pulses("Failed") == 0
    draw(q, [6, 3], lift=False)
    assert q.pulses("Unlocked") == 1                           # five dots: checked before the lift
    q.lift()
    assert q.pulses("Unlocked") == 1


def test_pattern_same_value_grid_size_write_is_a_no_op():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    draw(q, [1, 5], lift=False)
    assert q.run("return #TouchPad.inst.path") == 2
    q.set_pin("GridSize", 3, fire=True)                        # a script re-asserts the same value
    assert q.run("return #TouchPad.inst.path") == 2            # the drawing in progress stays
    draw(q, [9], lift=False)
    q.lift()
    assert q.pulses("Unlocked") == 1 and q.pin("LastPattern")["String"] == "1-5-9"
    q.advance(1.0)
    draw(q, [1, 5], lift=False)
    q.set_pin("GridSize", 4)                                   # a real change drops the drawing
    assert q.run("return #TouchPad.inst.path") == 0 and len(circles(q.icon())) == 16
    q.lift()
    assert q.pulses("Unlocked") == 1 and q.pulses("Failed") == 0
    q = boot()                                                 # Panel Touch is sticky: a fresh pad
    q.set_pin("Pattern", "1-5-9")
    q.touch(path_points(q, [1, 5, 9]), lift=False)             # no Panel Touch: the check is pending
    q.advance(0.5)
    q.set_pin("GridSize", 3, fire=True)
    assert q.run("return TouchPad.inst.pending ~= nil") is True   # the pending check survives
    q.advance(2.0)
    assert q.pulses("Unlocked") == 1 and q.pin("LastPattern")["String"] == "1-5-9"


def test_pattern_pending_check_feedback_shows_after_a_new_touch():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    q.touch(path_points(q, [1, 5, 9]), lift=False)             # right, no Panel Touch
    q.advance(0.5)                                             # inferred lift: pending
    assert q.pulses("Unlocked") == 0
    q.touch([dot(q, 1)], lift=False)                           # a new press far from dot 9
    assert q.pulses("Unlocked") == 1                           # the pending drawing was checked
    q.advance(0.05)
    svg = q.icon()
    assert "Unlocked" in svg and OK in svg                     # ... and its green result shows
    assert q.run("return TouchPad.inst.feedback ~= nil") is True
    q.advance(0.3)
    assert "Unlocked" in q.icon()
    q.advance(0.6)                                             # 0.8 s are over
    assert "Unlocked" not in q.icon()
    # The result colours its own trail, not the drawing that began under it.
    q.advance(1.0)
    q.touch(path_points(q, [1, 2, 3]), lift=False)             # wrong, pending
    q.advance(0.5)
    q.touch(path_points(q, [7, 8]), lift=False)                # new press: the red result shows
    assert q.pulses("Failed") == 1
    svg = q.icon()
    assert "Try 1 of 5" in svg and DANGER in svg
    assert '<polyline' in svg and 'stroke="%s"' % DANGER not in svg   # the new trail is not red
    q.lift()


def test_pattern_pending_check_uses_learn_as_it_was_at_the_lift():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    q.touch(path_points(q, [3, 5, 7]), lift=False)             # wrong, no Panel Touch
    q.advance(0.5)                                             # pending
    q.set_pin("Learn", True)                                   # Learn goes on while the check waits
    q.advance(1.7)
    assert q.pulses("Failed") == 1 and q.pin("Pattern")["String"] == "1-5-9"   # not stored
    assert q.pin("Learn")["Boolean"] is True                   # Learn waits for a pattern drawn under it
    q.advance(1.0)
    q.touch(path_points(q, [2, 5, 8]), lift=False)
    q.advance(0.5)
    q.set_pin("Learn", False)                                  # switched off while this one waits
    q.advance(1.7)
    assert q.pin("Pattern")["String"] == "2-5-8"               # drawn under Learn: stored
    assert q.pulses("Failed") == 1 and q.pulses("Unlocked") == 0


def test_pattern_one_dot_touch_is_not_a_pattern():
    q = boot()
    q.set_pin("Pattern", "1-5-9-6")
    q.set_pin("MaxTries", 2)
    q.tap(*dot(q, 5), panel_touch=True)                        # stray taps on a dot
    q.advance(0.5)
    q.tap(*dot(q, 5), panel_touch=True)
    assert q.pulses("Failed") == 0 and q.pin("Locked")["Boolean"] is False
    assert q.pin("LastPattern")["String"] == "" and q.pulses("Tap") == 2
    assert "Try " not in q.icon() and "<polyline" not in q.icon()
    q.set_pin("Learn", True)
    q.tap(*dot(q, 5), panel_touch=True)                        # a tap cannot become the secret
    assert q.pin("Pattern")["String"] == "1-5-9-6" and q.pin("Learn")["Boolean"] is True
    draw(q, [3, 5, 7])
    assert q.pin("Pattern")["String"] == "3-5-7" and q.pin("Learn")["Boolean"] is False
    q.advance(1.0)
    q.set_pin("Pattern", "5")                                  # a one-dot secret is no secret
    q.advance(0.05)
    assert q.run("return #TouchPad.inst.secret") == 0 and "Set a pattern first" in q.icon()
    q.tap(*dot(q, 5), panel_touch=True)
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    draw(q, [5, 9])
    assert q.pulses("Failed") == 1                             # two dots are checked (and fail)


def test_pattern_one_dot_wobble_is_dropped_at_once():
    """A finger resting on one dot for longer than a tap, moving a few px, is
    lifted by silence. The engine can only resume a touch that dragged (12 px),
    so this lift is final: nothing waits for the resume window."""
    q = boot()
    q.set_pin("Pattern", "5-9")
    x, y = dot(q, 5)
    q.touch([(x + i, y) for i in range(5)], dt=0.1, lift=False)   # 4 px over 0.4 s, no Panel Touch
    q.advance(0.5)                                             # the lift is inferred
    assert q.run("return TouchPad.inst.pending ~= nil") is False
    assert q.run("return #TouchPad.inst.path") == 0 and "<polyline" not in q.icon()
    assert "Draw your pattern" in q.icon()                     # the hint is back at once
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    q.advance(1.7)
    assert q.pulses("Unlocked") == 0 and q.pulses("Failed") == 0
    # A one-dot touch that did drag (out and back) can still be resumed.
    q.touch([(x, y), (x + 30, y), (x, y)], dt=0.1, lift=False)
    q.advance(0.5)
    assert q.run("return TouchPad.inst.pending ~= nil") is True
    q.touch(path_points(q, [5, 9])[1:], lift=False)            # the finger resumes nearby
    q.advance(0.5)
    q.advance(1.7)
    assert q.pulses("Unlocked") == 1 and q.pin("LastPattern")["String"] == "5-9"


def test_pattern_masked_dots_have_their_own_line():
    q = boot()
    q.set_pin("Pattern", "1-5-9")
    q.set_pin("Masked", True)
    draw(q, [1, 5, 9])
    svg = q.icon()
    mask = [c for c in circles(svg) if c[2] == 4.0]
    tx = [t for t in texts(svg) if t[3] == "Unlocked"]
    assert len(mask) == 3 and len(tx) == 1
    top, bottom = text_box(tx[0])
    for cx, cy, r in mask:
        assert cy - r >= bottom + 2                            # below the top line
        assert cy + r <= dot(q, 1)[1] - q.run("return TouchPad.inst.r") - 2   # above the first row
    assert mask[0][1] == mask[1][1] == mask[2][1] == 41.0
    assert dot(q, 1) == (70.0, 70.0) and dot(q, 9) == (430.0, 430.0)   # the grid did not move
    q.advance(1.0)
    q.set_pin("Learn", True)
    draw(q, [1, 2], lift=False)
    svg = q.icon()
    prompt = [t for t in texts(svg) if t[3] == "Draw the new pattern"]
    mask = [c for c in circles(svg) if c[2] == 4.0]
    assert len(prompt) == 1 and len(mask) == 2
    assert all(cy - r >= text_box(prompt[0])[1] + 2 for cx, cy, r in mask)
    q.lift()


def test_pattern_small_pads_keep_the_texts_off_the_dots():
    def dot_rows(q):
        r = q.run("return TouchPad.inst.r")
        return sorted(set(c[1] for c in circles(q.icon()) if abs(c[2] - r) < 0.1)), r   # the SVG rounds r

    # 120 px: there is no room for the top line or the hint, so neither is drawn
    q = boot(props={"Pad Width": 120, "Pad Height": 120})
    q.set_pin("Pattern", "1-5-9")
    assert "Draw your pattern" not in q.icon()
    draw(q, [1, 2])
    svg = q.icon()
    rows, r = dot_rows(q)
    assert len(rows) == 3 and rows[1] - rows[0] >= 36         # the grid never gets smaller than this
    assert q.pulses("Failed") == 1 and DANGER in svg           # the colour still carries the result
    assert not [t for t in texts(svg) if "Try" in t[3]]
    q.set_pin("Masked", True)
    q.advance(1.0)
    draw(q, [1, 5], lift=False)
    assert not [c for c in circles(q.icon()) if c[2] == 4.0]  # no room for the masking line either
    q.lift()
    q.advance(1.0)
    draw(q, [1, 5, 9])
    assert q.pulses("Unlocked") == 1

    # 200 px and a wide 1600 x 300: everything shows and nothing overlaps the dots
    for w, h in ((200, 200), (1600, 300), (300, 1200)):
        q = boot(props={"Pad Width": w, "Pad Height": h})
        q.set_pin("Pattern", "1-5-9")
        q.set_pin("Masked", True)
        assert "Draw your pattern" in q.icon()
        draw(q, [1, 2])
        svg = q.icon()
        rows, r = dot_rows(q)
        tries = [t for t in texts(svg) if "Try 1" in t[3]]
        mask = [c for c in circles(svg) if c[2] == 4.0]
        assert len(tries) == 1 and len(mask) == 2, (w, h)
        assert text_box(tries[0])[1] < mask[0][1] - 4, (w, h)          # top line above the masking dots
        assert mask[0][1] + 4 < rows[0] - r, (w, h)                    # masking dots above the first row
        q.advance(1.0)
        hint = [t for t in texts(q.icon()) if t[3] == "Draw your pattern"]
        assert len(hint) == 1 and rows[-1] + r < text_box(hint[0])[0], (w, h)   # last row above the hint
        assert q.budget()["max_frame"] < 30000
