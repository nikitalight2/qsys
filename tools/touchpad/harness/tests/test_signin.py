# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: scenario tests of the Sign-In mode (25_mode_signin.lua)
"""The Sign-In pad draws a signature box under the guest fields; Submit
writes <base>/SignIns/<time>_<name>.svg and a line of SignIns/log.csv (BOM
once, formula-safe cells), pulses Submitted, sets LastGuest and TodayCount,
posts the webhook (JSON or Teams card) and clears the form. A failed save
shows "Not saved: please ask at reception" and counts nothing; TodayCount is
read from the log at start and resets at midnight; three idle minutes clear
the form; a second Submit right after a sign-in does nothing; strokes are
polylines of at most 400 points, at most 60 of them, a dot for no movement."""
import base64
import json
import math
import os
import re
import shutil
import time

from harness import QSys
from harness.qsys_fake import DEFAULT_PLUGIN, plugin_modes

ACCENT, TEXT, OK, DANGER, LINE = "#C513E8", "#F4F2F7", "#2ECC8F", "#F0328C", "#35313E"   # Nikita theme
NOT_SAVED = "Not saved: please ask at reception"
HINT = "Sign above the line, then press Sign In"

# The full plugin when it carries the Sign-In mode, else the per-mode build
# (python3 tools/touchpad/build.py --modes signin --out plugins/.build/NikitaTouchPad-signin.qplug).
PER_MODE = os.path.join(os.path.dirname(os.path.abspath(DEFAULT_PLUGIN)), ".build", "NikitaTouchPad-signin.qplug")


def defines_mode(path):
    """True when the plugin at `path` really carries Modes["Sign-In"] (MODE_NAMES
    lists every mode name whether or not its module was built in)."""
    try:
        if "Sign-In" not in plugin_modes(path):
            return False
        with open(path, "rb") as fh:
            return b'Modes["Sign-In"]' in fh.read()
    except Exception:
        return False


def plugin_path():
    if defines_mode(DEFAULT_PLUGIN):
        return DEFAULT_PLUGIN
    return PER_MODE if os.path.exists(PER_MODE) else DEFAULT_PLUGIN


def boot(**kw):
    kw.setdefault("mode", "Sign-In")
    kw.setdefault("picker", "Color_Picker")
    kw.setdefault("plugin", plugin_path())
    q = QSys(**kw)
    q.advance(0.2)
    return q


def box(q):
    """The signature box (x, y, w, h) in pad px, from the mode's own geometry."""
    return q.run("return TouchPad.inst:box()")


def strokes(q):
    return int(q.run("return TouchPad.inst:strokeCount()"))


def stroke_points(q, i):
    return int(q.run("return TouchPad.inst:strokePoints(%d)" % i))


def sign(q, n=30, amplitude=30):
    """One wavy stroke across the signature box."""
    bx, by, bw, bh = box(q)
    pts = [(bx + 30 + i * (bw - 60) / n, by + bh * 0.55 + amplitude * math.sin(i / 3.0)) for i in range(n)]
    q.drag(pts, seconds=0.8)


def press(q, name):
    q.set_pin(name, True)
    q.set_pin(name, False)


def fill(q, name="Ana Lopez", company="Acme", visiting="Nikita"):
    q.set_pin("GuestName", name)
    q.set_pin("GuestCompany", company)
    q.set_pin("Visiting", visiting)


def base_dir(q):
    return "design" if q.run("return System.IsEmulating") else "media"


def sign_in(q, name="Ana Lopez", **fields):
    fill(q, name, **fields)
    sign(q)
    press(q, "Submit")


def paths(svg):
    return re.findall(r'<path d="([^"]*)"[^>]*>', svg)


def circles(svg):
    return [tuple(float(v) for v in m.groups())
            for m in re.finditer(r'<circle cx="([-\d.]+)" cy="([-\d.]+)" r="([-\d.]+)"', svg)]


def texts(svg):
    return re.findall(r">([^<]*)</text>", svg)


