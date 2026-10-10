<!-- Nikita Visual Arts – nikitavisual.art -->

# Q-SYS plugin design-time API

Designer loads the whole `.qplug` file, then calls the functions below while
the block is being placed and configured. Every function receives `props`,
a table keyed by property name where `props["Name"].Value` holds the current
value. Return plain Lua tables; Designer reads them and discards them.

Contents:

1. PluginInfo
2. GetColor and GetPrettyName
3. GetProperties and RectifyProperties
4. GetPages
5. GetControls
6. GetControlLayout (layout and graphics)
7. GetPins
8. GetComponents
9. GetWiring

## 1. PluginInfo

A global table, not a function.

| Field | Type | Notes |
|---|---|---|
| `Name` | string | Shown in the plugin list. `"Vendor~Block"` nests it in a Vendor folder. |
| `Version` | string | Semantic version shown to the user. Bump on each release. |
| `BuildVersion` | string | Four-part build number, e.g. `"1.0.0.0"`. |
| `Id` | string | A GUID. Unique per plugin and stable across versions. |
| `Author` | string | Use `"Nikita Visual Arts – nikitavisual.art"`. |
| `Description` | string | Shown in the plugin tooltip. |
| `ShowDebug` | boolean | `true` shows the script debug window in the block. |

## 2. GetColor and GetPrettyName

- `GetColor(props)` returns `{ r, g, b }` for the block background in the
  schematic.
- `GetPrettyName(props)` returns the title drawn on the block. It can reflect
  properties, e.g. `"Mixer 8x2"`.

## 3. GetProperties and RectifyProperties

`GetProperties()` returns an array of property tables.

| Field | Type | Notes |
|---|---|---|
| `Name` | string | Key used in `props[...]` and `Properties[...]`. |
| `Type` | string | `"string"`, `"integer"`, `"double"`, `"boolean"`, `"enum"`. |
| `Value` | varies | Default. For properties `Value` is the right key. |
| `Min`, `Max` | number | For `integer` and `double`. |
| `Choices` | array of strings | For `enum`. |
| `Header` | string | Groups the property under a heading (Designer 9.10+). |
| `Comment` | string | Help text under the property (Designer 9.10+). |
| `Description` | string | Tooltip text. |

`RectifyProperties(props)` runs after any property change and must return
`props`. Use it to hide a property that does not apply
(`props["Monitor Count"].IsHidden = (props["Mode"].Value == "Simple")`) or to
clamp one value against another. Do nothing else there.

## 4. GetPages

Optional. Return an array of `{ name = "Page" }` tables. With more than one
page Designer calls `GetControlLayout` once per page with
`props["page_index"].Value` set to the 1-based page number. Keep the page
names in a global array so both functions use the same list.

## 5. GetControls

Return an array of control tables. The conventional local name for the array
is `ctls`.

| Field | Type | Notes |
|---|---|---|
| `Name` | string | Identifier for `Controls[...]` and the layout key. No spaces is safest. |
| `ControlType` | string | `"Button"`, `"Knob"`, `"Text"`, `"Indicator"`. |
| `ButtonType` | string | Buttons: `"Toggle"`, `"Momentary"`, `"Trigger"`, `"StateTrigger"`. |
| `IndicatorType` | string | Indicators: `"Led"`, `"Meter"`, `"Status"`, `"Text"`. |
| `ControlUnit` | string | Knobs: `"dB"`, `"Float"`, `"Hz"`, `"Integer"`, `"Pan"`, `"Percent"`, `"Position"`, `"Seconds"`. |
| `Min`, `Max` | number | Knob range (also meters). |
| `DefaultValue` | number | Initial value. A `Value` key here is ignored. |
| `Count` | integer | Number of identical controls, default 1. 1 gives a single object at runtime, more gives an array. |
| `PinStyle` | string | `"Input"`, `"Output"`, `"Both"`, `"None"`: which control pins the block exposes. |
| `UserPin` | boolean | `true` lists the pin under Control Pins in the Properties pane instead of always showing it. |
| `Icon` | string | Designer icon name or base64 image for a button face. |
| `IconType` | string | `"Icon"` (default), `"Image"` (PNG or JPG), `"SVG"`. |

