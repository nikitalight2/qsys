# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: tests of the fake Q-SYS runtime against the fixture plugin
"""Every fake API is exercised here through fixtures/mini_plugin.lua."""
import os

from harness import QSys, BudgetError, LuaHandlerError, HarnessError, FIXTURE_PLUGIN


def fixture(**kw):
    kw.setdefault("plugin", FIXTURE_PLUGIN)
    kw.setdefault("picker", "Color_Picker")
    return QSys(**kw)


# ------------------------------------------------------------ design time

def test_controls_follow_getcontrols_with_count_quirk():
    q = fixture(props={"Zones": 1}, mode="Zone Select")
    assert q.pin("ZoneSelected")["Boolean"] is False          # Count 1: a single object
    assert q.pin("ZoneSelected", 1)["Index"] == 1
    try:
        q.pin("ZoneSelected", 2)
        assert False, "index 2 on a Count 1 control"
    except HarnessError:
        pass
    q3 = fixture(props={"Zones": 3}, mode="Zone Select")
    assert [q3.pin("ZoneSelected", i)["Index"] for i in (1, 2, 3)] == [1, 2, 3]
    assert q3.pin("ZoneSelected 2")["Key"] == "ZoneSelected 2"   # "Name n" addressing
    try:
        q3.pin("ZoneSelected")
        assert False, "array without index"
    except HarnessError:
        pass
    assert "ZoneSelected 3" in q3.control_names() and "Display" in q3.control_names()
    assert q3.run("return #Controls.ZoneSelected") == 3
    assert q3.run("return Controls.ZoneSelected[1].Index") == 1


def test_properties_mode_and_overrides():
    q = fixture(mode="Zone Select", props={"Pad Width": 640, "Zones": 3})
    assert q.run('return Properties["Mode"].Value') == "Zone Select"
    assert q.run('return Properties["Pad Width"].Value') == 640
    assert q.run('return Properties["Pad Height"].Value') == 500
    assert q.run('return Properties["Zones"].IsHidden') is False
    assert q.pad_size == (640.0, 500.0)
    try:
        fixture(props={"No Such Property": 1})
        assert False, "unknown property accepted"
    except HarnessError:
        pass


def test_knob_coherence():
    q = fixture()
    q.set_pin("Level", -20)
    p = q.pin("Level")
    assert p["Value"] == -20 and abs(p["Position"] - (80 / 110)) < 1e-9 and p["String"] == "-20.0dB"
    q.set_pin("Level", {"Position": 1.0})
    assert q.pin("Level")["Value"] == 10
    q.set_pin("Level", 500)                                 # clamped to Max
    assert q.pin("Level")["Value"] == 10 and q.pin("Level")["Boolean"] is True
    q.set_pin("Level", "-6.5dB")                            # String parses a number
    assert abs(q.pin("Level")["Value"] + 6.5) < 1e-9
    q.set_pin("Counter", 2.6)                               # Integer unit rounds
    assert q.pin("Counter")["Value"] == 3 and q.pin("Counter")["String"] == "3"
    q.run("Controls.X.Position = 0.25")
    assert abs(q.pin("X")["Value"] - 0.25) < 1e-9 and q.pin("X")["String"] == "0.25"


def test_button_text_status_coherence():
    q = fixture(props={"Zones": 2}, mode="Zone Select")
    q.set_pin("ZoneSelected", True, index=1)
    p = q.pin("ZoneSelected", 1)
    assert p["Boolean"] is True and p["Value"] == 1 and p["Position"] == 1 and p["String"] == "true"
    q.run("Controls.ZoneSelected[1].Value = 0")
    assert q.pin("ZoneSelected", 1)["Boolean"] is False
    q.set_pin("ZoneName", "Stage", index=2)
    p = q.pin("ZoneName", 2)
    assert p["String"] == "Stage" and p["Value"] == 0 and p["Boolean"] is False
    q.set_pin("ZoneName", "42", index=2)
    assert q.pin("ZoneName", 2)["Value"] == 42
    q.run('Controls.Status.Value = 2; Controls.Status.String = "Fault text"')
    s = q.pin("Status")
    assert s["Value"] == 2 and s["String"] == "Fault text" and abs(s["Position"] - 0.4) < 1e-9
    q.run("Controls.Status.Value = 9")
    assert q.pin("Status")["Value"] == 5                   # clamped to the 0..5 states
    q.run('Controls.Display.Color = "#FFFFFF"; Controls.Picker.Choices = {"a", "b"}; Controls.Display.IsInvisible = true')
    assert q.pin("Display")["Color"] == "#FFFFFF" and q.pin("Picker")["Choices"] == ["a", "b"]
    assert q.pin("Display")["IsInvisible"] is True and q.pin("Display")["IsDisabled"] is True