def pin_styles(q):
    t = q.run("local t = {} for _, c in ipairs(GetControls(Properties)) do t[c.Name] = c.PinStyle or 'none' end return t")
    return dict(t.items())


def test_signin_controls_pins_and_idle_drawing():
    q = boot()
    styles = pin_styles(q)
    expect = {"GuestName": "Both", "GuestCompany": "Both", "Visiting": "Both", "Submit": "Input",
              "Clear": "Input", "ClearSignature": "Input", "Submitted": "Output", "LastGuest": "Output",
              "TodayCount": "Output", "RoomName": "Input", "WebhookUrl": "Input", "SendStatus": "Output",
              "PenWidth": "Input"}
    for name, style in expect.items():
        assert styles.get(name) == style, (name, styles.get(name))
    assert len(q.control_names()) == 26 + len(expect)
    assert abs(q.pin("PenWidth")["Value"] - 3) < 1e-9
    assert q.pin("TodayCount")["String"] == "0" and q.pin("SendStatus")["String"] == "Off"
    assert q.pin("Gesture")["String"] == HINT.upper()
    svg = q.icon()
    assert svg.startswith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500"')
    assert all(ord(ch) < 127 for ch in svg)
    t = texts(svg)
    assert "Visitor sign-in" in t and "Today: 0" in t and "Your name" in t and "x" in t
    assert HINT in t
    assert 'stroke-dasharray' in svg                       # the signature baseline
    assert not paths(svg) and strokes(q) == 0
    assert len(q.layout_lint()) == 0


def test_signin_stroke_is_a_simplified_polyline_with_pen_width():
    q = boot()
    bx, by, bw, bh = box(q)
    pts = [(bx + 40 + i * 8, by + 120 + 40 * math.sin(i / 4.0)) for i in range(40)]
    q.touch(pts, dt=0.04, lift=False)
    svg = q.icon()
    assert len(paths(svg)) == 1 and paths(svg)[0].startswith("M")
    assert 'stroke="%s"' % ACCENT in svg                   # the box lights up while drawing
    assert HINT not in svg                                  # no hint while the finger draws
    q.lift()
    assert strokes(q) == 1
    n = stroke_points(q, 1)
    assert 4 <= n < 40                                      # simplified, still a curve
    svg = q.icon()
    d = paths(svg)[0]
    assert d.count("L") == n - 1 and 'stroke-width="3"' in svg and 'stroke-linecap="round"' in svg
    assert 'stroke="%s"' % TEXT in svg and HINT in texts(svg)
    q.set_pin("PenWidth", 6)
    q.advance(0.1)
    assert 'stroke-width="6"' in q.icon()


def test_signin_dot_for_a_touch_without_movement():
    q = boot()
    bx, by, bw, bh = box(q)
    q.tap(bx + 100, by + 80)
    assert strokes(q) == 1 and stroke_points(q, 1) == 1
    assert (bx + 100.0, by + 80.0, 2.7) in circles(q.icon())     # 0.9 x pen width
    q.set_pin("PenWidth", 5)
    q.tap(bx + 150, by + 80, panel_touch=False)
    assert (bx + 150.0, by + 80.0, 4.5) in circles(q.icon())
    assert strokes(q) == 2 and not paths(q.icon())


def test_signin_touch_outside_the_box_is_ignored():
    q = boot()
    bx, by, bw, bh = box(q)
    q.tap(bx + 50, by - 30)                                 # the header band
    q.drag([(bx + 50, by - 40), (bx + 120, by - 20), (bx + 200, by + 40)], seconds=0.5)   # starts outside
    assert strokes(q) == 0 and not paths(q.icon())
    q.drag([(bx + 20, by + 20), (bx + 200, by - 60), (bx + bw - 10, by + bh + 12)], seconds=0.5)   # starts inside, runs out
    assert strokes(q) == 1
    q.advance(0.05)
    d = paths(q.icon())[0]
    xs = [float(v) for v in re.findall(r"[ML](-?[\d.]+) ", d)]
    ys = [float(v) for v in re.findall(r"[ML]-?[\d.]+ (-?[\d.]+)", d)]
    assert min(xs) >= bx and max(xs) <= bx + bw                # clamped to the box
    assert min(ys) >= by and max(ys) <= by + bh


