<!-- Nikita Visual Arts – nikitavisual.art -->

# Q-SYS plugin runtime API

The Core (or Designer in emulation, F5) runs the `.qplug` file again when the
design starts, this time with the global `Controls` defined. Everything that
reacts to the operator or drives DSP lives inside `if Controls then ... end`
at the bottom of the file. The runtime block is restarted whenever the design
is pushed again, so it must set up its full state from scratch every time.

Contents:

1. Runtime skeleton
2. Controls
3. Properties
4. Embedded components
5. Timers
6. Status indicator
7. Debug output and error handling
8. Other Q-SYS Lua libraries

## 1. Runtime skeleton

```lua
if Controls then
  local chCount = Properties["Channel Count"].Value

  -- Count = 1 gives one control object, larger counts give an array.
  local function arr(c, n) return n == 1 and { c } or c end
  local Gain = arr(Controls.Gain, chCount)
  local Mute = arr(Controls.Mute, chCount)

  local function apply(i)
    main_mixer[string.format("input.%d.output.%d.gain", i, i)].Value = Mute[i].Boolean and -100 or Gain[i].Value
  end

  for i = 1, chCount do
    Gain[i].EventHandler = function() apply(i) end
    Mute[i].EventHandler = function() apply(i) end
    apply(i)                      -- push the current state once at start
  end
  Controls.Status.Value = 0
  Controls.Status.String = "OK"
end
```

Wire every handler, then call the handler once so the DSP matches the
controls after a restart. Without that initial call the audio path keeps
whatever the component defaults were until the user touches something.

## 2. Controls

`Controls` is a table keyed by the `Name` from `GetControls`. Each control
object has:

| Field | Access | Meaning |
|---|---|---|
| `Value` | read, write | Numeric value. Buttons give 0 or 1. |
| `String` | read, write | Text form of the value. For Text controls this is the text. |
| `Boolean` | read, write | `true` when the position is above 0.5. |
| `Position` | read, write | 0.0 to 1.0 across the control's range. |
| `Legend` | read, write | Caption on a button or fader. |
| `Choices` | read, write | Array of strings for a ComboBox or ListBox bound to a Text control. |
| `Color` | read, write | `{ r, g, b }` colour of the control. |
| `IsDisabled` | read, write | `true` greys the control out. |
| `IsInvisible` | read, write | `true` hides it. |
| `IsIndeterminate` | read, write | `true` marks the value as unknown. |
| `RampTime` | read, write | Seconds over which value changes ramp. |
| `Values` | read, write | Array of numbers for multi-value controls. |
| `Index` | read | Position of the control in its array. |
| `EventHandler` | write | Function called on every change. Receives the control as its argument. |
| `:Trigger()` | method | Fires a Trigger button from code. |

Write only one of `Value`, `String`, `Position` or `Boolean`; they are views
of the same state. Setting a control from code also fires its own
`EventHandler`, so guard against feedback loops when two handlers set each
other.

## 3. Properties

`Properties["Name"].Value` holds the property value at runtime. Properties
are fixed while the design runs, so read them once at the top of the runtime
block into locals.

## 4. Embedded components

Every entry from `GetComponents` is a global named after its `Name`. Its
controls are reached by their Q-SYS control name as a string key:

```lua
main_mixer["input.1.output.2.gain"].Value = -6
main_mixer["output.1.mute"].Boolean = true
local level = meter_1["meter.1"].Value
```

A component whose `Type` did not resolve is simply absent, so the global is
`nil` and the first index throws. Probe before use and report:

```lua
local reverb = _G["reverb_fx"]
local haveReverb = reverb ~= nil
```

Wrap reads of controls whose names you have not verified on a Core in
`pcall`, and show which engines loaded in a Text indicator so the user can
report back exactly what is missing on their Q-SYS version.

Control names known from this repository:

| Component Type | Control names |
|---|---|
| `mixer` | `input.<i>.output.<o>.gain`, `output.<o>.gain`, `output.<o>.mute` |
| `meter2` | `meter.1` |
| `compressor` | threshold, ratio and bypass controls exist; names were taken from the block's control list in Designer and not confirmed on hardware |
| `effect_reverb` | reverb time, pre-delay, mix and bypass controls exist; same caveat |

When a name is uncertain, open the matching block in Designer, enable a
Named Control on the control you need, and read the control name it shows.

## 5. Timers

```lua
local t = Timer.New()
t.EventHandler = function() ... end
t:Start(0.5)          -- seconds, repeats until t:Stop()

Timer.CallAfter(function() ... end, 2.0)   -- one shot
```

Use one timer for all meters (poll at about 15 Hz, `0.066` s) instead of a
timer per meter. Stop timers you no longer need; they keep running until
the design restarts.

## 6. Status indicator

A control declared with `IndicatorType = "Status"` shows the block state in
Designer and in Core Manager. Set both `Value` and `String`:

| Value | State |
|---|---|
| 0 | OK |
| 1 | Compromised |
| 2 | Fault |
| 3 | Not Present |
| 4 | Missing |
| 5 | Initializing |

Set 5 at the top of the runtime block and 0 (or 1 with a reason in `String`)
once everything is wired. A plugin whose engines did not load should report
1 with a message naming the missing engine, never 0.

## 7. Debug output and error handling

`print(...)` writes to the Designer debug window of the block (visible when
`PluginInfo.ShowDebug` is true or the user opens the script). Gate verbose
output behind a `Debug` property so production designs stay quiet. Print the
plugin name and version once at start, so a user's log always says which
build produced it.

A runtime error stops the whole script, so wrap anything that touches an
unverified control name in `pcall` and degrade gracefully (report in Status,
skip the feature) rather than letting one missing control silence the block.

## 8. Other Q-SYS Lua libraries

These exist in the plugin runtime and are documented under "Extensions to
Lua" in the Q-SYS Developer Help: `Timer`, `Component.New("Named")` for
components elsewhere in the design, `NamedControl`, `TcpSocket`, `UdpSocket`,
`SerialPorts`, `HttpClient`, `Ssh`, `Crypto`, `json` (`require("json")`),
`Network`, `System`, `Design`. Use them only when the block genuinely needs
to reach outside itself; a DSP plugin normally needs none of them.