Typical declarations:

```lua
table.insert(ctls, { Name = "Gain", ControlType = "Knob", ControlUnit = "dB", Min = -100, Max = 20,
  DefaultValue = 0, Count = chCount, PinStyle = "Both", UserPin = true })
table.insert(ctls, { Name = "Mute", ControlType = "Button", ButtonType = "Toggle", Count = chCount,
  PinStyle = "Both", UserPin = true })
table.insert(ctls, { Name = "Level", ControlType = "Indicator", IndicatorType = "Meter", Count = chCount,
  PinStyle = "Output" })
table.insert(ctls, { Name = "Status", ControlType = "Indicator", IndicatorType = "Status", PinStyle = "Output", Count = 1 })
table.insert(ctls, { Name = "Mode", ControlType = "Text", Count = 1 })   -- drives a ComboBox in the layout
```

Buttons default to off, Text controls to an empty string. A Text control is
what a ComboBox or ListBox layout binds to; set its `Choices` at runtime.

## 6. GetControlLayout

Return two tables: `layout` (keyed by control name) and `graphics` (an
array). The key for a control with `Count = 1` is its `Name`; otherwise it
is `"Name 1"`, `"Name 2"`, and so on. A control with no layout entry exists
but is not drawn.

### Layout entry fields

| Field | Applies to | Values |
|---|---|---|
| `Style` | all | `"Fader"`, `"Knob"`, `"Button"`, `"Text"`, `"Meter"`, `"Led"`, `"ListBox"`, `"ComboBox"`, `"Media"`, `"None"` |
| `PrettyName` | all | Display name in the UI and on pins. `"Group~Name"` nests pins in a folder. |
| `Position` | all | `{ x, y }` pixels from the top left. |
| `Size` | all | `{ width, height }` pixels. |
| `ButtonStyle` | Button | `"Toggle"`, `"Momentary"`, `"Trigger"`, `"StateTrigger"`, `"On"`, `"Off"`, `"Custom"` |
| `ButtonVisualStyle` | Button | `"Flat"`, `"Gloss"` |
| `CustomButtonUp`, `CustomButtonDown` | Button `"Custom"` | Legend text per state. |
| `Legend` | Button, Fader | Text label on the control. |
| `MeterStyle` | Meter | `"Level"`, `"Reduction"`, `"Gain"`, `"Standard"` |
| `TextBoxStyle` | Text, Fader box | `"Normal"`, `"Meter"`, `"NoBackground"` |
| `ShowTextbox` | Fader, Knob, Meter | `true` draws the value box. |
| `IsReadOnly` | all | `true` blocks user edits (status displays). |
| `Color` | all | `{ r, g, b }` or `{ r, g, b, a }`, 0 to 255. Button on-colour, fader and knob accent. |
| `OffColor` | Button, Led | Off-state colour, used when `UnlinkOffColor = true`. |
| `UnlinkOffColor` | Button, Led | `true` lets on and off colours differ. |
| `TextColor` | all | Text colour. |
| `BackgroundColor` | Meter, Text | Background colour. |
| `StrokeColor`, `StrokeWidth` | all | Outline colour and width in pixels. |
| `CornerRadius` (alias `Radius`) | all | Corner rounding in pixels. |
| `Margin`, `Padding` | all | Pixels outside and inside the control frame. |
| `Font`, `FontSize`, `FontStyle` | text-bearing | See the style reference. `IsBold = true` is a shorthand for a Bold style. |
| `HTextAlign`, `VTextAlign` | text-bearing | `"Left"`, `"Center"`, `"Right"` and `"Top"`, `"Center"`, `"Bottom"`. |
| `WordWrap` | text-bearing | `true` wraps long legends. |
| `IconColor` | Button | Colour of a button icon. |
| `ZOrder` | all | Signed integer. Higher draws in front, shared with graphics on the same page. |