def test_unknown_control_property_write_raises():
    q = fixture()
    ok, err = q.run('return pcall(function() Controls.X.Values = 1 end)')
    assert ok is False and "no property 'Values'" in err
    ok, err = q.run('return pcall(function() Controls.X.EventHandler = 5 end)')
    assert ok is False and "must be a function" in err
    assert q.run("return Controls.X.NoSuchThing") is None


# ------------------------------------------------------- picker binding

def test_picker_binding_and_status():
    q = fixture()
    assert q.status() == "OK - Color_Picker (saturation, value)"
    q2 = fixture(picker="Pick2", picker_names=("hsv_s", "hsv_v"), props={"Color Picker": "Pick2"})
    assert q2.status() == "OK - Pick2 (hsv_s, hsv_v)"
    assert sorted(q2.picker.controls) == ["color_picker_surface", "hsv_s", "hsv_v", "hue"]
    q3 = fixture(props={"Color Picker": "Nope"})
    assert q3.status() == "No picker named Nope"
    q4 = fixture(picker=None, props={"Color Picker": "Gain1"})
    q4.add_component("Gain1", "gain", {"gain": {"Value": 0, "Min": -100, "Max": 20}, "mute": {"Boolean": False}})
    q4.set_pin("Refresh", True)
    assert q4.status() == "Gain1 is not a Color Picker"
    q5 = fixture(picker=None)
    assert q5.status() == "No Color Picker in the design"
    q5.add_picker("Late")
    q5.set_pin("Picker", "Late")                               # Picker text override rebinds
    assert q5.status() == "OK - Late (saturation, value)"
    q6 = fixture(picker=None, props={"Debug Print": "All"})
    q6.add_picker("A")
    q6.add_picker("B")
    q6.set_pin("Refresh", True)
    assert q6.status() == "2 Color Pickers in the design: name one"
    assert any(line.startswith("picker control: ") for line in q6.output()) is False  # bind stopped early


def test_component_api_from_lua():
    q = fixture(picker=None)
    cam = q.add_component("Cam1", "camera", {"pan.speed": {"Value": 0.5, "Min": -1, "Max": 1}, "home": {"Boolean": False},
                                             "name": {"String": "Lobby"}})
    assert q.run('return Component.New("Cam1")["pan.speed"].Value') == 0.5
    assert q.run('return Component.New("Cam1").name.String') == "Lobby"
    assert q.run('return Component.New("Cam1").missing') is None
    ok, err = q.run('return pcall(Component.New, "Ghost")')
    assert ok is False and "Ghost" in err
    names = q.run('local t = {} for _, c in ipairs(Component.GetComponents()) do t[#t + 1] = c.Name .. ":" .. c.Type end return table.concat(t, ",")')
    assert names == "Cam1:camera"
    info = q.run('local t = {} for _, c in ipairs(Component.GetControls("Cam1")) do t[#t + 1] = c.Name .. "=" .. tostring(c.Position) end return table.concat(t, ",")')
    assert info == "pan.speed=0.75,home=0,name=0"
    assert q.run('return #Component.GetControls("Ghost")') == 0
    q.run('Component.New("Cam1").home.Boolean = true')
    assert cam.get("home")["Boolean"] is True
    cam.set("pan.speed", -1)
    assert q.run('return Component.New("Cam1")["pan.speed"].Position') == 0
    q.remove_component("Cam1")
    assert q.run("return #Component.GetComponents()") == 0
    q7 = fixture(picker=None, missing_component="empty")
    assert q7.run('return type(Component.New("Ghost"))') == "table"