def test_signin_stroke_limits_400_points_and_60_strokes():
    q = boot(props={"Max Frame Rate": "30"})
    bx, by, bw, bh = box(q)
    pts = [(bx + 10 + (i % 300) * 1.3, by + 40 + 100 * math.sin(i / 7.0) + i * 0.1) for i in range(700)]
    q.touch(pts, dt=0.034)
    assert strokes(q) == 1 and 8 < stroke_points(q, 1) <= 400
    for i in range(64):
        q.tap(bx + 20 + (i % 16) * 25, by + 30 + (i // 16) * 40)
    assert strokes(q) == 60                                  # the 61st and later are not taken
    b = q.budget()
    assert b["max_handler"] < 120000 and b["max_frame"] < 60000
    assert len(q.icon()) < 60000


def test_signin_submit_needs_a_name_and_a_signature():
    q = boot()
    press(q, "Submit")
    assert q.pulses("Submitted") == 0 and q.pin("Gesture")["String"] == "ENTER YOUR NAME"
    assert "Please enter your name" in texts(q.icon())
    assert not q.list_files()
    q.set_pin("GuestName", "Ana")
    press(q, "Submit")
    assert q.pulses("Submitted") == 0 and q.pin("Gesture")["String"] == "PLEASE SIGN"
    q.advance(0.05)
    assert "Please sign" in texts(q.icon())
    assert q.pin("TodayCount")["String"] == "0" and not q.list_files()
    q.advance(6)
    assert "Please sign" not in texts(q.icon())             # the message fades


def test_signin_submit_writes_svg_and_log_with_bom_once():
    q = boot()
    q.set_pin("RoomName", "Lobby")
    sign_in(q, "Ana Lopez", company="Acme", visiting="Nikita")
    assert q.pulses("Submitted") == 1
    assert q.pin("LastGuest")["String"] == "Ana Lopez" and q.pin("TodayCount")["String"] == "1"
    assert q.pin("Gesture")["String"] == "SIGNED IN: ANA LOPEZ"
    q.advance(0.05)
    assert "Thank you, Ana Lopez" in texts(q.icon()) and 'stroke="%s"' % OK in q.icon()
    base = base_dir(q)
    files = q.list_files()
    assert base + "/SignIns/log.csv" in files
    svgs = [f for f in files if f.endswith(".svg")]
    assert len(svgs) == 1 and re.match(r"%s/SignIns/\d{8}_\d{6}_Ana_Lopez\.svg$" % base, svgs[0])
    sig = q.read_file(svgs[0])
    assert sig.startswith("<svg") and len(paths(sig)) == 1 and 'fill="#FFFFFF"' in sig
    assert "translate(" in sig and "<text" not in sig
    raw = q.read_file(base + "/SignIns/log.csv", text=False)
    assert raw.startswith(b"\xef\xbb\xbf") and raw.count(b"\xef\xbb\xbf") == 1
    lines = raw.decode("utf-8")[1:].split("\r\n")
    assert lines[0] == "time,name,company,visiting,room,file"
    cells = lines[1].split(",")
    assert re.match(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$", cells[0])
    assert cells[1:] == ["Ana Lopez", "Acme", "Nikita", "Lobby", os.path.basename(svgs[0])]
    assert lines[2] == ""
    # the form is cleared for the next guest; the thank-you line fades
    assert q.pin("GuestName")["String"] == "" and q.pin("GuestCompany")["String"] == ""
    assert q.pin("Visiting")["String"] == "" and strokes(q) == 0
    q.advance(6)
    assert "Thank you, Ana Lopez" not in texts(q.icon())
    # a second guest appends: one BOM, one header, two rows
    q.advance(3)
    sign_in(q, "Bo", company="", visiting="")
    assert q.pulses("Submitted") == 2 and q.pin("TodayCount")["String"] == "2"
    raw = q.read_file(base + "/SignIns/log.csv", text=False)
    assert raw.count(b"\xef\xbb\xbf") == 1 and raw.count(b"time,name,") == 1
    rows = [l for l in raw.decode("utf-8").split("\r\n") if l][1:]
    assert len(rows) == 2 and rows[1].split(",")[1:4] == ["Bo", "", ""]
    assert len([f for f in q.list_files() if f.endswith(".svg")]) == 2


def test_signin_csv_cells_are_formula_safe_and_quoted():
    q = boot()
    sign_in(q, "=SUM(A1)", company="Acme, Inc", visiting='+1 "boss"')
    assert q.pulses("Submitted") == 1
    base = base_dir(q)
    row = q.read_file(base + "/SignIns/log.csv").split("\r\n")[1]
    assert ",'=SUM(A1)," in row
    assert ',"Acme, Inc",' in row
    assert ',"\'+1 ""boss""",' in row
    svgs = [f for f in q.list_files() if f.endswith(".svg")]
    assert re.search(r"_SUM_A1_?\.svg$", svgs[0]) and "=" not in os.path.basename(svgs[0])
    assert q.pin("LastGuest")["String"] == "=SUM(A1)"
    # UTF-8 names pass through the log unharmed and draw as character references
    q.advance(3)
    fill(q, "Zoë Müller", "", "")
    assert "&#235;" in q.icon() and "&#252;" in q.icon()
    sign(q)
    press(q, "Submit")
    assert "Zoë Müller" in q.read_file(base + "/SignIns/log.csv")


def test_signin_failed_save_counts_nothing_and_keeps_the_form():
    q = boot()
    base = base_dir(q)
    shutil.rmtree(os.path.join(q.files, base))               # the Core's media folder is gone
    sign_in(q, "Ana")
    assert q.pulses("Submitted") == 0
    assert q.pin("TodayCount")["String"] == "0" and q.pin("LastGuest")["String"] == ""
    q.advance(0.05)
    assert NOT_SAVED in texts(q.icon()) and 'stroke="%s"' % DANGER in q.icon()
    assert q.pin("Gesture")["String"] == "NOT SAVED"
    assert q.status().startswith(NOT_SAVED) and q.pin("Status")["Value"] == 1
    assert q.pin("GuestName")["String"] == "Ana" and strokes(q) == 1   # nothing thrown away
    assert not q.list_files()
    q.advance(10)
    assert NOT_SAVED in texts(q.icon())                     # the warning stays until the next action
    # reception fixes the folder: the same press now saves
    os.makedirs(os.path.join(q.files, base))
    press(q, "Submit")
    assert q.pulses("Submitted") == 1 and q.pin("TodayCount")["String"] == "1"
    q.advance(0.05)
    assert NOT_SAVED not in texts(q.icon()) and q.status().startswith("OK")
    assert len(q.list_files()) == 2


def test_signin_second_press_right_after_a_sign_in_does_nothing():
    q = boot()
    sign_in(q, "Ana")
    assert q.pulses("Submitted") == 1
    fill(q, "Bo")
    sign(q)
    press(q, "Submit")                                      # within 2 s of the sign-in
    assert q.pulses("Submitted") == 1 and q.pin("TodayCount")["String"] == "1"
    assert q.pin("GuestName")["String"] == "Bo" and strokes(q) == 1
    assert len([f for f in q.list_files() if f.endswith(".svg")]) == 1
    q.advance(2.5)
    press(q, "Submit")
    assert q.pulses("Submitted") == 2 and q.pin("LastGuest")["String"] == "Bo"


def test_signin_today_count_from_the_log_at_start_and_midnight_reset():
    q = QSys(mode="Sign-In", picker="Color_Picker", plugin=plugin_path(), runtime=False)
    today = time.strftime("%Y-%m-%d", time.localtime(q.epoch))
    yesterday = time.strftime("%Y-%m-%d", time.localtime(q.epoch - 86400))
    log = ("﻿time,name,company,visiting,room,file\r\n"
           + "%s 09:10:00,Old,,,,a.svg\r\n" % yesterday
           + "%s 08:00:00,Ana,,,,b.svg\r\n" % today
           + "%s 08:30:00,=Bo,,,,c.svg\r\n" % today
           + "%s 11:00:00,\"Cy, Jr\",,,,d.svg\r\n" % today)
    q.write_file("media/SignIns/log.csv", log)
    q._dispatch("load", q._chunk)
    q.advance(0.2)
    assert q.pin("TodayCount")["String"] == "3"             # today's lines only
    assert "Today: 3" in texts(q.icon())
    q.advance(3)
    sign_in(q, "Di")
    assert q.pin("TodayCount")["String"] == "4"
    rows = q.read_file("media/SignIns/log.csv").split("\r\n")
    assert rows[0] == "﻿time,name,company,visiting,room,file" and rows[-2].split(",")[1] == "Di"
    # midnight: the count starts over
    q2 = boot()
    local = time.localtime(q2.epoch)
    midnight = time.mktime((local.tm_year, local.tm_mon, local.tm_mday, 23, 59, 30, 0, 0, -1))
    q2.epoch = int(midnight)
    q2.advance(0.1)
    sign_in(q2, "Eve")
    assert q2.pin("TodayCount")["String"] == "1"
    q2.advance(45)
    assert q2.pin("TodayCount")["String"] == "0" and "Today: 0" in texts(q2.icon())
    q2.advance(3)
    sign_in(q2, "Fay")
    assert q2.pin("TodayCount")["String"] == "1"
    assert len(q2.read_file("media/SignIns/log.csv").split("\r\n")) == 4   # header, two rows, trailing


def test_signin_idle_three_minutes_clears_the_form():
    q = boot()
    fill(q, "Ana", "Acme", "Nikita")
    sign(q)
    q.advance(120)
    assert q.pin("GuestName")["String"] == "Ana" and strokes(q) == 1
    bx, by, bw, bh = box(q)
    q.tap(bx + 60, by + 60)                                 # activity restarts the clock
    q.advance(120)
    assert q.pin("GuestName")["String"] == "Ana" and strokes(q) == 2
    q.advance(75)
    assert q.pin("GuestName")["String"] == "" and q.pin("GuestCompany")["String"] == ""
    assert q.pin("Visiting")["String"] == "" and strokes(q) == 0
    assert q.pulses("Submitted") == 0 and not q.list_files()
    assert "Your name" in texts(q.icon()) and not paths(q.icon())
    # typing in a field also counts as activity
    q.set_pin("GuestName", "Bo")
    q.advance(150)
    q.set_pin("GuestCompany", "Acme")
    q.advance(150)
    assert q.pin("GuestName")["String"] == "Bo"
    q.advance(45)
    assert q.pin("GuestName")["String"] == ""


def test_signin_webhook_json_posts_the_record_and_the_signature():
    q = boot(props={"Sign-In Webhook": "JSON"})
    assert q.pin("SendStatus")["String"] == "Ready"
    q.set_pin("WebhookUrl", " https://hooks.example.test/signin ")
    q.set_pin("RoomName", "Boardroom")
    sign_in(q, "Ana Lopez", company="Acme", visiting="Nikita")
    assert q.pin("SendStatus")["String"] == "Sending..."
    assert len(q.http_posts) == 1
    post = q.http_posts[0]
    assert post["url"] == "https://hooks.example.test/signin" and post["method"] == "POST"
    assert post["headers"]["Content-Type"] == "application/json"
    body = json.loads(post["body"])
    assert set(body) == {"name", "company", "visiting", "room", "time", "signature", "file"}
    assert body["name"] == "Ana Lopez" and body["company"] == "Acme" and body["visiting"] == "Nikita"
    assert body["room"] == "Boardroom"
    assert re.match(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", body["time"])
    svgs = [f for f in q.list_files() if f.endswith(".svg")]
    assert body["file"] == os.path.basename(svgs[0])
    assert base64.b64decode(body["signature"]).decode("utf-8") == q.read_file(svgs[0])
    q.advance(0.05)
    assert q.pin("SendStatus")["String"] == "Sent 200"
    assert q.status().startswith("OK")


def test_signin_webhook_teams_card():
    q = boot(props={"Sign-In Webhook": "Teams Card"})
    q.set_pin("WebhookUrl", "https://teams.example.test/webhook")
    q.set_pin("RoomName", "Lobby")
    sign_in(q, "Ana", company="Acme", visiting="Nikita")
    assert len(q.http_posts) == 1
    body = json.loads(q.http_posts[0]["body"])
    assert body["type"] == "message" and len(body["attachments"]) == 1
    att = body["attachments"][0]
    assert att["contentType"] == "application/vnd.microsoft.card.adaptive"
    card = att["content"]
    assert card["type"] == "AdaptiveCard" and card["version"] == "1.4"
    assert card["$schema"] == "http://adaptivecards.io/schemas/adaptive-card.json"
    assert card["body"][0]["type"] == "TextBlock" and card["body"][1]["type"] == "FactSet"
    facts = {f["title"]: f["value"] for f in card["body"][1]["facts"]}
    assert facts["Name"] == "Ana" and facts["Company"] == "Acme" and facts["Visiting"] == "Nikita"
    assert facts["Room"] == "Lobby" and re.match(r"\d{4}-\d{2}-\d{2}T", facts["Time"])
    assert "signature" not in q.http_posts[0]["body"]
    q.advance(0.05)
    assert q.pin("SendStatus")["String"] == "Sent 200"


def test_signin_webhook_failure_off_and_blank_url():
    q = boot(props={"Sign-In Webhook": "JSON"})
    q.set_pin("WebhookUrl", "https://hooks.example.test/x")
    q.http_reply = (500, "boom", None)
    sign_in(q, "Ana")
    q.advance(0.05)
    assert q.pin("SendStatus")["String"] == "Send failed: HTTP 500"
    assert "Webhook failed" in q.status() and q.pin("Status")["Value"] == 1
    assert q.pulses("Submitted") == 1 and q.pin("TodayCount")["String"] == "1"   # the sign-in itself stood
    q.http_reply = (0, "", "connection refused")
    q.advance(3)
    sign_in(q, "Bo")
    q.advance(0.05)
    assert q.pin("SendStatus")["String"] == "Send failed: connection refused"
    # a blank URL posts nothing
    q.set_pin("WebhookUrl", "")
    q.advance(3)
    sign_in(q, "Cy")
    assert len(q.http_posts) == 2 and q.pulses("Submitted") == 3
    # Off never posts
    off = boot()
    off.set_pin("WebhookUrl", "https://hooks.example.test/x")
    sign_in(off, "Ana")
    assert off.http_posts == [] and off.pin("SendStatus")["String"] == "Off" and off.pulses("Submitted") == 1


def test_signin_clear_and_clear_signature():
    q = boot()
    fill(q, "Ana", "Acme", "Nikita")
    sign(q)
    bx, by, bw, bh = box(q)
    q.tap(bx + 40, by + 40)
    assert strokes(q) == 2
    press(q, "ClearSignature")
    assert strokes(q) == 0 and not paths(q.icon()) and q.pin("Gesture")["String"] == "SIGNATURE CLEARED"
    assert q.pin("GuestName")["String"] == "Ana" and "Ana" in texts(q.icon())
    sign(q)
    press(q, "Clear")
    assert strokes(q) == 0 and q.pin("GuestName")["String"] == "" and q.pin("Visiting")["String"] == ""
    assert q.pin("Gesture")["String"] == "CLEARED" and "Your name" in texts(q.icon())
    assert q.pulses("Submitted") == 0 and not q.list_files()


def test_signin_fields_show_on_the_pad():
    q = boot()
    q.set_pin("GuestName", "  Ana Lopez  ")
    q.set_pin("GuestCompany", "Acme")
    q.set_pin("Visiting", "Nikita")
    q.set_pin("RoomName", "Lobby")
    q.advance(0.05)
    t = texts(q.icon())
    assert "Ana Lopez" in t and "Acme  -  visiting Nikita" in t
    assert any(s.startswith("Lobby") and s.endswith("Today: 0") for s in t)
    assert "Your name" not in t
    q.set_pin("GuestCompany", "")
    q.advance(0.05)
    assert "visiting Nikita" in texts(q.icon())
    long = "A" * 200
    q.set_pin("GuestName", long)
    q.advance(0.05)
    assert any(s.endswith("...") for s in texts(q.icon()))   # fitted to the pad width
    assert len(q.icon()) < 4000


def test_signin_resume_after_an_inferred_lift_starts_a_new_stroke():
    q = boot()
    bx, by, bw, bh = box(q)
    q.touch([(bx + 50, by + 100), (bx + 80, by + 120), (bx + 110, by + 100)], dt=0.05, lift=False)
    q.advance(0.5)                                          # silence: the lift is inferred
    assert strokes(q) == 1
    q.touch([(bx + 118, by + 104), (bx + 150, by + 130), (bx + 180, by + 100)], dt=0.05, lift=False)   # resumed
    assert strokes(q) == 1 and len(paths(q.icon())) == 2    # the old ink plus the live stroke, not joined
    q.lift()
    assert strokes(q) == 2 and len(paths(q.icon())) == 2
    d1, d2 = paths(q.icon())
    assert d1.endswith("L%s %s" % (bx + 110, by + 100)) and d2.startswith("M%s %s" % (bx + 118, by + 104))


def test_signin_lock_hints_off_and_emulate_base():
    q = boot()
    bx, by, bw, bh = box(q)
    q.touch([(bx + 50, by + 100), (bx + 90, by + 140)], dt=0.05, panel_touch=True, lift=False)
    q.set_pin("Lock", True)
    q.advance(0.05)
    assert strokes(q) == 1 and "Locked" in q.icon()         # the stroke so far is kept
    q.lift()
    q.set_pin("Lock", False)
    q.tap(bx + 200, by + 100, panel_touch=True)
    assert strokes(q) == 2
    quiet = boot(props={"Show Hints": False})
    assert HINT not in quiet.icon() and quiet.pin("Gesture")["String"] == HINT.upper()
    emu = boot(emulate=True)
    sign_in(emu, "Ana")
    assert emu.pulses("Submitted") == 1
    assert all(f.startswith("design/SignIns/") for f in emu.list_files()) and len(emu.list_files()) == 2


def test_signin_pad_sizes_themes_and_budget():
    small = boot(props={"Pad Width": 160, "Pad Height": 120})
    bx, by, bw, bh = box(small)
    assert bw > 100 and bh >= 24 and by + bh <= 120
    sign_in(small, "Ana")
    assert small.pulses("Submitted") == 1 and len(small.icon()) < 60000
    light = boot(props={"Theme": "Light", "Pad Width": 800, "Pad Height": 400})
    assert "#F4F4F6" in light.icon() and 'viewBox="0 0 800 400"' in light.icon()
    q = boot(props={"Pad Width": 1600, "Pad Height": 1200, "Max Frame Rate": "30"})
    bx, by, bw, bh = box(q)
    for s in range(30):
        pts = [(bx + 20 + s * 40 + i * 2, by + 100 + 300 * abs(math.sin(i / 9.0)) + s * 10) for i in range(80)]
        q.touch(pts, dt=0.034)
    assert strokes(q) == 30
    fill(q, "Ana Lopez", "Acme", "Nikita")
    press(q, "Submit")
    assert q.pulses("Submitted") == 1
    b = q.budget()
    assert b["frames"] >= 40
    assert b["max_handler"] < 120000 and b["max_frame"] < 60000
    assert len(q.icon()) < 20000