### Graphics entry fields

Graphics are `table.insert(graphics, { ... })` entries drawn behind or around
controls.

| Field | Notes |
|---|---|
| `Type` | `"Label"`, `"GroupBox"`, `"Header"`, `"Image"`, `"Svg"` |
| `Text` | For Label, GroupBox and Header. |
| `Image` | Base64 of a PNG or JPG (Image) or of an SVG file (Svg). |
| `Position`, `Size` | As for controls. |
| `Fill` | Background colour of a GroupBox. |
| `StrokeColor`, `StrokeWidth`, `CornerRadius` | GroupBox frame. |
| `Color` | Text colour for Label, GroupBox and Header. |
| `Font`, `FontSize`, `FontStyle`, `HTextAlign`, `VTextAlign` | Text styling. |
| `ZOrder` | Drawing order. |

Build the panel from helpers (a `panel(x, y, w, h)` that inserts a GroupBox,
a `caption(text, x, y, w)` that inserts a Label) so a change of style touches
one place. Insert full-panel backgrounds first; later entries draw on top.

## 7. GetPins

Return an array of pin tables for the signal pins on the block edge. Control
pins come from `PinStyle` on controls and do not belong here.

| Field | Values |
|---|---|
| `Name` | Label on the pin; also the endpoint name in `GetWiring`. |
| `Direction` | `"input"` or `"output"`. |
| `Domain` | `"audio"` (default) or `"serial"`. |

Pin order in the array is the order on the block, so list inputs channel by
channel and outputs after them.

## 8. GetComponents

Return an array of embedded components. Each becomes a global at runtime,
named after `Name`, with its controls reachable as `name["control.name"]`.

| Field | Notes |
|---|---|
| `Name` | Global variable name: letters, digits and underscores only. |
| `Type` | The component type string, e.g. `"mixer"`, `"gain"`, `"compressor"`, `"crossover"`, `"meter2"`, `"effect_reverb"`, `"signal_presence"`, `"scriptable_controls"`. |
| `Properties` | Table of the component's own properties, e.g. `{ ["n_inputs"] = 8, ["n_outputs"] = 2 }` for a mixer. |

Type strings and control names are the least documented part of the
framework, and the trust levels differ:

- Used by this repository's plugins and checked offline, but not confirmed
  on a Core: `mixer` with `n_inputs` and `n_outputs` (crosspoint gains
  `input.<i>.output.<o>.gain`, output gains `output.<o>.gain`, output mutes
  `output.<o>.mute`), `meter2` (control `meter.1`), `compressor`,
  `crossover` (2-way by default, band outputs named High and Low),
  `effect_reverb`.
- Named in the Q-SYS documentation but with no control names recorded here:
  `gain`, `signal_presence`, `scriptable_controls`.

Prefer a `mixer` for gain and mute duties (write -100 dB to a crosspoint to
mute it) because its control names are the ones recorded here. A wrong
`Type` is dropped without an error, so always probe at runtime and surface
the result (see the runtime reference). When unsure of a component's control
names, open the equivalent block in Designer, add a Named Control or hover
the control, and read the name shown there.

## 9. GetWiring

Return an array of wires. Each wire is an array of endpoint strings that are
connected together: plugin pin names from `GetPins` and component pins in the
form `"<component Name> Input <n>"` or `"<component Name> Output <n>"`.

```lua
table.insert(wiring, { "In 1", "main_mixer Input 1" })
table.insert(wiring, { "main_mixer Output 1", "Out L", "meter_l Input 1" })
```

Rules that follow from how Designer resolves wires:

- An endpoint that does not exist on the named component is ignored, so a
  wire with one real source and several candidate destinations is a safe way
  to cover a pin whose name differs between Q-SYS versions. Never put two
  possible sources on one wire, since both might resolve and sum.
- Every component input that should carry signal needs a wire, otherwise the
  component sees silence.
- Keep counts in sync: the number of mixer inputs you wire must not exceed
  the `n_inputs` you declared.