# ----------------------------------------------------------------- touch

def test_tap_in_panel_mode():
    q = fixture()
    assert q.icon() is None
    q.tap(250, 125)
    assert q.pulses("Tap") == 1
    assert q.pin("Touching")["Boolean"] is False
    assert abs(q.pin("X")["Value"] - 0.5) < 1e-9 and abs(q.pin("Y")["Value"] - 0.75) < 1e-9   # Y up
    assert q.pin("Gesture")["String"] == "TAP"
    svg = q.icon()
    assert svg.startswith("<svg") and "TAP" in svg and q.icons >= 2
    assert q.pin("Display")["Legend"].startswith('{"DrawChrome":false,"IconData":"')
    q.reset_pulses()
    assert q.pulses("Tap") == 0
    assert q.budget()["max_handler"] > 0


def test_designer_mode_axis_gap_and_suppression():
    q = fixture(emulate=True, props={"Debug Print": "All"})
    assert q.touch_mode == "designer"
    q.tap(250, 250)
    reports = [l for l in q.output() if l.startswith("report ")]
    assert len(reports) == 2, reports
    t1 = float(reports[0].split("t=")[1])
    t2 = float(reports[1].split("t=")[1])
    assert abs((t2 - t1) - 0.06) < 1e-6
    u = float(reports[1].split("u=")[1].split()[0])
    assert abs(u - 0.5 * 4 / 7) < 1e-3                      # Designer geometry: the pad is the left 4/7
    assert q.pulses("Tap") == 1
    q.advance(0.5)                                            # the picker parks at (0, 0)
    assert q.picker.position == (0.0, 0.0)
    q.clear_output()
    q.tap(250, 250)                                           # same spot again after a park: reported again
    assert q.pulses("Tap") == 2
    q.touch([(250, 250)], lift=False)                         # finger down, then the same spot: suppressed
    n = len([l for l in q.output() if l.startswith("report ")])
    q.touch([(250, 250)], lift=False)
    assert len([l for l in q.output() if l.startswith("report ")]) == n
    q.touch([(250, 300)], lift=False)                         # one axis only: one report, no gap
    reports = [l for l in q.output() if l.startswith("report ")]
    assert len(reports) == n + 1
    q.lift()
    assert q.pin("Touching")["Boolean"] is False


def test_panel_touch_press_release_and_long_press():
    q = fixture()
    q.touch([(100, 100)], panel_touch=True, lift=False)
    assert q.pin("PanelTouch")["Boolean"] is True and q.pin("Touching")["Boolean"] is True
    q.advance(2.0)                                            # no silence lift while PanelTouch is on
    assert q.pin("Touching")["Boolean"] is True
    q.lift()
    assert q.pin("PanelTouch")["Boolean"] is False and q.pin("Touching")["Boolean"] is False
    assert q.pin("Gesture")["String"] == "RELEASE"
    q.reset_pulses()
    q.long_press(200, 200, seconds=1.0)
    assert q.pulses("Tap") == 0 and q.pin("Gesture")["String"] == "RELEASE"
    q.tap(300, 300, panel_touch=True)
    assert q.pulses("Tap") == 1


def test_drag_swipe_pause_and_frames():
    q = fixture()
    q.drag([(50, 50), (250, 250), (450, 450)], seconds=0.4)
    assert abs(q.pin("X")["Value"] - 0.9) < 1e-9 and abs(q.pin("Y")["Value"] - 0.1) < 1e-9
    assert q.pin("Gesture")["String"] == "RELEASE"
    b = q.budget()
    assert b["frames"] >= 3 and b["max_frame"] > 0 and "frame:timer" in b["handlers"]
    before = q.icons
    q.swipe(100, 250, 400, 250, seconds=0.2)
    assert q.icons > before
    q.reset_pulses()
    # A pause longer than ReleaseTime mid-drag is an inferred lift, then a new press.
    q.touch([(100, 100), (120, 120), (300, 300), (320, 320)], dt=0.05, pause=(2, 0.6))
    assert q.pin("Gesture")["String"] == "RELEASE"
    presses = [l for l in q.output() if "PRESS" in l]
    assert len(presses) == 0                                   # Gesture text is not printed; check the icon count instead
    assert q.icons > before + 1


