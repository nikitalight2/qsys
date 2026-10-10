# Nikita Visual Arts – nikitavisual.art
## Touch Pad for Q-SYS: offline test harness

A fake Q-SYS control engine in Python + `lupa` (Lua 5.3). It loads a `.qplug`
exactly as a Core would (the whole file once at design time with `Controls`
nil, then again with `Controls` set), replaces every Q-SYS global with a fake,
replays finger paths through a fake Color Picker, runs timers on a virtual
clock and counts the VM instructions of every callback. Spec sections 7, 12
and 13 are the contract; `fixtures/mini_plugin.lua` is a tiny plugin that
exercises every fake API and doubles as a worked example of the engine
patterns (picker discovery, LANDING, echo guard, park, Legend icon, pcall).

### Running

    python3 tools/touchpad/harness/run_tests.py             # lint the built plugin + every tests/test_*.py
    python3 tools/touchpad/harness/run_tests.py -k tap -v   # tests whose name contains "tap", full tracebacks
    python3 tools/touchpad/harness/run_tests.py --no-lint tests/test_harness.py
    python3 tools/touchpad/harness/run_tests.py --plugin build/other.qplug

`run_tests.py` first loads `plugins/NikitaTouchPad.qplug` once per mode in
`MODE_NAMES` and runs `layout_lint` over every page for every property set in
its `LINT_MATRIX` (sets naming a property the plugin does not have are
skipped). It then imports each `tests/test_*.py`, runs every `test_*`
function in file order and prints one row per test: PASS/FAIL, the largest
handler instruction count and the largest frame count over every `QSys` the
test created, and the time. Exit code 1 on any failure, lint problem, budget
breach or uncaught Lua error. (`lua_unit.py` is the separate runner for the
pure-Lua module tests in `tests/test_*.lua`.)

### Writing a test

```python
from harness import QSys, FIXTURE_PLUGIN

def test_tap_pulses_tap():
    q = QSys(mode="XY Pad", props={"Pad Width": 500, "Pad Height": 500}, picker="Color_Picker")
    q.tap(250, 125)
    assert q.pulses("Tap") == 1
    assert abs(q.pin("Y")["Value"] - 0.75) < 1e-9        # Y is 0 at the bottom
    assert "<svg" in q.icon()
    q.budget()                                             # raises BudgetError above the limits
```

Rules the runner applies to every test:

- every `QSys` the test creates is checked after the test: a handler above
  120,000 VM instructions or a frame above 60,000 fails the test, and so does
  an uncaught Lua error. A test that provokes one on purpose sets
  `q.allow_budget = True` or `q.allow_errors = True` on that instance;
- instances are closed (sandbox folder removed) after the test;
- a test is a plain function; use `assert`. Helpers that need Lua directly use
  `q.run("return ...")` (multiple returns come back as a tuple).

### Constructor

```python
QSys(mode="XY Pad", props=None, picker="Color_Picker", emulate=False, plugin=None,
     picker_names=("saturation", "value"), source=None, runtime=True,
     echo_on_self_write=True, strict=True, strict_errors=True, touch_mode=None,
     missing_component="error", picker_type="color_picker")
```

- `plugin`: path of the `.qplug` (default `plugins/NikitaTouchPad.qplug`);
  `source` is Lua text instead. `FIXTURE_PLUGIN` is the fixture's path.
- `mode` sets the `Mode` property; `props` overrides other properties by name
  (unknown names raise `HarnessError`). `RectifyProperties` runs when present.
- `picker`: Code Name of the fake Color Picker registered before the runtime
  starts (`None` for no picker). Its controls are the two `picker_names` axes
  (0..100, `Position` 0..1) plus `hue` and `color_picker_surface`.
- `emulate`: `System.IsEmulating`; it also picks the default touch mode
  (`designer` when emulating, else `panel`) and the default finger geometry.
- `runtime=False` loads design time only (used by the lint).
- `echo_on_self_write`: the conservative assumption that a script write fires
  the control's own EventHandler. Default on; turn it off to see the other
  behaviour. External writes (`set_pin`, finger, `ComponentHandle.set`)
  always fire.
- `strict`: `budget()` raises on a breach. `strict_errors`: an uncaught Lua
  error raises `LuaHandlerError` from the call that triggered it; off, errors
  only accumulate in `q.errors`.
