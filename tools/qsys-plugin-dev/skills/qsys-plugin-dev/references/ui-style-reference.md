<!-- Nikita Visual Arts – nikitavisual.art -->

# Q-SYS plugin UI style reference

Enumerated values accepted by the layout and graphics tables. Values are
case-sensitive strings unless marked otherwise.

## Colours

Every colour field takes `{ r, g, b }` or `{ r, g, b, a }` with components
from 0 to 255. Brand palette used by this user's plugins:

| Name | RGB | Hex | Use |
|---|---|---|---|
| Magenta | 197, 19, 232 | #C513E8 | primary accent, pans |
| Purple | 122, 27, 232 | #7A1BE8 | faders |
| Violet | 83, 18, 219 | #5312DB | secondary knobs (sends) |
| Orange | 255, 138, 30 | #FF8A1E | effects, warnings |
| Pink | 240, 50, 140 | #F0328C | solo, highlights |
| BG | 23, 21, 28 | #17151C | panel background |
| Panel | 32, 29, 38 | #201D26 | group boxes |
| Stroke | 53, 49, 62 | #35313E | outlines |
| Text | 244, 242, 247 | #F4F2F7 | primary text |
| Muted | 167, 159, 179 | #A79FB3 | captions |
| OK | 46, 204, 143 | #2ECC8F | status good |

## Fonts and font styles

`Font` must be one of these names and `FontStyle` one of the styles listed
for it. An unsupported pair falls back to the default font without warning.

| Font | FontStyle values |
|---|---|
| Roboto | Thin, Thin Italic, Light, Light Italic, Regular, Italic, Medium, Medium Italic, Bold, Bold Italic, Black, Black Italic |
| Roboto Mono | Thin, Thin Italic, Light, Light Italic, Regular, Italic, Medium, Medium Italic, Bold, Bold Italic |
| Roboto Slab | Thin, Light, Regular, Bold |
| Open Sans | Light, Light Italic, Regular, Italic, Semibold, Semibold Italic, Bold, Bold Italic, Extrabold, Extrabold Italic |
| Lato | Light, Light Italic, Regular, Italic, Bold, Bold Italic, Black, Black Italic |
| Montserrat | Thin, Thin Italic, ExtraLight, ExtraLight Italic, Light, Light Italic, Regular, Italic, Medium, Medium Italic, SemiBold, SemiBold Italic, Bold, Bold Italic, ExtraBold, ExtraBold Italic, Black, Black Italic |
| Noto Serif | Regular, Italic, Bold, BoldItalic |
| Poppins | Light, Regular, Medium, SemiBold, Bold |
| Droid Sans | Regular, Bold |
| Adamina | Regular |
| Slabo 27px | Regular |

`FontSize` is in points. Captions read well at 8 to 10, values at 10 to 12,
headers at 13 to 16. `IsBold = true` is a shorthand for a Bold style.

## Enumerations

| Field | Values |
|---|---|
| `ControlType` | Button, Knob, Text, Indicator |
| `ButtonType` (control) | Toggle, Momentary, Trigger, StateTrigger |
| `IndicatorType` | Led, Meter, Status, Text |
| `ControlUnit` | dB, Float, Hz, Integer, Pan, Percent, Position, Seconds |
| `PinStyle` | Input, Output, Both, None |
| `Style` (layout) | Fader, Knob, Button, Text, Meter, Led, ListBox, ComboBox, Media, None |
| `ButtonStyle` (layout) | Toggle, Momentary, Trigger, StateTrigger, On, Off, Custom |
| `ButtonVisualStyle` | Flat, Gloss |
| `MeterStyle` | Level, Reduction, Gain, Standard |
| `TextBoxStyle` | Normal, Meter, NoBackground |
| `HTextAlign` | Left, Center, Right |
| `VTextAlign` | Top, Center, Bottom |
| `IconType` | Icon, Image, SVG |
| `Type` (graphics) | Label, GroupBox, Header, Image, Svg |
| `Type` (property) | string, integer, double, boolean, enum |
| `Direction` (pin) | input, output |
| `Domain` (pin) | audio, serial |

## Sizes that work

| Control | Size |
|---|---|
| Fader, vertical | 32 x 140 or taller |
| Knob | 32 x 32 to 48 x 48 |
| Toggle button | 36 x 24 to 72 x 28 |
| LED | 16 x 16 |
| Meter, vertical strip | 10 x same height as the fader |
| Meter, horizontal | 150 to 240 x 20 |
| ComboBox | 120 to 200 x 22 |
| Text field | 72 to 160 x 20 |

Keep every coordinate on an 8 px grid and compute positions from counts
rather than typing numbers, so that a change of `Count` reflows the panel.