def test_double_tap_and_outside_touch():
    q = fixture()
    q.double_tap(200, 200, gap=0.4)        # without PanelTouch the gap must exceed ReleaseTime
    assert q.pulses("Tap") == 2
    q.reset_pulses()
    q.double_tap(200, 200, gap=0.15, panel_touch=True)
    assert q.pulses("Tap") == 2
    e = fixture(emulate=True)
    e.calibration = (0.0, 0.0, 4.0 / 7.0, 1.0)
    e.tap(600, 250)                                            # right of the pad: inside the picker, ignored
    assert e.pulses("Tap") == 0 and e.pin("Touching")["Boolean"] is False


def test_park_echo_is_ignored():
    q = fixture(props={"Debug Print": "All"})
    q.tap(100, 400)
    q.advance(0.4)
    assert q.picker.position == (0.0, 0.0)
    assert any("park echo ignored" in l for l in q.output())
    assert q.pin("Touching")["Boolean"] is False and q.pin("Gesture")["String"] == "TAP"
    assert q.pulses("Tap") == 1


# ------------------------------------------------------ handlers / echo

def test_external_write_fires_handler():
    q = fixture(mode="Zone Select", props={"Zones": 3})
    q.set_pin("Level", -20)
    assert q.pin("Gesture")["String"] == "LEVEL -20.0"
    assert q.set_pin("Level", -20) is False                  # unchanged: no handler
    assert q.set_pin("Level", -20, fire=True) is False and q.instructions("ctl:Level") > 0
    q.set_pin("ZoneSelected", True, index=1)
    q.set_pin("ZoneSelected", True, index=3)
    assert q.pin("SelectedList")["String"] == "1,3"
    q.set_pin("ZoneName", "Stage", index=2)
    assert q.pin("Gesture")["String"] == "ZONE 2 Stage"
    q.set_pin("Tap", True)
    assert q.pin("Gesture")["String"] == "TAP IN"
    q.trigger("Level")
    assert q.instructions("trigger:Level") > 0


def test_echo_on_self_write_flag():
    q = fixture()
    q.tap(100, 100)                                           # the plugin pulses Tap itself
    assert any("echo ignored: Tap" in l for l in q.output())
    quiet = fixture(echo_on_self_write=False)
    quiet.tap(100, 100)
    assert quiet.pulses("Tap") == 1
    assert not any("echo ignored" in l for l in quiet.output())
    assert quiet.F.echo is False


def test_recovered_error_and_uncaught_errors():
    q = fixture()
    q.set_pin("Crash", True)
    assert q.status().startswith("Recovered from an error: ") and "deliberate fixture error" in q.status()
    assert q.errors == []
    q.allow_errors = True                                     # tells run_tests the errors are deliberate
    q.run('Controls.Save.EventHandler = function() error("boom") end')
    try:
        q.set_pin("Save", True)
        assert False, "uncaught error should raise"
    except LuaHandlerError as exc:
        assert "boom" in str(exc)
    assert len(q.errors) == 1 and q.errors[0][0] == "ctl:Save"
    assert any(l.startswith("LUA ERROR in ctl:Save") for l in q.output())
    q.strict_errors = False
    q.set_pin("Save", False)                                  # the handler errors on both edges
    q.set_pin("Save", True)
    assert len(q.errors) == 3


# ---------------------------------------------------------------- timers