- `missing_component`: `Component.New` of an unknown Code Name raises
  (`"error"`, the default, so the engine's pcall is exercised) or returns an
  empty table (`"empty"`).

### Time

- `q.now` -- virtual seconds (float). `Timer.Now()` returns it. Nothing moves
  unless a helper advances it.
- `q.advance(seconds)` -- runs every timer, `Timer.CallAfter`, HTTP reply and
  TCP connect that falls due, in time order (ties in creation order),
  re-arming repeating timers from their due time; `q.now` ends at the target.
  `q.pending_events()` counts what is still scheduled.
- `os.time()` / `os.date()` follow the clock: `q.epoch` (default 2026-10-10
  12:00:00 local) + `q.now`. `os.clock` raises.

### Touch helpers

Coordinates (spec 13.1): points are **pad pixels, origin top-left, y down**.
The helper converts a point to picker Positions `u, v` with `px = x / W`,
`py = 1 - y / H` and the calibration `(x0, y0, w, h)`: `u = x0 + px * w`,
`v = y0 + py * h`. The default calibration follows `emulate`, as the engine
does: panel `(0, 0, 1, 1)`; Designer `(0, 0, 4/7, 1)` (the pad is the left
4/7 of the surface). `q.calibration = (x0, y0, w, h)` overrides it;
`q.to_picker(x, y)` shows the mapping. `W, H` come from `Pad Width` /
`Pad Height` (`q.pad_size`).

```python
q.touch(points, dt=0.05, mode=None, panel_touch=False, lift=True, hold=0.0, pause=None, silence=None)
q.tap(x, y, **kw)
q.double_tap(x, y, gap=0.15, **kw)
q.long_press(x, y, seconds=1.0, panel_touch=True, **kw)
q.swipe(x1, y1, x2, y2, seconds=0.2, steps=6, **kw)
q.drag(points, seconds=1.0, **kw)
q.lift(silence=None)
q.finger_down
```

- `mode="panel"`: both axes are written for every point (even unchanged), x
  then y, at the same instant; the EventHandler of each axis fires separately,
  so the first report of a touch still carries the other axis's old value
  (the LANDING case of spec 5.3). `mode="designer"`: an axis whose value did
  not change is **not written** (Designer never resends a value), and when
  both change the y axis follows 0.06 s after the x axis. A point whose both
  axes equal the picker's current values sends nothing: a second tap on the
  same spot before the park is invisible in designer mode, as in Designer.
- Each point is followed by `advance(dt)` (designer: the axis gap counts
  toward it). `pause=(i, seconds)` advances `seconds` before point `i`.
- `panel_touch=True` sets `Controls.PanelTouch` true before the first point
  and false at the lift.
- `hold` advances after the last point. `lift=True` (default) then calls
  `lift()`: with `panel_touch`, `PanelTouch = false` then `q.panel_settle`
  (0.35 s); without, silence of `ReleaseTime` + `q.release_extra` (0.4 s) so
  the engine infers the lift. Both leave time for the engine's 0.3 s park.
  `silence` overrides that time; `lift=False` leaves the finger down for a
  later `q.lift()`.
- `double_tap` lifts the first tap with `silence=gap`. Without PanelTouch the
  engine can only separate the taps when `gap` exceeds `ReleaseTime`.
- `long_press` without `panel_touch` cannot be told from a lift (a resting
  finger sends nothing); keep the default.

### Controls and pins

```python
q.pin(name, index=None)      # {"Value", "String", "Boolean", "Position", "Legend", "Style", "Color",
                             #  "Choices", "IsDisabled", "IsInvisible", "IsIndeterminate", "Index", "Key"}
q.set_pin(name, value, index=None, fire=None)   # bool -> Boolean, number -> Value, str -> String,
                             # {"Position": 0.5} -> that property; fires the handler on change (fire=True: always)
q.pulses(name, index=None)   # rising edges (Boolean false -> true) since start / q.reset_pulses()
q.trigger(name, index=None)  # ctl:Trigger() (handler without a value change)
q.control(name, index=None)  # the Lua control object itself (writes through it count as script writes)
q.has_control(name); q.control_names()
q.status()                   # Controls.Status.String (None without a Status control)
q.icon(name="Display")       # SVG decoded from the IconData of the Legend (or Style) JSON; None if never set
q.icons                      # distinct icon writes on Display; q.icon_writes(name) for others
q.camera_view()              # q.icon("CameraView")
```

`Controls` is built from the plugin's own `GetControls(props)`: `Count == 1`
gives a single control object, `Count > 1` a 1-based array (the Mic Mixer
`arr()` quirk). A control named `"Name n"` can be addressed as
`pin("Name 3")` or `pin("Name", 3)`; a single control rejects an index other
than 1 and an array demands one.

Control objects keep Value / String / Boolean / Position coherent per type:
Knob and Meter (Value clamped to Min..Max, `Position = (Value - Min) / (Max -
Min)`, Integer units round, String is a short readout such as `-20.0dB`,
`3`, `0.25`, Boolean = Position > 0.5); Button and Led (Boolean, Value and
Position 0/1, String `"true"`/`"false"`); Text and Indicator Text (String,
Value = the number in it or 0, Position 0, Boolean false); Status (Value 0..5
and an independent String). Legend, Style, Color, Choices, IsDisabled,
IsInvisible, IsIndeterminate, RampTime, CssClass and EventHandler are plain
fields; `ctl:Trigger()` calls the handler; any other property write raises
(reads give nil). Defaults follow `DefaultValue`, else Min / false / "".

### Components

```python
q.picker                      # PickerHandle: .name, .x_name, .y_name, .controls[name] (Lua objects),
                              # .set(u, v, force=False), .set_axis("x"|"y", value), .position, .get(name)
q.components                  # {name: ComponentHandle}
q.add_component(name, type, controls={"gain": {"Value": 0, "Min": -100, "Max": 20},
                                      "mute": {"Boolean": False}, "label": {"String": "x"}})
q.add_picker(name, picker_names=("saturation", "value"))
q.remove_component(name)
handle.get(name); handle.set(name, value, fire=None); handle.controls[name]
```

In Lua: `Component.New(name)` (raises for an unknown name unless
`missing_component="empty"`), `Component.GetComponents()` ->
`{ {Name, Type, Properties = {}} }`, `Component.GetControls(name)` -> array
of `{Name, Value, String, Position, Boolean, Type, Direction, MinValue,
MaxValue, Index}` snapshots (empty for an unknown name). `comp[ctlname]` is
the control object or nil. The picker's `color_picker_surface` String holds a
hex colour that changes silently with the finger; set `q.F.surface_reports
= True` to make it fire its EventHandler on every report too.

### Output, log, errors, budget

```python
q.output()      # captured print() lines (uncaught Lua errors are appended as "LUA ERROR in <label>: ...")
q.clear_output()
q.log           # [(kind, text)] from Log.Message / Log.Error
q.errors        # [(label, traceback)] of uncaught errors inside Lua callbacks
q.budget(strict=None)   # {"max_handler", "max_frame", "load", "handlers": {label: max}, "frames", "dispatches"}
                        # max_handler leaves the load dispatch out; "load" reports it (it draws the first frame but is not a frame)
q.instructions(label)
q.run(lua_code)         # execute Lua in the plugin's state
q.lua, q.G, q.F         # the lupa runtime, its globals, the fake's internal table (__FAKE)
```

Every entry into plugin code is one *dispatch* with a label: `load` (the
runtime section), `ctl:<key>` (a control EventHandler; component controls are
`<component>~<control>`), `trigger:<key>`, `timer`, `callafter`, `http`,
`udp`, `tcp:connected|data|eof|error|timeout|reconnect`. A count hook
(granularity 10) runs during the dispatch; the fake's own library code
(control writes, JSON, Base64, sockets, files, print, timers) pauses it, as
those are C on a Core. A handler fired by a script write runs nested: its
count is recorded under its own label and also included in the outer one. A
dispatch in which `Display`'s icon changed is a *frame*: it is also recorded
as `frame:<label>` and compared with the frame budget. The `load` dispatch is
the exception: it draws the first frame but is reported only as the load.

### Files

`q.files` is the sandbox root with `media/` and `design/` inside. Lua's `io`
is replaced by `io.open`, `io.lines` and `io.type` that accept only paths
starting with `media/` or `design/` (no `..`, no backslashes, no absolute
paths; `nil, "...Permission denied..."` otherwise); a missing parent folder
fails as on a Core. `dir.get(path)` -> array of `{name, type}` ("file" /
"directory") or nil, `dir.create(path)` -> true (nil when the parent is
missing), `dir.remove(path)`. Python side: `q.read_file(rel, text=True)`,
`q.write_file(rel, data)`, `q.file_exists(rel)`, `q.list_files()`.

### HTTP

`HttpClient.Upload{Url, Method = "POST"|"PUT"|"PATCH", Headers, Data,
Timeout, EventHandler}` (plus Download / Get / Post / Put / Patch / Delete,
`EncodeString`, `DecodeString`, `EncodeParams`, `CreateUrl`) records the
request in `q.http_posts` (`{"url", "method", "kind", "headers", "body",
"body_bytes", "timeout", "code", "at"}`) and answers on the next `advance`
after `q.http_latency` (0.01 s) with `q.http_reply = (code, data, err)`
(default `(200, "", None)`): `EventHandler(tbl, code, data, err, headers)`.

### Sockets

`UdpSocket.New()`, `:Open(ip, port)`, `:Send(ip, port, data)`, `:Close()`,
`:JoinMulticast(group, local)`, `.EventHandler(sock, packet{Address, Port,
Data})` or `.Data`. `q.udp_sent` is `[(ip, port, bytes)]`;
`q.inject_udp(data, address="127.0.0.1", port=0, index=None)` delivers to
every open socket (or the index-th created).

`TcpSocket.New()`, `.Events` / `.EOL` tables, `:Connect(ip, port)` (Connected
fires after `q.tcp_latency` on the next `advance`), `:Write` (raises when not
connected), `:Read(n)`, `:ReadLine(eol, custom)`, `:Search`, `:Disconnect()`,
`IsConnected`, `BufferLength`, `PeerAddress`, `ReadTimeout`, `WriteTimeout`,
`ReconnectTimeout`, `.EventHandler(sock, evt, err)` and the per-event
callbacks. `q.tcp_connects` is `[(ip, port)]`, `q.tcp_sent` `[(ip, port,
bytes)]`; `q.inject_tcp(data, index=None)` appends to the buffer of every
connected socket and fires Data; `q.tcp_event("Closed"|"Error"|"Timeout"|
"Reconnect"|"Connected"|"Data", err=None, index=None)` fires an event (Closed,
Error and Timeout mark the socket disconnected).

### Other fakes

`System.IsEmulating/BuildVersion/MajorVersion/MinorVersion/Version/
LockingId`; `Crypto.Base64Encode(s, pad)` / `Base64Decode(s)` (Digest and
HMAC raise); `require("rapidjson")` and `require("json")` return the same
module: `encode(v)` (object keys sorted, `#t > 0` or `__jsontype = "array"`
is an array, `{}` is an object, `null` sentinel), `decode(s)` -> value or
`nil, err`; any other `require` raises and `package` is nil; `print` is
captured; `Log.Message` / `Log.Error` go to `q.log`.

### Layout lint

`q.layout_lint(matrix=None, mode=None)` runs `GetPages`, `GetControls` and
`GetControlLayout` for every page and every override dict in `matrix`
(default `[{}]`, merged over the instance's props) and returns a list of
problem strings: a control from `GetControls` placed on no page, a layout key
that is not a control, an entry without Style or Position/Size, a box at a
negative position, with an empty size or leaving the page (the page size is
the largest graphic placed at (0, 0)), non-ASCII text in Legend / PrettyName
/ Text other than the brand en dash, a page without a full-page background.
Because `GetControlLayout` returns a dictionary, placing a control twice on
one page cannot be observed (the second entry replaces the first); the check
is not possible from outside.

### Testing against the engine (50_runtime.lua)

`tests/test_engine.py` and `tests/test_xy.py` drive the built plugin. Things
the engine does that a test must allow for:

- handlers are armed 0.1 s after load (spec 14.4): `q.advance(0.2)` before the
  first touch (the tests' `boot()` helper does this);
- once `PanelTouch` has changed, the engine treats it as wired for good: press
  and release then follow it and silence no longer infers a lift, so keep an
  instance to one style of touch (`panel_touch=True` everywhere, or nowhere);
- an inferred lift after a drag can be taken back by a report near the last
  spot within 1.5 s (`onTouchResume`); the picker is parked 0.3 s after the
  lift is certain (1.8 s after a drag's last report, 0.55 s after a tap's);
- frames are capped at `Max Frame Rate`: after an event that follows another
  within 1/fps, `q.advance(0.05)` before reading `q.icon()`;
- `TouchPad` is a Lua global with `E` (the engine API), `inst` (the mode
  instance; replace a method to probe or to raise), `state` and `mode`.

### Known approximations

- The String readout of a Knob and the exact shape of `dir.get` entries are
  approximations; Q-SYS formats are not documented in the research notes.
- `Component.New` on a Core may return an empty table instead of raising;
  the engine must survive both (`missing_component` switches the fake).
- Whether a Core fires a control's EventHandler for the script's own write is
  unknown; the fake does by default (`echo_on_self_write`).
- The count hook measures Lua VM instructions, not the Core's "execution
  count"; the budgets in spec section 0 are the engineering margin.