def test_timers_virtual_clock():
    q = fixture()
    assert q.now == 0.0 and q.run("return Timer.Now()") == 0.0
    q.advance(3.5)
    assert q.now == 3.5 and q.pin("Counter")["Value"] == 3
    q.run('''
      Seen = {}
      Timer.CallAfter(function() Seen[#Seen + 1] = "b" .. Timer.Now() end, 0.2)
      Timer.CallAfter(function() Seen[#Seen + 1] = "a" .. Timer.Now() end, 0.1)
      Rep = Timer.New()
      Rep.EventHandler = function(t) Seen[#Seen + 1] = "r" .. Timer.Now(); if #Seen >= 4 then t:Stop() end end
      Rep:Start(0.15)
    ''')
    q.advance(1.0)
    assert q.run("return table.concat(Seen, ',')") == "a3.6,r3.65,b3.7,r3.8"
    assert q.run("return Rep:IsRunning()") is False
    assert q.pending_events() >= 3                            # the fixture's own timers keep running
    assert q.pin("Counter")["Value"] == 4
    ok, err = q.run("return pcall(function() Rep:Start(0) end)")
    assert ok is False and "positive" in err
    try:
        q.advance(-1)
        assert False
    except HarnessError:
        pass


def test_os_time_and_date_follow_the_clock():
    q = fixture()
    t0 = q.run("return os.time()")
    assert t0 == q.epoch
    assert q.run('return os.date("%Y-%m-%d %H:%M:%S")') == "2026-10-10 12:00:00"
    q.advance(3600 + 61)
    assert q.run("return os.time()") == t0 + 3661
    assert q.run('return os.date("%H:%M:%S")') == "13:01:01"
    assert q.run('return os.date("!%Y-%m-%dT%H:%M:%SZ", 0)') == "1970-01-01T00:00:00Z"
    ok, err = q.run("return pcall(os.clock)")
    assert ok is False and "os.clock" in err
    assert q.run("return os.getenv") is None


# ------------------------------------------------- json / crypto / require

def test_rapidjson_and_crypto():
    q = fixture()
    assert q.run('return require("rapidjson").encode({b = 1, a = {1, 2, "x"}, c = true, d = "q\\"\\n"})') == '{"a":[1,2,"x"],"b":1,"c":true,"d":"q\\"\\n"}'
    assert q.run('return require("json").encode({})') == "{}"
    assert q.run('return require("rapidjson").encode(setmetatable({}, {__jsontype = "array"}))') == "[]"
    assert q.run('return require("rapidjson").encode({x = 0.5, n = require("rapidjson").null})') == '{"n":null,"x":0.5}'
    assert q.run('local j = require("rapidjson"); local t = j.decode(\'{"a":[1,2.5,{"b":null}],"s":"\\\\u00e9 ok","t":true}\'); return t.a[2], t.a[3].b == j.null, t.s, t.t') == (2.5, True, "\u00e9 ok", True)
    assert q.run('local v, err = require("rapidjson").decode("{bad"); return v == nil, type(err)') == (True, "string")
    assert q.run('local v, err = require("rapidjson").decode("[1] x"); return v == nil') is True
    assert q.run('return Crypto.Base64Encode("Man")') == "TWFu"
    assert q.run('return Crypto.Base64Encode("Ma"), Crypto.Base64Encode("Ma", false)') == ("TWE=", "TWE")
    assert q.run('return Crypto.Base64Decode("TWFu"), Crypto.Base64Decode("TWE=")') == ("Man", "Ma")
    assert q.run('return Crypto.Base64Decode(Crypto.Base64Encode("\\0\\1\\255")) == "\\0\\1\\255"') is True
    ok, err = q.run('return pcall(require, "socket")')
    assert ok is False and "not found" in err
    assert q.run("return package") is None


def test_library_work_is_not_counted():
    q = fixture()
    q.run('''
      Controls.Save.EventHandler = function()
        local big = string.rep("x", 60000)
        for i = 1, 20 do Crypto.Base64Encode(big) end
        require("rapidjson").encode({ a = big })
      end
    ''')
    q.set_pin("Save", True)
    assert q.instructions("ctl:Save") < 2000


# ------------------------------------------------------------------ http

def test_http_upload_and_reply():
    q = fixture()
    q.set_pin("Post", True)
    assert len(q.http_posts) == 1
    p = q.http_posts[0]
    assert p["url"] == "https://example.invalid/hook" and p["method"] == "POST" and p["kind"] == "Upload"
    assert p["headers"] == {"Content-Type": "application/json"} and p["timeout"] == 10
    assert '"name":"fixture"' in p["body"] and '"time":"2026-10-10T' in p["body"]
    assert p["code"] is None and q.pin("Gesture")["String"] == "READY"
    q.advance(0.05)
    assert q.pin("Gesture")["String"] == "HTTP 200" and q.http_posts[0]["code"] == 200
    q.http_reply = (500, "", "timeout")
    q.set_pin("Post", False)
    q.set_pin("Post", True)
    q.advance(0.05)
    assert q.pin("Gesture")["String"] == "HTTP 500 timeout"
    ok, err = q.run('return pcall(HttpClient.Upload, { Url = "x", Method = "GET" })')
    assert ok is False and "POST, PUT or PATCH" in err
    assert q.run('return HttpClient.EncodeString("a b/c")') == "a%20b%2Fc"
    assert q.instructions("http") > 0


# --------------------------------------------------------------- sockets

def test_udp_and_tcp():
    q = fixture()
    q.set_pin("Net", True)
    assert q.udp_sent == [("10.0.0.5", 52381, b"\x81\x01\x04\x07\x02\xff")]
    assert q.tcp_connects == [("10.0.0.6", 5678)] and q.tcp_sent == []
    assert q.inject_udp(b"\x90\x50\xff", address="10.0.0.5", port=52381) == 1
    assert q.pin("Gesture")["String"] == "UDP 3 10.0.0.5"
    assert q.inject_tcp(b"early\r\n") == 0                    # nothing is connected yet
    q.advance(0.05)                                           # the connect completes
    assert q.tcp_sent == [("10.0.0.6", 5678, b"hello\r\n")]
    assert q.run("return Sockets.tcp.IsConnected") is True
    q.inject_tcp(b"pong\r\nsecond\r\npartial")
    assert q.pin("Gesture")["String"] == "TCP second"
    assert q.run("return Sockets.tcp.BufferLength") == 7
    q.inject_tcp(b"\r\n")
    assert q.pin("Gesture")["String"] == "TCP partial"
    q.tcp_event("Error", err="reset by peer")
    assert q.pin("Gesture")["String"] == "TCP ERROR reset by peer"
    assert q.run("return Sockets.tcp.IsConnected") is False
    ok, err = q.run('return pcall(Sockets.tcp.Write, Sockets.tcp, "x")')
    assert ok is False and "not connected" in err
    q.tcp_event("Closed", index=1)
    assert q.pin("Gesture")["String"] == "TCP CLOSED"
    assert q.instructions("tcp:data") > 0 and q.instructions("udp") > 0
    assert q.run('''
      local s = TcpSocket.New(); s._buf = "ab\\0cd\\n"; s.IsConnected = true
      return s:ReadLine(TcpSocket.EOL.Null), s:Read(1), s:ReadLine(TcpSocket.EOL.Any), s:Read(5)
    ''') == ("ab", "c", "d", None)


# ----------------------------------------------------------------- files

def test_files_sandbox():
    q = fixture()
    q.set_pin("Save", True)
    assert q.pin("Gesture")["String"] == "SAVED 1"
    assert q.file_exists("media/Fixture/log.csv") and q.list_files() == ["media/Fixture/log.csv"]
    assert q.read_file("media/Fixture/log.csv") == "2026-10-10 12:00:00,fixture\n"
    assert q.log == [("message", "fixture saved 1")]
    e = fixture(emulate=True)
    e.set_pin("Save", True)
    assert e.file_exists("design/Fixture/log.csv") and not e.file_exists("media/Fixture/log.csv")
    assert q.run('return (io.open("/etc/passwd"))') is None
    assert q.run('return (io.open("media/../x", "w"))') is None
    assert q.run('local f, err = io.open("other/x", "w"); return f == nil and err') == "other/x: Permission denied (paths must start with media/ or design/)"
    assert q.run('return (io.open("media/missing/x", "w"))') is None   # parent folder must exist
    assert q.run('return dir.create("media/a/b")') is None
    assert q.run('return dir.create("media/a")') is True
    assert q.run('return dir.create("media/a/b")') is True
    names = q.run('local t = {} for _, e in ipairs(dir.get("media")) do t[#t + 1] = e.name .. ":" .. e.type end return table.concat(t, ",")')
    assert names == "Fixture:directory,a:directory"
    assert q.run('return dir.get("media/none")') is None
    q.write_file("media/seed.txt", "hello")
    assert q.run('local f = io.open("media/seed.txt"); local s = f:read("*a"); f:close(); return s') == "hello"
    assert q.run("return io.popen") is None
    assert os.path.isdir(q.files)
    q.close()
    assert not os.path.isdir(q.files)


# ---------------------------------------------------------------- budget

def test_budget_and_labels():
    q = fixture()
    q.tap(100, 100)
    b = q.budget()
    assert set(["load", "ctl:Color_Picker~saturation", "ctl:Color_Picker~value", "timer", "callafter"]) <= set(b["handlers"])
    assert b["load"] == b["handlers"]["load"] and b["dispatches"] > 5
    assert "frame:load" not in b["handlers"]                  # the load draws the first frame but is not one
    assert b["max_handler"] == max(v for k, v in b["handlers"].items() if k != "load" and not k.startswith("frame:"))
    q.allow_budget = True                                     # tells run_tests the breach is deliberate
    q.run('Controls.Save.EventHandler = function() local s = 0 for i = 1, 100000 do s = s + i end end')
    q.set_pin("Save", True)
    assert q.instructions("ctl:Save") > 120000
    try:
        q.budget()
        assert False, "budget breach not raised"
    except BudgetError as exc:
        assert "ctl:Save" in str(exc)
    assert q.budget(strict=False)["max_handler"] > 120000
    q.strict = False
    assert q.budget()["max_handler"] > 120000
    # a frame is any dispatch that changed Display's icon
    f = fixture()
    f.allow_budget = True
    f.run('Controls.Save.EventHandler = function() local s = 0 for i = 1, 50000 do s = s + i end Controls.Display.Legend = "{\\"DrawChrome\\":false}" end')
    f.set_pin("Save", True)
    try:
        f.budget()
        assert False, "frame breach not raised"
    except BudgetError as exc:
        assert "frame" in str(exc)


def test_nested_dispatch_counts_inner_and_outer():
    q = fixture()
    q.run('''
      Controls.Level.EventHandler = function() local s = 0 for i = 1, 3000 do s = s + i end end
      Controls.Save.EventHandler = function()
        Controls.Level.Value = Controls.Level.Value - 1   -- fires Level's handler inside Save's
        local s = 0 for i = 1, 1000 do s = s + i end
      end
    ''')
    q.set_pin("Save", True)
    inner, outer = q.instructions("ctl:Level"), q.instructions("ctl:Save")
    assert inner > 10000 and outer > inner


# ----------------------------------------------------------------- lint

def test_layout_lint_clean_and_broken():
    q = fixture(mode="Zone Select")
    assert q.layout_lint(matrix=[{}, {"Zones": 1}, {"Zones": 4}, {"Pad Width": 1600, "Pad Height": 1200}]) == []
    q.run('''
      local real = GetControlLayout
      function GetControlLayout(props)
        local layout, graphics = real(props)
        layout["Ghost"] = { Style = "Led", Position = { 10, 10 }, Size = { 16, 16 } }
        layout["Level"] = nil
        layout["Gesture"] = nil
        if layout["Display"] then layout["Display"].Position = { 700, 700 } end
        graphics[#graphics + 1] = { Type = "Label", Text = "caf\\xC3\\xA9", Position = { 0, 0 }, Size = { 10, 10 } }
        graphics[#graphics + 1] = { Type = "Label", Text = "Nikita Visual Arts \\xE2\\x80\\x93 nikitavisual.art", Position = { 0, 20 }, Size = { 10, 10 } }
        return layout, graphics
      end
    ''')
    problems = q.layout_lint()
    text = "\n".join(problems)
    assert "unknown control 'Ghost'" in text
    assert "control 'Level' is not placed on any page" in text
    assert "control 'Gesture' is not placed on any page" in text
    assert "leaves the 760 x 560 page" in text
    assert "non-ASCII text" in text and "caf" in text
    assert "nikitavisual" not in text                           # the brand en dash is allowed
    assert all(p.startswith("Zone Select") for p in problems)
