<!-- Nikita Visual Arts – nikitavisual.art -->
<p align="center">
  <img src="../../assets/brand/logo-horizontal.png" alt="Nikita Visual Arts" width="280"><br>
  <strong>Nikita Visual Arts – nikitavisual.art</strong>
</p>

# Touch Pad for Q-SYS: user guide

Version 1.0.1. The plugin is `plugins/NikitaTouchPad.qplug`. The pin reference built from
it is [PINS.md](PINS.md); the build and test tools are described in
`tools/touchpad/README.md`.

Contents: [What it is](#what-it-is), [How it works](#how-it-works),
[Set it up in your own design](#set-it-up-in-your-own-design), [Properties](#properties),
[Common pins and controls](#common-pins-and-controls), [Calibration](#calibration),
[Touch Activity](#touch-activity), [Touch panels](#touch-panels),
[Making it look right on a panel](#making-it-look-right-on-a-panel),
[Designer notes](#designer-notes), [Themes](#themes),
[Status messages and troubleshooting](#status-messages-and-troubleshooting),
[Per mode](#per-mode), [Recipes](#recipes),
[What has been tested, honestly](#what-has-been-tested-honestly), [Credits](#credits),
[Changelog](#changelog).

## What it is

Touch Pad gives a Q-SYS UCI real touch gestures with no extra hardware. A native Color
Picker component sits under the page and reports where a finger is while it is touched. The
plugin reads it, works out the gesture (tap, double tap, long press, drag, swipe) and draws
its own interface on top of the page as a vector drawing set from the script. Every result
is a pin: live X and Y, a pulse for each gesture, and the outputs of the mode you pick. One
block is one pad. Sixteen modes share the same block, the same setup and the same common
pins, so a joystick, a zone map and a signature pad are all set up the same way.

| Mode | One line |
|---|---|
| XY Pad | The live X and Y of one finger with the common gestures; draws a card with a dotted grid, crosshair lines and a dot at the finger. |
| Swipe Layer | An almost invisible layer that reports swipes in four directions; draws only a fading finger trail and a brief chevron. |
| Joystick | A stick that springs back or stays put, with JoyX, JoyY, magnitude and direction LEDs; drives a camera when one is set. |
| PTZ Pad | Drag to aim a camera: absolute pan and tilt, plus pan and tilt speeds while dragging; double tap goes home. |
| Camera Framing | Draw a box around the next shot: the box's pan, tilt and zoom go to the camera; boxes add up, double tap zooms out. |
| Dial | An endless jog wheel with detents: a 0..1 value, a step pulse per detent, a control it can drive directly, or a camera's zoom. |
| Knob | A bounded rotary (270 degrees) with min, max and units: a value in display units and a 0..1 position. |
| Fader | A linear touch fader, vertical or horizontal, with jump or relative grab, a linear or audio taper and a center snap. |
| Panner | A 2D panner over a speaker layout from stereo to 7.1: a gain in dB per speaker and a stereo pan value. |
| Zone Select | Tap, paint, lasso and solo zones on a grid or a floor plan; the layout is editable; the selection is a comma-separated list. |
| Drag & Drop | Drag a source tile onto a screen tile to route it; pages when there are many; whole words in names pick the icons. |
| Matrix | A crosspoint grid of sources by destinations: tap or paint crosspoints, exclusive columns, pages beyond 12 x 12. |
| Pattern Lock | Draw a pattern over a 3 x 3 (up to 5 x 5) dot grid: unlocked and failed pulses, a lockout after too many tries, learn mode. |
| Keypad | A numeric keypad drawn by the pad for PIN entry: accepted and rejected pulses, masked entry, lockout, auto submit. |
| Sign-In | A visitor signature pad with name, company and host fields; saves an SVG and a CSV log; optional webhook. |
| Whiteboard | Freehand drawing with pen colors, undo, an eraser and a snapshot to an SVG file. |

## How it works

**The hidden Color Picker.** Q-SYS has no control that reports where a finger is, but the
native Color Picker does: while a finger is on its color surface, its saturation control
(left to right) and its value control (bottom to top) follow the finger, each as a position
from 0 to 1. The plugin opens the picker by its Code Name with `Component.New`, finds those
two controls by name, and listens to their events. Each report is turned into pad pixels
through the geometry for the screen type and the calibration (see
[Calibration](#calibration)). A touch that lands on the picker outside the pad is ignored,
and stays ignored when it slides onto the pad.

**A drawing on a disabled button.** The pad's drawing is the block's `Display` control, a
plain button. The plugin builds an SVG of the pad, base64-encodes it and writes it into the
button's Legend as `{"DrawChrome":false,"IconData":"..."}`, the pattern QSC's own
script-set icon examples use. The button is disabled (`IsDisabled = true`, re-asserted after
every write), so the panel draws it but lets touches pass through to the picker beneath.
Frames are capped at **Max Frame Rate** (20 per second by default), a frame identical to
the last one is not sent, and the drawing is limited to 60,000 characters. The **Icon
Channel** property moves the write to the button's Style property instead, for a firmware
that only renders that variant.

**Three stacked copies at 35 %.** A panel draws a disabled control at about 35 % strength.
One copy of the Display looks faint. Each extra copy covers 35 % of what is still showing
through, so two stacked copies come out at about 58 %, three at about 73 % and four at
about 82 %. Three is the recommended number: paste the Display three times, exactly over
the pad, with a box in the pad's own color under them so that what shows through is the
same color and the pad looks solid. See
[Making it look right on a panel](#making-it-look-right-on-a-panel).

**Why Swipe Disabled.** On a TSC and in the UCI Viewer apps, a sideways drag on a UCI page
flips to the next page. The picker never sees that drag. Turn on the UCI's **Swipe
Disabled** property so every drag on the pad reaches the picker.

**Touch Activity.** The picker reports positions, not press and release. A finger resting
still sends nothing, so on its own the plugin infers a lift after **Release Time** (0.25 s)
of silence. The TSC's Status/Control block has a **Touch Activity** output that is true
while the screen is being touched. Wired into the block's **Panel Touch** pin, press and
release become exact, long press works, and a drag that pauses is not mistaken for a lift.
See [Touch Activity](#touch-activity) for what works without it.

**Parking.** 0.3 s after a lift is certain, the plugin writes position 0 to both picker
axes, so the next touch anywhere is a change of value and is reported. It never writes to
the picker while a finger may be down, and it ignores the echo of its own write.

## Set it up in your own design

The short version:

1. Block: pick the Mode and the pad's size.
2. Color Picker: Script Access All; type its Code Name into the block's Color Picker property.
3. Read the block's Setup page: the picker's size, and where the pad can go.
4. UCI: the picker's color surface at that size and place, sent to the back.
5. A Group Box over the picker, page color, 2 px bigger.
6. Where the pad goes: a box in the pad's color, then the Display from the block's Display page pasted three times on top.
7. UCI: Swipe Disabled on.
8. Test. On a TSC: tick and wire Touch Activity to the block's Panel Touch.

Each step in full:

1. **Block.** Drag **Plugins > User > Custom > Nikita Visual Arts > Touch Pad** into the
   schematic. Pick the **Mode** and set **Pad Width** and **Pad Height** (500 x 500 is the
   default; 16:9 such as 640 x 360 suits Camera Framing). The block is named
   `Touch Pad: <Mode> <W>x<H>`. On a 1280-wide UCI keep the pad's longer side at about 640
   or less: the picker behind the pad is 1.91 times as wide as that side (step 4). Square
   pads are the safe choice in 1.0.0: for a pad that is not square, the picker's touch square
   still has the longer side, and the built-in geometry maps that whole square onto the pad,
   so run [Calibration](#calibration) once on each screen type you use, or keep the pad
   square.
2. **Picker.** Add a **Color Picker** (Control Components), set its **Script Access** to
   **All** (or Script) and type its **Code Name** (not its label) into the block's **Color
   Picker** property. With exactly one Color Picker in the design the property may stay
   blank: the plugin finds it and names it on Status. Each pad needs its own picker. At run
   time the **Picker** text on the block's Setup page overrides the property, and
   **Refresh** rebinds.
3. **Read the Setup page.** The **SIZE FOR THIS PAD** text gives the picker's size, how far
   the pad's top-left sits inside it, the cover's size, and where the pad's top-left can go
   on a 1280 x 800 page. The **LIVE PLACEMENT** readout repeats it at run time. Decide where
   the pad goes before you draw anything.
4. **Picker on the UCI.** Drag the picker's color surface onto the page and set its size
   and position so that the pad's top-left is the printed offset to the right of and below
   the picker's top-left. **Send the picker to the back** (lowest in the layer list).
   Everything else on the page sits on top of it: buttons and fields elsewhere keep their
   own touches, and a touch that lands on the picker outside the pad is ignored, even if it
   then slides onto the pad.
5. **Cover it.** A **Group Box** over the whole picker and 2 px bigger on every side (or the
   picker's edge shows as a thin line): Fill = page color, Stroke Width 0, Corner Radius 0,
   just above the picker in the layer list, under everything else. Touches pass through
   graphics.
6. **Drawing.** Put a box in the pad's color exactly where the pad goes (the block's
   **Display** page prints it, for example `Pad colour: 23,21,28` for the Nikita theme, with
   the same corner radius as the pad). Then open the block's **Display** page, copy the
   **Display** there (it is already the pad's size) and paste it onto the UCI **three
   times**, stacked exactly over the box. With Background = Transparent, leave the box out:
   the page art shows through the pad. Tip: group the picker, the cover, the box and the
   three copies so the pad moves in one go.
7. **Swipe off.** Select the UCI itself and turn on **Swipe Disabled** in its properties.
8. **Test.** Save, press F6 (Emulate), open the UCI and drag on the pad. **Status** on the
   block should read `OK - Ready. Picker OK: ...`. On a TSC, also wire the panel's **Touch
   Activity** to the block's **Panel Touch**: tick **Touch Activity** under Control Pins on
   the TSC's Status/Control block, tick **Panel Touch** (in the Setup folder) under Control
   Pins on the Touch Pad, then wire them. Read [Touch Activity](#touch-activity) first:
   one panel per pad.

Not working? Open the block's Setup page and read **Status**; every text it can show is
listed under [Status messages and troubleshooting](#status-messages-and-troubleshooting).
If Status says OK but nothing moves, something other than graphics is on top of the picker,
the UCI has a different picker than the block, or Swipe Disabled is off.

### The picker geometry rule

With P the pad's longer side, in UCI pixels:

- picker width = ceil(1.91 x P)
- picker height = P + 24
- pad top-left = picker top-left + (round(0.04 x picker width), 12)
- cover = the picker rectangle grown by 2 px on each side (width + 4, height + 4, placed 2 px
  up and 2 px left of the picker)

Why so big: a TSC-G3 and a browser draw the picker's touch area as a square whose side is
the smaller of 4/7 of 92 % of the picker's width and the picker's height minus 24, inset
4 % of the width from the picker's left edge and 12 px from its top. This width and height
make that square exactly P on a side and put it on the pad. Designer draws the surface as a
wider rectangle instead; the plugin knows both shapes (see [Designer notes](#designer-notes)),
so neither should need calibrating. These numbers were measured on the Gesture Pad project's
published single-pad design (a 560 x 560 pad over a 1070 x 584 picker, the pad 43 px right
and 12 px down, a 1074 x 588 cover).

### A worked example: a 500 x 500 pad

- Picker: **955 x 524 px** (ceil(1.91 x 500) = 955; 500 + 24 = 524).
- Pad: its top-left is **38 px right and 12 px down** from the picker's top-left
  (round(0.04 x 955) = 38). Put differently, the picker starts 38 px left of and 12 px above
  the pad.
- Cover: **959 x 528 px**, its top-left 2 px up and 2 px left of the picker's.
- Display: three copies, each 500 x 500, stacked exactly on the pad, with a 500 x 500 box in
  the pad's color under them (`Pad colour: 23,21,28` for the Nikita theme).

The block's Setup page prints exactly this for the configured pad:

```
Picker on the UCI: 955 x 524 px. Pad top-left = picker top-left + (38, 12).
Cover box: 959 x 528 px, 2 px outside the picker. Pad top-left fits at x 39..363, y 12..288 on a 1280 x 800 page.
```

### Where the pad can go on a 1280 x 800 page

The picker reaches 38 px to the left of a 500 px pad, 12 px above and below it, and
417 px to the right of it (955 - 38 - 500), so the pad cannot go just anywhere. The pad's
top-left must leave room for the picker on every side: on a 1280 x 800 page a 500 x 500 pad
fits with its top-left at **x 39..363 and y 12..288**, the left part of the page. A 640 x 640
pad fits at x 50..106, y 12..148. The Setup page prints the range for your size, or
`Wider than a 1280 x 800 page: use a smaller pad or a larger page.` Leave room for a tab bar
on the right or at the bottom. A 1920 x 1200 page (a TSC-101-G3) has far more room; a
1280 x 720 page (a TSC-50-G3) has 80 px less height than the printed range assumes.

### One panel per pad

Touch Activity is screen-wide: it is true whenever that panel is touched, anywhere on the
screen. A pad whose Panel Touch is wired therefore listens to that one panel. Two pads on
different pages of the same UCI can both be wired to the same panel (a touch on another
page's pad reaches a different picker and is ignored by this one). A UCI shown on more than
one panel cannot: OR their Touch Activity pins together through a Logic block into Panel
Touch, or leave Panel Touch unwired. A browser or the UCI Viewer app has no Touch Activity:
it works with lifts inferred from silence, but only on a pad whose Panel Touch is not wired.

## Properties

Properties are read when the script starts: change one in Designer and push the design
again (or restart Emulate). Properties that do not apply to the chosen mode or theme are
hidden.

### General

| Property | Values | Default | Meaning |
|---|---|---|---|
| Mode | the sixteen modes | XY Pad | Which mode the block is. Changing it changes the block's controls, pages and pins. |
| Pad Width | 120..1600 | 500 | The pad's width in UCI pixels; the Display is drawn at this size. |
| Pad Height | 120..1200 | 500 | The pad's height in UCI pixels. |
| Color Picker | text | blank | The Code Name of the Color Picker on the UCI. Blank binds the only Color Picker in the design. The Setup page's Picker text overrides it at run time. |
| Swap Axes | yes / no | no | Swaps the picker's two axes before anything else, for a picker whose surface turns out to be oriented differently than assumed. |
| Flip X | yes / no | no | Mirrors the picker's horizontal axis before calibration. |
| Flip Y | yes / no | no | Mirrors the picker's vertical axis before calibration. |
| Show Hints | yes / no | yes | Draws the mode's hint line on the pad (for example `Drag anywhere`) while nothing is touching it. |
| Max Frame Rate | 10, 15, 20, 30 | 20 | The most frames per second the plugin sends to the Display. |
| Icon Channel | Legend, Style | Legend | Which property of the Display button carries the drawing. Keep Legend unless a firmware only renders the Style variant. |

### Theme and look

| Property | Values | Default | Meaning |
|---|---|---|---|
| Theme | Nikita, Sunset, Ocean, Light, Custom | Nikita | The pad's colors (see [Themes](#themes)). |
| Accent Color | `#RRGGBB` | blank | Custom theme only: highlights. Blank or invalid keeps the Nikita accent. |
| Background Color | `#RRGGBB` | blank | Custom theme only: the pad's background; cards, tracks and hairlines are derived from it, and so is the color the Display page prints. |
| Text Color | `#RRGGBB` | blank | Custom theme only: text; muted text is mixed from it and the background. |
| Background | Solid, Transparent, Panel | Solid | Solid fills the pad with the theme's background color. Transparent draws no pad background or frame, so the page art shows through. Panel fills it with the theme's lighter panel color at 80 % opacity, so the page art shows through slightly. |
| Corner Radius | 0..40 | 18 | The radius of the pad's frame. |
| Font | font family name | Roboto | The font for text in the drawing, followed by Roboto and sans-serif as fallbacks. Use a font the panel or the UCI style has (for example `Heebo Bold`). Text widths are estimated from Roboto metrics. |

### Camera

Shown for Joystick, PTZ Pad, Camera Framing and Dial only.

| Property | Values | Default | Meaning |
|---|---|---|---|
| Camera Control | None, Demo (simulated), Q-SYS Camera, VISCA over IP | None | None: no camera controls. Demo: a simulated camera with its own Camera View page and display. Q-SYS Camera: a camera component in the design. VISCA over IP: a network camera, with the IP typed on the Setup page. |
| Camera Name | text | blank | Q-SYS Camera only: the camera component's Code Name. Its Script Access must be Script or All. |
| VISCA Brand | PTZOptics, Sony, AVer, Lumens, Marshall, BirdDog, Avonic, Generic Sony header, Generic raw TCP | PTZOptics | VISCA over IP only: the transport, header and position scales for the brand. |

### Mode counts

| Property | Values | Default | Used by | Meaning |
|---|---|---|---|---|
| Zones | 1..32 | 8 | Zone Select | How many zones, and how many `ZoneName n` / `ZoneSelected n` controls. |
| Sources | 1..64 | 4 | Drag & Drop, Matrix | How many sources (rows in Matrix). |
| Destinations | 1..64 | 2 | Drag & Drop, Matrix | How many destinations (columns in Matrix). Above 16 of either, the Names page splits into Sources and Destinations pages. |
| Speakers | Stereo, LCR, Quad, 5.1, 7.1 | Stereo | Panner | The speaker layout and the number of `SpeakerGain n` outputs. |
| Orientation | Vertical, Horizontal | Vertical | Fader | Which way the fader runs. |
| Sign-In Webhook | Off, JSON, Teams Card | Off | Sign-In | What each sign-in posts to the Webhook URL. |

### Debug

| Property | Values | Default | Meaning |
|---|---|---|---|
| Debug Print | None, Gestures, All | None | Gestures prints every touch start and end, every gesture, calibration results and lock changes with pad coordinates and timing. All also prints every picker report, every park and the picker's full control list once at bind. The lines land in the block's Debug Output. |

There is no separate Show Debug property on this plugin: Designer provides its own on every
block, and that is what opens the Debug Output window.

## Common pins and controls

Every mode has these. Pins are named `Group ~ Name` under the block's Control Pins list;
`none` means the control lives on the block's pages only (and in Lua). The Lua name is the
control's name for `Component.New` (see [PINS.md](PINS.md) for the full list per mode).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's state: `OK - Ready...` or the problem (see [Status messages](#status-messages-and-troubleshooting)). Also the LED in every page header. |
| none | `Display` | Button | | The pad's drawing: copy it from the Display page onto the UCI three times. It is disabled at run time so touches pass through it. |
| none | `SetupVersion` | Text | | On the About page. Blank until the first start, when the plugin writes the documented defaults of its toggles (Source Active, Allow Calls, Exclusive Columns, Masked, Auto Submit, Show Background) once and records `1` here; after that your own settings of those toggles are kept. |
| Setup ~ Picker | `Picker` | Text | in | The picker's Code Name at run time; blank uses the Color Picker property. Changing it rebinds. |
| Setup ~ Refresh | `Refresh` | Trigger | in | Rescans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Toggle | in | Wire the TSC's Status/Control > Touch Activity here for exact press and release and for long press. Leave it off when nothing is wired to it. |
| Setup ~ Calibrate | `Calibrate` | Toggle | in | On: the pad shows two targets; tap them in turn (see [Calibration](#calibration)). Off cancels. |
| none | `Calibration` | Text | | The calibration lines, `P x0 y0 w h` for panels and browsers and `D x0 y0 w h` for Designer. Editable; clear it to go back to the built-in geometry. |
| none | `PickerLayout` | Indicator Text | | The computed picker size and placement for the current pad size (the same text as SIZE FOR THIS PAD). |
| Setup ~ Release Time | `ReleaseTime` | Knob, seconds 0.1..1 | in | Default 0.25. Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob, seconds 0.3..3 | in | Default 0.6. How long a still finger must rest for a long press (needs Panel Touch). |
| Setup ~ Lock | `Lock` | Toggle | in | On: touches are ignored, nothing pulses, the pad draws dimmed with a lock icon and Gesture shows `LOCKED`. The mode is told, so a joystick returns to center and a picked source is put down. |
| Live ~ Touching | `Touching` | LED | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob, 0..1 | out | The finger's position from left (0) to right (1), live while touching and held after a lift. |
| Live ~ Y | `Y` | Knob, 0..1 | out | The finger's position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Trigger | both | Pulses on a tap: down and up within 0.35 s, less than 12 px of movement. The first tap of a double tap pulses it too. |
| Actions ~ Double Tap | `DoubleTap` | Trigger | both | Pulses on a second tap within 0.4 s and 40 px of the first. |
| Actions ~ Long Press | `LongPress` | Trigger | both | Pulses when a finger rests still for Long Press Time. Needs Panel Touch. |
| Actions ~ Press | `Press` | Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Trigger | out | Pulses on a confirmed lift (or, without Panel Touch, an inferred one). |
| Actions ~ Swipe Left / Right / Up / Down | `SwipeLeft`, `SwipeRight`, `SwipeUp`, `SwipeDown` | Trigger | both | Pulses on a swipe: at least 20 % of the pad's diagonal within 0.6 s, with one axis at least 1.5 times the other. Every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the mode's hint, in upper case: `TAP`, `DOUBLE TAP`, `LONG PRESS`, `DRAG`, `SWIPE LEFT`, `LOCKED`, or a mode's own text. |
| Live ~ Drag Distance | `DragDistance` | Knob, 0..2 | out | The current or last drag's length as a fraction of the pad's diagonal. |
| Live ~ Drag Angle | `DragAngle` | Knob, -180..180 | out | The current or last drag's direction in degrees: 0 is right, 90 is up. |

The gesture pins marked `both` can also be pulsed from outside by a script or another
block; the mode is told about such a pulse, and what it does with it is up to the mode.

A drag starts once the finger has moved 12 px from where it landed; Gesture then shows
`DRAG` and Drag Distance and Drag Angle follow the finger.

Camera modes with Camera Control set add the Camera group: `ZoomIn` and `ZoomOut`
(momentary, in), `MaxSpeed` and `ZoomSpeed` (1..100 %, default 50, in), `CameraStatus`
(text, out), `CameraIP` (text, in; VISCA over IP only) and the `CameraView` display (Demo
camera only; copy it onto the UCI like the pad's Display, three times, 480 x 270 px).

## Calibration

Only needed if the drawing does not line up with your finger (a different picker layout,
another viewer, a pad that is not square). It is a setup tool: keep **Calibrate** off the
pages end users see.

1. On the Setup page turn **Calibrate** on. The pad shows two targets, 12 % in from the
   top-left and bottom-right corners, and the title `Calibration: Tap the top-left target`.
2. Tap the top-left target, then the bottom-right one. Only taps count, and only taps near a
   target (within about a third of the pad): a tap elsewhere shows `Calibration: tap closer to
   target 1` (or 2) on Status and waits.
3. The result is written into the **Calibration** text as `P x0 y0 w h` on a panel or in a
   browser, or `D x0 y0 w h` in Designer, and Status shows `Calibrated: ...`. Both lines can
   exist at once: the P line applies on panels and browsers, the D line while emulating, so
   calibrating one does not upset the other.

Calibrate gives up after 60 s without a tap (`Calibration cancelled: no taps for 60 s`), and
turning the toggle off cancels it. Two taps on nearly the same spot fail with
`Calibration failed: the two taps are too close`.

The numbers are the picker's raw range that the pad covers: `x0 y0` is the raw position of
the pad's bottom-left corner and `w h` the raw width and height, all in 0..1. The built-in
values are `P 0 0 1 1` (the touch square equals the pad) and `D 0 0 0.5714 1` (the pad is the
left 4/7 of Designer's wider rectangle). A calibration made at run time is lost on the next
deploy unless you type the line into the Calibration field in Designer. Clear the field to go
back to the built-in geometry. Swap Axes, Flip X and Flip Y apply before calibration.

## Touch Activity

Without Panel Touch wired, the plugin infers a lift after **Release Time** (0.25 s) of
silence from the picker. That works for taps, double taps, drags and swipes, with these
limits:

- **Long press needs it.** A finger resting still sends nothing, so without Touch Activity
  the plugin cannot tell a held finger from a lifted one. Long Press never pulses.
- **A drag that pauses** longer than Release Time looks like a lift for a moment: Touching
  goes off and Release pulses. If the drag carries on within 1.5 s near the same spot, the
  drag resumes (Touching comes back on without a new Press, and the mode takes back a drop
  or keeps a lasso open). A lasso or a framing box is therefore applied about 1.75 s after the
  finger stops, in case the drag carries on.
- **A double tap** needs a gap longer than Release Time and shorter than 0.4 s between the
  taps, within 40 px. Two quick taps on different places are two taps.
- The finger peeling off can send a few pixels of movement after an inferred lift; a report
  within 6 px of the lift spot is ignored rather than counted as a new touch.

With Panel Touch wired to the panel's Touch Activity:

- Press and release follow the pin exactly; reports that arrive after the release are
  dropped, and a report that beats its own down (within 0.1 s) still lands.
- Long Press pulses after Long Press Time (default 0.6 s) with the finger still.
- A touch that starts outside the picker (no report within 0.15 s of the down) is ignored,
  because Touch Activity is screen-wide.
- A stuck touch (Touch Activity on with no movement for 30 s) is released, and the next
  report presses again. A joystick therefore cannot drive a camera forever.
- Once Panel Touch has changed once, the pad follows it until the script restarts: silence
  no longer infers a lift. A browser or the UCI Viewer app, which have no Touch Activity, is
  then ignored by that pad.
- Leave Panel Touch off when nothing is wired to it. A Panel Touch saved on with nothing
  wired makes the pad wait for a release that never comes.
- One panel per pad: see [One panel per pad](#one-panel-per-pad).

Designer has no Touch Activity, so the limits of the first list apply in Emulate.

## Touch panels

- **One finger at a time per screen.** The panel's viewer follows only the first finger; a
  second finger can cut the first drag short. Two pads on one page take turns.
- **Frame rate.** The plugin sends at most Max Frame Rate frames per second (default 20; 10,
  15, 20 or 30), and only frames that changed. A TSC-G3 checks for control changes about 30
  times a second, so more than 30 would never help. Max Frame Rate is a property: change it
  in Designer and push again.
- **Q-SYS 10.4 or later.** The drawing is a button icon set from the script. The Gesture Pad
  project reports that QSC fixed TSC-G3 button icons that could stay on a loading spinner in
  **10.2** and an icon refresh problem in **10.4**, and recommends 10.4 or later; its testers
  ran 10.0.3, 10.3 and 10.5. The 10.4 item could not be confirmed in QSC's release notes
  while writing this guide. Use 10.4 or later; on 10.0.x expect a pad that sits on a spinner.
- **Panel resolutions.** Designer sizes a UCI for a TSC-70-G3 at 1280 x 800, a TSC-101-G3 at
  1920 x 1200 and a TSC-50-G3 at 1280 x 720 (as reported by the Gesture Pad project). The
  Setup page's "fits at" range assumes 1280 x 800. A UCI made for one size and shown on
  another is scaled by the panel; nobody has tried this plugin that way yet.
- **The drawing's size.** The SVG is capped at 60,000 characters. If a mode's drawing grows
  past it (a Matrix with long names, a Whiteboard with many strokes), elements are dropped
  and Status says `Drawing too large: some elements were dropped` once. Smaller pads, shorter
  names or fewer items fix it.

## Making it look right on a panel

- A touch panel draws the pad faded because the Display is disabled (that is what lets
  touches through to the picker): three stacked copies come out at about 73 %, so 27 % of
  whatever is under them shows through. Over a light page or the wrong color the pad looks
  washed out; a single copy comes out at 35 % and looks very faint.
- So put a box in the pad's own color right under the copies, the pad's size, with the same
  corner radius. What shows through is then the same color and the pad looks solid. The
  Display page prints the value for the chosen theme as `Pad colour: r,g,b`:

  | Theme | Pad color (Background = Solid) | Panel color (Background = Panel) |
  |---|---|---|
  | Nikita | 23,21,28 (`#17151C`) | 32,29,38 (`#201D26`) |
  | Sunset | 18,11,8 (`#120B08`) | 36,23,15 (`#24170F`) |
  | Ocean | 11,20,25 (`#0B1419`) | 19,35,43 (`#13232B`) |
  | Light | 244,244,246 (`#F4F4F6`) | 255,255,255 (`#FFFFFF`) |
  | Custom | your Background Color | 6 % lighter than it |

- **Background = Solid** fills the pad with the theme's background color and draws a 1 px
  frame in the theme's line color with the Corner Radius. Use the pad color above.
- **Background = Panel** fills the pad with the theme's panel color instead (the color of
  the cards and tiles) at 80 % opacity, so the whole pad reads as one card with the page art
  showing through slightly. Leave the box out, as for Transparent; the Display page prints
  `Pad colour: none (Panel: r,g,b at 80 % over the page art)` with the panel color above.
- **Background = Transparent** draws no pad background and no frame, so the page art shows
  through, and the Display page says `Pad colour: none`. The mode's own cards, tiles and
  readouts still draw. Leave the box out.
- **Font.** Text in the drawing uses the Font property, then Roboto, then the panel's
  sans-serif. Panels have Roboto; a UCI style can ship other fonts. Widths are estimated
  with Roboto metrics, so a much wider font may be clipped early and a narrower one leave
  space.
- **Corner Radius** is the frame's radius (default 18). Give the box under the copies the
  same radius, or the box's corners show outside the pad.
- Keep the cover in the page color; only the box under the pad is in the pad's color. The
  pad's own colors come from the theme; on a light page the Light theme or a Custom one
  with your page color as Background Color looks best.
- Designer 10.5's Emulate shows the fade too, so the look can be checked there; the panel
  has the final say.

## Designer notes

These notes come from the Gesture Pad project's published experience with the same
technique; this plugin has not been opened in Designer yet (see
[What has been tested, honestly](#what-has-been-tested-honestly)).

- **Long pin arrays are paged on the Outputs pages**: an output array longer than 16 is shown
  as mini cells (32 per row), 512 per page; a 64 x 64 Matrix therefore has `Outputs` to
  `Outputs 9` (4096 Cross toggles and 64 Route knobs), a 32 x 32 one three pages. Every
  element keeps its pin; the pages only keep Designer's layout work per page small.
- **Emulate redraws the UCI page lazily**: the pad can look a second or more behind. The
  plugin itself reacts within a frame (Debug Print = Gestures shows the timing), and the
  block's own Pad page updates sooner than the UCI tab. Designer 10.5 is reported to redraw
  far faster than 10.0.3.
- **No Touch Activity in Designer**: long press does not work with a still mouse, lifts are
  inferred from Release Time of silence, and lassos and framing boxes are applied about
  1.75 s after the mouse stops. Leave Panel Touch off in Emulate.
- **Identical repeat taps are not resent**: Designer does not resend a value it has already
  sent, so a click exactly on the previous spot, before the picker is parked (about 0.55 s
  after a tap), does not arrive at all. A mouse double-click therefore cannot test a double
  tap: click twice a few pixels apart (within 40 px and 0.4 s). Touch panels send every
  touch. The plugin does not try to work around this.
- **Designer's wider picker rectangle and the D line**: Designer draws the picker's surface as
  a wider rectangle than a panel's square. By default the plugin assumes the pad covers the
  left 4/7 of that rectangle's width and its full height (the built-in `D 0 0 0.5714 1`);
  on a panel or in a browser it assumes the square equals the pad (`P 0 0 1 1`). If the dot
  does not follow the mouse in Emulate, run Calibrate there: it writes a D line that applies
  only while emulating, and a P line made on a panel is left alone.
- Files written by Sign-In and Whiteboard go under `design/` in Emulate and are temporary;
  on a Core they go under `media/`.

## Themes

Pick one with the Theme property. Hex values are what the drawing uses; the pad color (the
box under the copies) is the `bg` value.

| Key | Used for | Nikita | Sunset | Ocean | Light |
|---|---|---|---|---|---|
| bg | pad background | `#17151C` | `#120B08` | `#0B1419` | `#F4F4F6` |
| panel | cards and tiles | `#201D26` | `#24170F` | `#13232B` | `#FFFFFF` |
| well | tracks and readouts | `#0E0D12` | `#0C0705` | `#070E12` | `#E8EAEE` |
| line | hairlines and the frame | `#35313E` | `#45301F` | `#1F3640` | `#D0D4DA` |
| accent | highlights, the finger dot | `#C513E8` | `#FF8A3D` | `#2AB7D8` | `#2F6FEB` |
| accent2 | second highlight | `#FF8A1E` | `#FFC857` | `#5ED3EA` | `#1DA27A` |
| accent3 | third highlight | `#7A1BE8` | `#F0563A` | `#1C86A0` | `#7A1BE8` |
| text | text | `#F4F2F7` | `#FFF5EC` | `#E6F0F3` | `#1B1F24` |
| muted | hints and captions | `#A79FB3` | `#C7AE9C` | `#8FA6AE` | `#6B7280` |
| onAccent | text on an accent fill | `#FFFFFF` | `#2A140A` | `#06161C` | `#FFFFFF` |
| danger | mute, privacy, failed | `#F0328C` | `#C8102E` | `#E0433C` | `#D92D20` |
| ok | success | `#2ECC8F` | `#7BC67E` | `#3CCB8A` | `#1DA27A` |

**Custom** starts from Nikita and takes three `#RRGGBB` properties:

- **Background Color** sets `bg`; `panel` is 6 % lighter, `well` 5 % darker, `line` 14 %
  lighter, and the pad color printed on the Display page follows it.
- **Accent Color** sets `accent`; `accent2` is 25 % lighter and `accent3` 20 % darker.
- **Text Color** sets `text`; `muted` is the text mixed 40 % toward the background.

A blank or invalid value keeps Nikita's for that group. The other keys (`onAccent`, `danger`,
`ok`) stay as in Nikita.

## Status messages and troubleshooting

Status is the block's `Status` pin and the LED in every page header. Green is OK, amber a
warning, red an error. Every text the plugin can show:

| Status | Meaning | What to do |
|---|---|---|
| `OK - Ready. Picker OK: <x> / <y>` | Bound to the picker; `<x>` and `<y>` are the names of its two axis controls. | Nothing. |
| `OK - Picker bound through its colour output (coarse): <picker> / <control>` | No axis controls were recognized, so the plugin reads the picker's hex color output and derives the position from it. It works, with 8-bit steps and one report per touch. | Set Debug Print to All, press Refresh and send the printed control list, so the axis names can be added. |
| `No Color Picker in the design: add one and set its Script Access to All` | The Color Picker property is blank and the design lists no Color Picker the script can see. | Add a Color Picker, set its Script Access to All (or Script), and name it in the property or the Picker text. |
| `<n> Color Pickers in the design: name one in the Color Picker property` | The property is blank and several pickers exist. | Type the Code Name of this pad's picker into the property or the Setup page's Picker text. |
| `No picker named <name>` | No component with that Code Name is reachable. | Check the Code Name (not the label) and the picker's Script Access. Press Refresh after changing it. |
| `<name> is not a Color Picker` | The component exists but is another type. | Name the picker, not another block. |
| `Set the picker's Script Access to All: <name>` | The picker is listed but its controls cannot be read. | Set the picker's Script Access to All (or Script) and press Refresh. |
| `<name> has no recognised axis controls (controls: ...)` | The picker was opened but none of its control names look like saturation and value. | Send the names shown (Debug Print = All prints the full list) so they can be added; meanwhile the hex fallback above may bind on Refresh. |
| `Mode <name> is not available in this build` | The plugin was built without that mode's module; the pad draws `<name> is not available`. | Use the full build, or another mode. |
| `Recovered from an error: <first line>` | A handler raised a Lua error; the pad kept working and the next touch is handled. `(xN)` counts repeats; the full trace is printed to the Debug Output at most every 5 s. | Note what you did and send the Debug Output. Status returns to OK after the next clean touch. |
| `Drawing too large: some elements were dropped` | A frame went past 60,000 characters; the rest of that frame was dropped. Shown once. | Fewer items, shorter names or a smaller pad. |
| `Calibration: tap the top-left target` | Calibrate is on and waiting for the first tap. | Tap the top-left target. |
| `Calibration: now tap the bottom-right target` | The first tap was accepted. | Tap the bottom-right target. |
| `Calibration: tap closer to target <n>` | A tap landed too far from the target. | Tap the target itself. |
| `Calibration failed: the two taps are too close` | The two taps did not span the pad. | Turn Calibrate on again and tap both targets. |
| `Calibrated: P ...` or `Calibrated: D ...` | Done; the line is in the Calibration text. | Copy the line into the design to keep it. |
| `Calibration cancelled` | Calibrate was turned off before the second tap. | Nothing. |
| `Calibration cancelled: no taps for 60 s` | Calibrate timed out. | Turn it on again when ready. |

Modes can add their own status texts (a camera that does not answer, a file that could not
be saved); those are described in the mode's section.

Other things to check when Status is OK and the pad still does not respond: something other
than graphics is on top of the picker (a button or a text field over the pad takes the
touch); the UCI shows a different picker than the one the block is bound to; Swipe Disabled
is off and a sideways drag flips the page; Panel Touch is on with nothing wired; Lock is on
(the pad is dimmed with a lock icon). With Debug Print = All, every picker report is printed
as `report u=... v=... -> x y in|out`, which shows at once whether reports arrive and where
they land.

## Per mode

Every chapter lists only what the mode adds to the [common pins](#common-pins-and-controls).
Pins are named `Group ~ Name`; the Lua name in backticks is what a script uses through
`Component.New`. An `n` after a name marks an array whose length comes from a property.
Camera modes (Joystick, PTZ Pad, Camera Framing, Dial) also carry the Camera group when
Camera Control is not None: `ZoomIn`, `ZoomOut`, `MaxSpeed`, `ZoomSpeed`, `CameraStatus`,
`CameraIP` (VISCA over IP) and the `CameraView` display (Demo).

### XY Pad

The plainest mode and the one to start with: a card with a dotted grid, crosshair lines that
follow the finger and a dot at the finger. Hint: `Drag anywhere`. It adds no control of its
own; everything it reports is the common set: `X` and `Y` live while touching and held after
the lift, `Touching`, the `Tap`, `DoubleTap`, `LongPress`, `Press`, `Release` and swipe
pulses, `Gesture`, `DragDistance` and `DragAngle`. Pages: Pad, Setup, Outputs, Display, About.

Use it to drive anything that wants two 0..1 values (a pan and tilt pair, an effect's two
parameters, a two-axis light position) or as the mode for checking the picker binding and the
calibration: the dot must sit under the finger everywhere on the pad.

### Swipe Layer

A pad that shows almost nothing: a finger trail that fades behind the touch and a brief
chevron in the direction of a recognised swipe. Hint: `Swipe in any direction`. It is meant
to sit over page art as an invisible gesture layer, usually with Background = Transparent.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Swipe Distance | `SwipeDistance` | Knob, 0.05..0.8 | in | Default 0.2. Fraction of the pad diagonal a swipe must cover. |

Behaviour: a swipe needs distance and speed, at most 0.6 s from the start of its stroke to
the lift, with one axis at least 1.5 times the other. The swipe pulses are the common
`SwipeLeft`, `SwipeRight`, `SwipeUp` and `SwipeDown`. Quick swipes in a row each count: with
Panel Touch wired every lift is certain; without it, a finger that lands again after a gap of
more than three reports, or a report that jumps across the pad, starts a new stroke and the
stroke that just ended is classified and pulsed at once. A second swipe within 0.25 s of the
first is not lost.

Recipe (UCI pages): put the Swipe Layer on a UCI layer that is on every page, set the UCI's
Swipe Disabled on so Q-SYS does not flip pages itself, and let a Text Controller turn the
pulses into `Uci.SetPage`:

```lua
local pad = Component.New("Swipe_Pad")               -- the block's Code Name
local UCI, PAGES = "Lobby UCI", { "Welcome", "Rooms", "Help" }
local page = 1
local function show() Uci.SetPage(UCI, PAGES[page]) end
pad.SwipeLeft.EventHandler = function(ctl)
  if ctl.Boolean and page < #PAGES then page = page + 1; show() end
end
pad.SwipeRight.EventHandler = function(ctl)
  if ctl.Boolean and page > 1 then page = page - 1; show() end
end
```

The full version is in [Recipes](#recipes).

### Joystick

A virtual stick: it sits where the finger is, measured from the centre of the pad and scaled
by the base radius (the rim is full travel). Hint: `Drag the stick. Double tap: home`. Pages:
Pad, Setup, Camera View (Demo camera), Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Joystick ~ Joy X | `JoyX` | Knob, -1..1 | out | The stick's horizontal position, -1 left to 1 right. |
| Joystick ~ Joy Y | `JoyY` | Knob, -1..1 | out | The stick's vertical position, -1 down to 1 up. |
| Joystick ~ Magnitude | `Magnitude` | Knob, 0..1 | out | How far the stick is from the centre. |
| Joystick ~ Dir Left / Right / Up / Down | `DirLeft`, `DirRight`, `DirUp`, `DirDown` | LED | out | Eight-way direction sectors. |
| Joystick ~ Deadzone | `Deadzone` | Knob, 0..0.5 | in | Default 0.08. Radius around the centre that outputs zero. |
| Joystick ~ Curve | `Curve` | Text, Linear / Squared / Cubed | in | The response curve. |
| Joystick ~ Sticky | `Sticky` | Toggle | in | On: the stick stays where it is left. Off: it springs back over 0.15 s. |
| Joystick ~ Home | `Home` | Trigger | both | Re-centres the stick and sends the camera home; pulses when the pad does it. |
| Joystick ~ Invert Pan / Invert Tilt | `InvertPan`, `InvertTilt` | Toggle | both | Mirror an axis. |

Properties: Camera Control, Camera Name and VISCA Brand (see [Camera](#camera)). With a
camera the stick's output drives pan and tilt at up to Max Speed; Zoom In and Zoom Out drive
the zoom at Zoom Speed; the Demo camera's scene is drawn on the Camera View. Safety: a Panel
Touch that sticks on is released after 30 s without movement, and a Home pin held longer than
half a second homes once, on its rising edge. Lock returns the stick to the centre.

### PTZ Pad

Drag to aim. The pad is a map of everything the camera can reach: a drag moves the aim like
a trackpad (relative, scaled by Sensitivity), a plain tap moves nothing and a double tap
sends the aim home. Hint: `Drag to aim. Double tap = home`. Pages as Joystick.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| PTZ Pad ~ Pan / Tilt | `Pan`, `Tilt` | Knob, 0..1 | out | Absolute aim; 0.5 is home. |
| PTZ Pad ~ Pan Speed / Tilt Speed | `PanSpeed`, `TiltSpeed` | Knob, -1..1 | out | Speed while dragging; 1 is one pad width per half second. |
| PTZ Pad ~ Dir Left / Right / Up / Down | `DirLeft`, `DirRight`, `DirUp`, `DirDown` | LED | out | Which way the aim is moving. |
| PTZ Pad ~ Sensitivity | `Sensitivity` | Knob, 0.2..3 | in | Default 1. How far the aim moves for a given drag. |
| PTZ Pad ~ Home | `Home` | Trigger | both | Sends the aim and the camera home. |
| PTZ Pad ~ Invert Pan / Invert Tilt | `InvertPan`, `InvertTilt` | Toggle | both | Mirror a direction. |
| Camera ~ HFOV | `HFOV` | Knob, 20..120 | in | Default 60. The camera's horizontal field of view in degrees; sizes the view box. |
| Camera ~ Optical Zoom | `OpticalZoom` | Knob, 1..40 | in | Default 12. The camera's maximum optical zoom factor. |

With a camera the aim is sent as an absolute position (pan -170..170 degrees, tilt -90..90)
at most ten times a second while dragging; Zoom In and Zoom Out drive the zoom. Without a
camera the Pan and Tilt outputs are the way to drive a camera block of your own.

### Camera Framing

Draw a box around the next shot. The pad shows the camera's current view as the widest 16:9
box on the pad; a box drawn on it is a region of that view. Hint: `Draw a box to frame.
Double tap = zoom out`. Pages as Joystick.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Camera Framing ~ Frame Pan / Frame Tilt | `FramePan`, `FrameTilt` | Knob, 0..1 | out | The applied frame's centre within the home view; 0.5 is home. |
| Camera Framing ~ Frame Zoom | `FrameZoom` | Knob, 0..1 | out | 0 is the whole view, 1 the tightest frame (Min Frame of the home view). |
| Camera Framing ~ Apply | `Apply` | Trigger | both | Pulses when a shot is sent; pulse it to apply the current box. |
| Camera Framing ~ Reset | `Reset` | Trigger | both | Zooms all the way out (the whole home view). |
| Camera Framing ~ Home | `Home` | Trigger | both | Zooms out and sends the camera home. |
| Camera Framing ~ Min Frame | `MinFrame` | Knob, 0.1..0.6 | in | Default 0.25. The smallest frame as a fraction of the home view. |
| Camera Framing ~ Invert Pan / Invert Tilt | `InvertPan`, `InvertTilt` | Toggle | both | Mirror the direction of the outputs and the camera. |
| Camera ~ HFOV, Optical Zoom | `HFOV`, `OpticalZoom` | Knob | in | Turn a frame into camera degrees and a zoom position. |

Behaviour: the box stays on the pad after it is applied. Dragging inside it moves it,
dragging a corner resizes it, and each is applied as a corrected shot within the same view.
A new box drawn outside it first re-bases the pad on the current shot, so boxes add up: each
is relative to the view the camera has at that moment. A box smaller than 8 % of the pad
(width or height) is ignored and changes nothing. A certain lift (Panel Touch) applies at
once; an inferred lift applies 1.5 s later unless the drag resumes; a new touch, a new box or
Zoom In / Out send a pending shot at once; Lock drops it. Double tap zooms out and pulses
Reset. With a camera the frame goes out through an absolute position: pan = (cx - 0.5) x
HFOV, tilt = (0.5 - cy) x HFOV x 9/16, zoom position = (1/fw - 1) / (Optical Zoom - 1); a
frame is never tighter than Min Frame or than the camera's reach.

### Dial

An endless jog wheel with detents. The wheel turns with the finger's angle around the pad
centre; the inner 30 % of the wheel is a dead centre that does nothing, and the first 8
degrees of every new touch are settling. Hint: `Turn the wheel. The centre does nothing`.
Pages: Pad, Setup, Camera View (Demo camera), Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Dial ~ Dial Value | `DialValue` | Knob, 0..1 | both | The level; clockwise raises it, bounded at both ends. |
| Dial ~ Step Up / Step Down | `StepUp`, `StepDown` | Trigger | out | One pulse per detent, in each direction. |
| Dial ~ Turns | `Turns` | Knob, 0.5..10 | in | Default 2. Full turns that cover the whole range. |
| Dial ~ Detents | `Detents` | Knob, 0..72 | in | Default 24. Notches per turn; 0 for none. |
| Dial ~ Dial Target | `DialTarget` | Text | in | A control driven directly, as `CodeName~control`. |
| Camera ~ Optical Zoom | `OpticalZoom` | Knob, 1..40 | in | Camera only. Sizes the zoom factor readout. |

Behaviour: the step pulses keep coming at the ends of the range (the wheel is endless, only
the level is bounded), and a flick that clicks past more notches than one report can pulse
pays the rest off over the next frames. A Dial Target (`CodeName~control`) is driven
position-wise and followed when it changes elsewhere, even while a finger rests on the wheel;
Dial Value written from outside is followed the same way. A target problem (`no component
named ...`, `... has no control ...`) shows on Status while nothing worse is reported there.
With a camera the level is the camera's zoom position: the wheel shows the zoom factor read
back from the camera, Zoom In / Out changes made elsewhere are followed, and a camera whose
position is unknown gets zoom speed bursts instead.

Recipe: to turn a QSC Gain block from the wheel, set the gain block's Script Access to Script
or All, give it the Code Name `Program_Gain` and type `Program_Gain~gain` into Dial Target.
Two full turns sweep the gain from its minimum to its maximum; raise Turns for finer control.
The same text works in Knob and Fader.

### Knob

A bounded rotary with a 270 degree sweep (from bottom-left over the top to bottom-right), a
value readout in display units and Min / Max labels. Hint: `Touch the ring to set, drag to
turn`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Knob ~ Knob Min / Knob Max | `KnobMin`, `KnobMax` | Knob, -1000..1000 | in | Defaults 0 and 100. The display range. |
| Knob ~ Units | `Units` | Text | in | The unit text after the value (cut to 24 characters). |
| Knob ~ Knob Value | `KnobValue` | Knob | both | The value in display units. |
| Knob ~ Knob Position | `KnobPosition` | Knob, 0..1 | both | The position along the sweep. |
| Knob ~ Dial Target | `DialTarget` | Text | in | A control driven directly, as `CodeName~control`. |

Behaviour: a touch on the ring (the track outside the knob body) sets the value from the
touch angle; dragging anywhere then turns the knob relative to the finger's angular movement
with acceleration (a fast turn moves up to three times as far as a slow one). Nothing wraps.
The Dial Target follows the Dial's rules. Recipe: `Program_Gain~gain` in Dial Target, Knob
Min -100, Knob Max 20, Units `dB`, so the readout shows the gain in dB while the target is
driven by position.

### Fader

A linear touch fader. The whole pad is the fader: a touch anywhere across the slot works.
Hint: `Touch or drag the fader`. Property: Orientation (Vertical or Horizontal). Pages: Pad,
Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Fader ~ Fader Min / Fader Max | `FaderMin`, `FaderMax` | Knob, -1000..1000 | in | Defaults -100 and 10. The display range. |
| Fader ~ Units | `Units` | Text | in | Default `dB`. |
| Fader ~ Fader Value | `FaderValue` | Knob | both | The value in display units. |
| Fader ~ Fader Position | `FaderPosition` | Knob, 0..1 | both | The position along the travel. |
| Fader ~ Grab Mode | `GrabMode` | Text, Jump / Relative | in | Jump sets the value where you touch; Relative moves it from where it was by the finger's travel. |
| Fader ~ Taper | `Taper` | Text, Linear / Audio | in | Audio puts 0 dB at 75 % of the travel for a -100..10 range with a piecewise curve. |
| Fader ~ Snap Center | `SnapCenter` | Toggle | in | Snaps a touch-driven position to the centre value within 3 % of the travel. |
| Fader ~ Dial Target | `DialTarget` | Text | in | A control driven directly, as `CodeName~control`. |

Behaviour: the pad draws the slot, the fill, the cap, scale ticks with labels and the value.
At start the fader resumes from the persisted Fader Position (or the target's level when a
Dial Target binds) rather than the minimum. Min equal to Max is a degenerate range: every
value reads Min and the scale carries no labels. Recipe: `Program_Gain~gain` in Dial Target
with Taper = Audio gives a fader whose top quarter is the useful -10..+10 dB region.

### Panner

A two-dimensional panner over a speaker layout chosen by the Speakers property (Stereo, LCR,
Quad, 5.1, 7.1). The finger places the source in the room: a touch jumps there, a drag
follows, a double tap returns it to the centre. Hint: `Drag to pan, double tap to centre`.
Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Panner ~ Pan X | `PanX` | Knob, -1..1 | both | Left-right position. |
| Panner ~ Pan Y | `PanY` | Knob, -1..1 | both | Back-front position (1 is the front). |
| Panner ~ Pan | `Pan` | Knob, -1..1 | both | A stereo pan; it equals Pan X. |
| Panner ~ Speaker Gain n | `SpeakerGain n` | Knob, dB -80..0 | out | One per speaker. |
| Panner ~ Divergence | `Divergence` | Knob, 0..1 | in | Default 0.5. 0 feeds the nearest speaker only, 1 spreads the source over every speaker within about a decibel. |

Behaviour: the gains come from a constant-power law on the distance between the source and
each speaker (a gaussian kernel whose width grows with Divergence; the weights are normalised
so their squares sum to one and clamped at 1e-4, so -80 dB is the floor). The LFE channel of
5.1 and 7.1 has no position and stays at 0 dB. Writing Pan X, Pan Y or Pan from outside moves
the source and recomputes the gains. The pad draws the room, every speaker with a glow that
follows its gain, the gain readouts and the source dot with two guide lines.

Recipe: to pan a microphone of the Nikita Mic Mixer, wire the pad's `Panner ~ Pan` pin to the
Mic Mixer's `MicPan 1` pin in the schematic; both are -1..1 pan knobs, so no script is
needed. For the full speaker set, wire each `Speaker Gain n` to a gain block's gain pin.

### Zone Select

A set of named zones (a room plan, a seating map, a row of displays) drawn on the pad.
Hint: `Tap, drag or circle zones`; in edit mode `Edit: drag to move, corner to resize`.
Property: Zones (1..32, default 8). Pages: Pad, Setup, Names, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Zones ~ Zone Name n | `ZoneName n` | Text | in | The name drawn on each zone (Names page). |
| Zones ~ Zone Selected n | `ZoneSelected n` | Toggle | both | Whether each zone is selected. |
| Zones ~ Select All / Clear All | `SelectAll`, `ClearAll` | Trigger | in | Select or clear every zone. |
| Zones ~ Selected List | `SelectedList` | Text | out | The selected zone numbers, comma separated. |
| Zones ~ Edit | `Edit` | Toggle | in | Edit the layout on the pad. |
| Zones ~ Show Background | `ShowBackground` | Toggle | in | Default on. Draws the pad background behind the zones. |
| Zones ~ Zone Layout | `ZoneLayout` | Text | both | The zone rectangles as a JSON list of `{x,y,w,h}` in 0..1 pad units; blank means the Columns grid. |
| Zones ~ Exclusive | `Exclusive` | Toggle | in | One zone at a time, like a radio group. |
| Zones ~ Columns | `Columns` | Knob, 1..8 | in | Default 4. Columns of the default grid. |

Gestures: tap toggles a zone; a drag that starts on a zone paints the opposite of that
zone's state across every zone it crosses; a closed lasso drawn on empty space selects the
zones whose centres it encloses (an open, small or short path is ignored); a long press on a
zone solos it; a double tap on empty space clears everything. Edit mode: drag a zone to move
it, its bottom-right corner to resize it, empty space to redraw the last touched zone; it
switches off after 5 min untouched and prints the layout to the Debug Output, so you can
paste it into Zone Layout. Lock drops a drag and a pending lasso.

Recipe: to turn zone selection into speaker mutes, wire each `Zone Selected n` pin to a
Logic > NOT block and the NOT's output to the matching mute pin of your mixer or gain: a
selected zone is unmuted, an unselected one muted. With Exclusive on it becomes a one-room
page selector.

### Drag & Drop

Sources on the left, screens (destinations) on the right. Drag a source tile onto a screen
to route it, or tap a source and then a screen. Hints: `Drag a source to a screen`, `Now tap
a screen`, `Drop on a screen`. Properties: Sources (1..64, default 4) and Destinations
(1..64, default 2). Pages: Pad, Setup, Names (Sources and Destinations above 16 of either),
Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Sources ~ Source Name n | `SourceName n` | Text | in | The name drawn on each source tile. |
| Sources ~ Source Active n | `SourceActive n` | Toggle | in | Default on. Signal present; off dims the tile. |
| Routing ~ Dest Name n | `DestName n` | Text | in | The name drawn on each screen tile. |
| Routing ~ Route n | `Route n` | Knob, 0..Sources | both | The source number routed to each screen; 0 is none. |
| Routing ~ Routed n | `Routed n` | Trigger | out | Pulses when a screen's route changes. |
| Routing ~ Route Name n | `RouteName n` | Text | out | The name of the source routed to each screen. |
| Routing ~ Clear Routes | `ClearRoutes` | Trigger | in | Clears every route. |
| Routing ~ Tap Only | `TapOnly` | Toggle | in | No drags: tap a source, then a screen. |
| Routing ~ Allow Calls | `AllowCalls` | Toggle | in | Default on. A double tap on a source skips screens whose name holds teams, zoom, webex, codec or call. |

Behaviour: a double tap (two taps on the same tile) sends a source to every screen, except,
with Allow Calls on, screens whose name carries a call word, so a running call is not
hijacked. Lists page when their tiles would drop under 56 px (never more than 12 sources or
16 screens on a page); dropping a source on a list's arrows turns that page and keeps the
source picked; a picked source is put down after 8 s. Tile icons follow whole words in the
names (laptop, pc, teams, zoom, camera, doc cam, apple tv, clickshare, mic, music, display,
projector, room). A Route written from outside updates the drawing and pulses Routed only
when it changed. Gesture shows the route made (`LAPTOP -> FRONT DISPLAY`) and the hints
(`NOW TAP A SCREEN`, `ALL CLEARED`).

Recipe: a Q-SYS Router counts its inputs from 1 and has no "none", while Route n is 0 for
none. Give the router one input more than there are sources and leave it unconnected (the
blank input), then map 0 to it in a Text Controller:

```lua
local pad, router = Component.New("Lobby_Pad"), Component.New("Video_Router")
local SOURCES, SCREENS = 4, 2
local BLANK = SOURCES + 1                      -- the unconnected router input
for d = 1, SCREENS do
  local route = pad["Route " .. d]
  local function apply()
    local src = math.floor(route.Value)
    router["select." .. d].Value = (src >= 1 and src <= SOURCES) and src or BLANK
  end
  route.EventHandler = apply
  apply()
end
```

`select.d` is the Router's output selector; read the exact control names off the Router's
Control Pins list in your design. The same script serves Matrix with Exclusive Columns on.

### Matrix

A crosspoint grid: sources are the rows, destinations the columns. Hint: `Tap a crosspoint,
drag to paint`. Properties: Sources and Destinations as Drag & Drop. Pages: Pad, Setup,
Names (or Sources and Destinations), Outputs (paged for long arrays), Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Sources ~ Source Name n | `SourceName n` | Text | in | The name of each row. |
| Routing ~ Dest Name n | `DestName n` | Text | in | The name of each column. |
| Matrix ~ Cross n | `Cross n` | Toggle | both | Each crosspoint; index = (row - 1) x columns + column. |
| Routing ~ Route n | `Route n` | Knob, 0..Sources | both | The source number routed to each column; 0 is none. |
| Routing ~ Exclusive Columns | `ExclusiveColumns` | Toggle | in | Default on. A column carries one source at a time. |
| Routing ~ Clear All | `ClearAll` | Trigger | in | Clears every crosspoint. |

Behaviour: tap a crosspoint to toggle it; a drag that starts on a crosspoint paints its new
state across every crosspoint it crosses; a tap on a row header sends that source to every
column; a tap on a column header clears that column. With Exclusive Columns on, Route n is
kept in sync both ways; with it off a column may carry several sources and Route n shows the
source routed last (0 once the column is empty). The grid shows at most 12 rows and 12
columns at a time; larger matrices page with arrow bars under the row headers (row pages)
and under the cells (column pages), and a swipe that starts on a header or an arrow bar turns
the pages too. A tap acts on the cell that was pressed, not on whatever lies under the lift.
Pin writes of a big matrix are spread over engine turns so a row select or Clear All on a
64 x 64 matrix stays within budget. The router recipe of Drag & Drop applies unchanged.

### Pattern Lock

A dot grid (3 x 3 by default, up to 5 x 5). The finger joins dots; a lift checks the drawn
pattern against the secret. Hints: `Draw your pattern`, `Set a pattern first`. Pages: Pad,
Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Pattern Lock ~ Grid Size | `GridSize` | Knob, 3..5 | in | Default 3. Dots per side. |
| Pattern Lock ~ Pattern | `Pattern` | Text | in | The secret as digits, `1-5-9-6` or `1596`, numbered left to right, top to bottom. |
| Pattern Lock ~ Unlocked / Failed | `Unlocked`, `Failed` | Trigger | out | The result of a check. |
| Pattern Lock ~ Locked | `Locked` | Toggle | both | On after Max Tries failures for Lockout Seconds; off clears the lockout. |
| Pattern Lock ~ Max Tries | `MaxTries` | Knob, 1..10 | in | Default 5. |
| Pattern Lock ~ Lockout Seconds | `LockoutSeconds` | Knob, 10..3600 | in | Default 60. |
| Pattern Lock ~ Last Pattern | `LastPattern` | Indicator Text | out | The pattern just drawn, for a script that records one. |
| Pattern Lock ~ Learn | `Learn` | Toggle | in | The next drawn pattern becomes the secret. |
| Pattern Lock ~ Masked | `Masked` | Toggle | in | Hides the trail; a row of small dots above the grid counts the joined dots. |
| Pattern Lock ~ Auto Submit | `AutoSubmit` | Toggle | in | Checks as soon as the pattern is as long as the secret (never while learning). |

Behaviour: a drag that passes within 22 % of the dot spacing of a dot adds it (no repeats,
line segments between dots, a skipped dot that lies exactly between two added dots is
added). The pad draws the dots, the trail and green or red feedback for 0.8 s. A pattern has
at least two dots: a tap on one dot is dropped without a check, does not count as a try and
is not learned, and a Pattern text with fewer than two dots is no secret. On a pad too small
for the top line and the hint those texts are left out rather than drawn over the dots.

Recipe (door strike): the same Text Controller as the Keypad's, with `pad.Unlocked` in place
of `pad.Accepted`.

### Keypad

A numeric keypad drawn by the pad (digits 0-9, clear, enter) for PIN entry on a lobby or a
lectern. Hint: `Tap a key, swipe left to delete`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Keypad ~ Pin | `Pin` | Text | in | Default `1234`. The accepted code or codes, separated by commas. |
| Keypad ~ Entry | `Entry` | Text | out | The digits entered so far. |
| Keypad ~ Masked | `Masked` | Toggle | in | Default on. Dots instead of digits on the pad; Gesture shows `KEY *`. |
| Keypad ~ Auto Submit | `AutoSubmit` | Toggle | in | Default on. Submits as soon as the entry is as long as a code. |
| Keypad ~ Learn | `Learn` | Toggle | in | The next code entered and confirmed with Enter is stored as the Pin. |
| Keypad ~ Accepted / Rejected | `Accepted`, `Rejected` | Trigger | out | The result of a check. |
| Keypad ~ Locked | `Locked` | Toggle | both | On after Max Tries failures for Lockout Seconds; off clears the lockout. |
| Keypad ~ Max Tries | `MaxTries` | Knob, 1..10 | in | Default 5. |
| Keypad ~ Lockout Seconds | `LockoutSeconds` | Knob, 10..3600 | in | Default 60. |

Behaviour: a key is entered when the finger lifts from it (the touch landed on the key and
never moved more than 12 px), however long it rested there; a drag or a swipe presses
nothing; keys highlight for 0.15 s; a swipe left deletes a digit. Codes of different lengths
want Auto Submit off, since it submits at the first matching length. Without Panel Touch the
same key tapped twice in quick succession needs a 0.5 s pause (the engine treats a report
within 6 px and 0.5 s of the last tap as the finger peeling off).

Recipe (door strike): a Text Controller with one Control Pin, a button named `Door`, wired
to the strike relay. The pulse goes true and then false, so the handler acts on the rising
edge, and a second event within the pulse only restarts the three seconds:

```lua
local pad = Component.New("Lobby_Keypad")
local timer = Timer.New()
timer.EventHandler = function() timer:Stop(); Controls.Door.Boolean = false end
pad.Accepted.EventHandler = function(ctl)
  if not ctl.Boolean then return end
  Controls.Door.Boolean = true
  timer:Stop(); timer:Start(3)
end
```

### Sign-In

A visitor sign-in pad: a signature area drawn by the pad plus the guest fields, which the
UCI's own text boxes fill. Hint: `Sign above the line, then press Sign In`. Property: Sign-In
Webhook (Off, JSON, Teams Card). Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Guest ~ Guest Name / Guest Company / Visiting | `GuestName`, `GuestCompany`, `Visiting` | Text | both | The form fields. |
| Sign-In ~ Submit | `Submit` | Trigger | in | Signs the guest in. |
| Sign-In ~ Clear / Clear Signature | `Clear`, `ClearSignature` | Trigger | in | Clear the form, or the signature only. |
| Sign-In ~ Submitted | `Submitted` | Trigger | out | Pulses after a successful sign-in. |
| Sign-In ~ Last Guest / Today Count | `LastGuest`, `TodayCount` | Text | out | The last name, and today's count. |
| Sign-In ~ Room Name | `RoomName` | Text | in | Written to the log and the webhook. |
| Sign-In ~ Webhook Url | `WebhookUrl` | Text | in | Where each sign-in is posted. |
| Sign-In ~ Send Status | `SendStatus` | Text | out | The result of the last post. |
| Sign-In ~ Pen Width | `PenWidth` | Knob, 1..8 | in | Default 3. |

Behaviour: Submit writes the signature as `<base>/SignIns/<time>_<name>.svg`, appends a line
to `<base>/SignIns/log.csv` (UTF-8 with a BOM written once when the file is created; a cell
starting with `=`, `+`, `-` or `@` gets a leading apostrophe so a spreadsheet does not run
it), pulses Submitted, sets Last Guest and Today Count, posts the webhook and clears the form.
`<base>` is `design` in Emulate and `media` on a Core. A failed save shows `Not saved: please
ask at reception`, counts nothing and pulses nothing. Today Count counts today's lines of the
log at start-up and resets at midnight; the form clears after three idle minutes; a second
Submit right after a sign-in does nothing. The JSON webhook posts name, company, visiting,
room, the time in ISO 8601, the signature as base64 SVG and the file name; the Teams Card is
an Adaptive Card without the signature. Strokes are polylines simplified to at most 400
points each, at most 60 strokes; a touch without movement draws a dot.

### Whiteboard

Freehand drawing for annotation. One finger draws strokes in the pen colour and width; a
touch without movement draws a dot. Hints: `Draw with one finger`, `Eraser: drag across a
stroke to remove it`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Whiteboard ~ Pen Width | `PenWidth` | Knob, 1..8 | in | Default 3. |
| Whiteboard ~ Pen Color | `PenColor` | Text, Accent / White / Black / Red / Green / Blue | in | Default Accent. |
| Whiteboard ~ Eraser | `Eraser` | Toggle | in | The finger removes every stroke it crosses. |
| Whiteboard ~ Undo | `Undo` | Trigger | in | Removes the last stroke. |
| Whiteboard ~ Clear Board | `ClearBoard` | Trigger | in | Empties the board. |
| Whiteboard ~ Snapshot | `Snapshot` | Trigger | in | Writes `<base>/Whiteboard/<time>.svg`. |
| Whiteboard ~ Strokes | `Strokes` | Indicator Text | out | The stroke count. |
| Whiteboard ~ Last File | `LastFile` | Text | out | The file written by the last snapshot. |

Behaviour: the board keeps at most 60 strokes (the oldest is dropped) and at most 2400
points (the oldest strokes are halved), and a stroke keeps at most 400 points, so the drawing
always fits the display. A stroke ended by an inferred lift continues when the finger comes
back within 1.6 s close to where it left; a touch farther away is a new stroke, so letters
written in quick succession without Panel Touch are not joined. Two-finger erase is not
possible (the picker reports one finger), hence the Eraser toggle.

## Recipes

All recipes run in a Text Controller (Design > Scripting) with the Touch Pad block's Script
Access set to Script or All and a Code Name given to it. `Component.New("Code_Name")`
returns the block's controls by their Lua names (`pad.X`, `pad["Route 2"]`). A trigger pin
pulses: it goes true and then false at once, so a handler sees two events; act on the one
where `ctl.Boolean` is true. Where a pin can be wired straight to another pin in the
schematic (the Panner's Pan to a pan knob, Zone Selected to a NOT), prefer the wire.

**Drag & Drop or Matrix to a Q-SYS Router (0 means blank).** Q-SYS routers count inputs
from 1 and have no "none"; Route n is 0 for none. Add one input more than there are sources
to the Router, leave it unconnected, and map 0 to it:

```lua
local pad, router = Component.New("Lobby_Pad"), Component.New("Video_Router")
local SOURCES, SCREENS = 4, 2                 -- the block's Sources and Destinations
local BLANK = SOURCES + 1                     -- the unconnected router input
for d = 1, SCREENS do
  local route = pad["Route " .. d]
  local function apply()
    local src = math.floor(route.Value)
    router["select." .. d].Value = (src >= 1 and src <= SOURCES) and src or BLANK
  end
  route.EventHandler = apply
  apply()                                     -- align the router with the pad at start
end
```

To feed the pad from the router as well (so a route made elsewhere shows on the tiles), set
`pad["Route " .. d].Value` from the router's selector in its EventHandler; the pad pulses
Routed only when the value changed, so there is no loop.

**Dial, Knob or Fader driving a control directly.** No script: give the target block a Code
Name and Script Access, and type `CodeName~control` into Dial Target, for example
`Program_Gain~gain`. The pad drives the control by position and follows it when it changes
elsewhere. For a plugin's array control use the spaced name: `Mic_Mixer~MicGain 1`. Status
tells you when the component or the control is not found.

**Panner to the Mic Mixer's pan.** Wire `Panner ~ Pan` to the Mic Mixer's `MicPan n` pin.
Both are -1..1 pan knobs. For a surround send, wire each `Speaker Gain n` (dB) to a gain
block's gain pin and set Divergence to taste.

**Swipe Layer to UCI pages.** Put the Swipe Layer on a UCI layer that is on every page, set
Swipe Disabled on the UCI, and:

```lua
local pad = Component.New("Swipe_Pad")
local UCI, PAGES = "Lobby UCI", { "Welcome", "Rooms", "Help" }
local page = 1
local function show() Uci.SetPage(UCI, PAGES[page]) end
pad.SwipeLeft.EventHandler = function(ctl)
  if ctl.Boolean and page < #PAGES then page = page + 1; show() end
end
pad.SwipeRight.EventHandler = function(ctl)
  if ctl.Boolean and page > 1 then page = page - 1; show() end
end
```

Every mode pulses the swipe pins, so the same script works over an XY Pad or a Zone Select
when a page change by swipe is wanted there.

**Pattern Lock or Keypad to a door strike.** A Text Controller with one Control Pin, a
button named `Door`, wired to the strike relay; `pad.Accepted` for the Keypad, `pad.Unlocked`
for the Pattern Lock:

```lua
local pad = Component.New("Lobby_Keypad")
local timer = Timer.New()
timer.EventHandler = function() timer:Stop(); Controls.Door.Boolean = false end
pad.Accepted.EventHandler = function(ctl)
  if not ctl.Boolean then return end
  Controls.Door.Boolean = true
  timer:Stop(); timer:Start(3)                -- three seconds, restarted by a second event
end
```

Wire `Locked` to an indicator on the UCI so the lockout is visible, and `Rejected` to a
counter if you want to log attempts.

**Zone Select to mutes.** Wire each `Zone Selected n` to a Logic > NOT block and the NOT to
the mute pin of the zone's gain or mixer input: selected means unmuted. Add `Select All` and
`Clear All` to two UCI buttons for an all-on, all-off pair. With Exclusive on, the same
wiring makes a one-zone-at-a-time page selector.

## What has been tested, honestly

- The plugin was **built and tested only in an offline test harness** that fakes the Q-SYS
  runtime in Python and Lua 5.3 (`tools/touchpad/harness`). At the time of writing that is
  **541 scenario tests** (`python3 tools/touchpad/harness/run_tests.py`: the layout lint of
  every page of every mode for 47 property variants, the harness's own checks, the engine,
  the camera drivers, the extremes and every one of the sixteen modes) and **101 unit tests
  with 38964 assertions** (`python3 tools/touchpad/harness/lua_unit.py --all`: the
  utilities, the font metrics, the SVG canvas, the shared shapes and the design-time
  framework, including a check that every control of every mode carries a description).
  `python3 tools/touchpad/build.py` runs the smoke test (GetProperties, GetPages,
  GetControls and GetControlLayout for every page of every mode and property variant) and
  the ASCII and local-slot lints on every build. Every test enforces the budgets of 120000 VM
  instructions per handler and 60000 per frame.
- Per mode, the scenario tests are: XY Pad 8, Swipe Layer 24, Joystick 22, PTZ Pad 21,
  Camera Framing 25, Dial 28, Knob 24, Fader 25, Panner 18, Zone Select 32, Drag & Drop 32,
  Matrix 25, Pattern Lock 25, Keypad 26, Sign-In 30, Whiteboard 18; plus engine 99, camera
  drivers 25, harness 26 and extremes 8.
- **What only the harness has exercised**, with a fake standing in for Q-SYS:
  - the Color Picker binding (a fake `Component.New` with `saturation` and `value` controls
    and a fake `Component.GetControls` list), and every finger path: taps, double taps, long
    presses, drags, swipes, resumed and inferred lifts, parked fingers and stuck Panel Touch;
  - the Display icon: the SVG is written to a fake Legend (or Style) and checked for its
    size and ASCII content, but no panel has rendered it;
  - timers (`Timer.New`, `Timer.CallAfter`) on a virtual clock, so every timing figure in
    this guide (0.6 s swipes, 8 s put-down, 5 min edit timeout, midnight reset) was checked
    against the fake clock, not a Core's;
  - the Q-SYS Camera driver against a fake camera component with the candidate control
    names, and the VISCA over IP driver against fake UDP and TCP sockets (`UdpSocket`,
    `TcpSocket`) that record what was sent and inject the replies the tests choose;
  - the Demo camera entirely (it is a simulation);
  - Sign-In and Whiteboard file writes (`dir`, `io`) into a sandbox folder, the CSV log,
    the BOM and the formula-safe cells; and the webhook posts (`HttpClient.Upload`) against a
    fake that records the request and answers with the status and latency the test sets;
  - the first-start writing of the toggle defaults and `SetupVersion`, and the Outputs page
    layout of arrays up to 64 x 64, through the design-time functions only;
  - `Design`, `System.IsEmulating` and the Core's file paths (`design/` in Emulate, `media/`
    on a Core) as the fake defines them.
- It has **never been opened in Q-SYS Designer** and **never run on a Core or a touch
  panel**. Everything about Designer and panels in this guide comes from QSC's documentation
  and from the Gesture Pad project's published notes on the same technique.
- The **Color Picker's script control names and axis orientation are inferred**, not
  confirmed. At bind time the plugin lists the picker's controls and picks the first name
  containing `saturation` (else `sat`, else exactly `hsv.s` or `hsv_s`) as the horizontal
  axis and the first containing `value` but not `hue` (else `val`, else `bright`, else
  exactly `hsv.v` or `hsv_v`) as the vertical one. Without a list it probes, in order,
  `hsv.saturation`, `saturation`, `hsv_saturation`, `Saturation`, `hsv.s`, `hsv_s` for X and
  `hsv.value`, `value`, `hsv_value`, `Value`, `hsv.v`, `hsv_v` for Y. If neither works it
  binds a string control whose name contains `output`, `color` or `hex` and holds a
  `#RRGGBB` value, and reports the coarse binding on Status. If the surface turns out to be
  oriented differently, the **Swap Axes**, **Flip X** and **Flip Y** properties and the
  **Calibrate** tool are the remedies, and Debug Print = All prints the names the plugin
  saw.
- The picker geometry (the square touch area on a panel, the wider rectangle in Designer)
  comes from the Gesture Pad project's measurements, and the three-copies-at-35 % figure
  from its hardware notes.
- The icon mechanism (a JSON legend with `DrawChrome` and `IconData`) follows QSC's own
  examples but has not been seen on a panel from this plugin; **Icon Channel = Style** is the
  alternative if a firmware renders only that variant.
- **Cameras and webhooks were exercised only against fakes**: the Q-SYS Camera control
  names, the VISCA byte tables and the HTTP posts of Sign-In have not met a real camera or
  server. The Router control names in the recipes (`select.n`) and the Mic Mixer's pin names
  are from documentation and from the Mic Mixer's source, not from a design that was run.

If you try it, please report the Q-SYS version, the panel model, what Status said, and
whether drags feel smooth.

## Credits

Touch Pad is by Nikita Visual Arts (nikitavisual.art). The technique, a native Color Picker
read from a script and a drawing set as the icon of a disabled button, follows the approach
documented by the open Gesture Pad project by Timothy McKinney; this plugin is a separate
implementation written from that project's public documentation. Q-SYS is a trademark of
QSC, LLC. Touch Pad is not made or endorsed by QSC.

## Changelog

### 1.0.1 (2026-10-10)

- Text measurement: non-ASCII text (Cyrillic, Greek, Hebrew, CJK, emoji) is measured and
  fitted several times faster, a fit walks only the characters that can fit, and names and
  labels in those scripts no longer threaten the per-frame budget: Zone Select, Matrix and
  Drag & Drop spread cold tile and header renders over frames by an estimate of each label's
  cost, Sign-In fits one header line per frame, Knob and Fader cut the Units text to 24
  characters.
- Outputs pages: arrays longer than 16 are paged 512 mini cells per page (`Outputs 2`, ...),
  built without per-cell lookups, so a 64 x 64 Matrix lays out cheaply in Designer.
- Display button: Margin, Padding and StrokeWidth are 0 and the stroke white, so the drawing
  maps onto the control's pixels exactly.
- First start: the toggles declared on by default are written on once and `SetupVersion`
  (About page) records it, in case Designer does not apply a boolean default to a button.
- Background = Panel is an 80 % panel, as specified; the Display page says so.
- Joystick: a Home pin held longer than half a second homes once, on its rising edge.
- Camera: releasing one Zoom pin while the other is held keeps zooming the held way; a VISCA
  camera that never answers position inquiries is reported even when polled faster than the
  inquiry timeout (the Dial, a held Zoom).
- Matrix: a Cross pin event that changes nothing no longer re-routes the column.
- Sign-In: Clear, Submit and the idle clear write the field pins back even when they held
  only whitespace.
- Knob: the Min / Max labels follow the Font property.
- Build: the main chunk's free local-variable slots are checked (margin 24 of Lua's 200);
  every module keeps its locals in a `do ... end` block.
- Every control of every mode carries a one-sentence Description, shown by Designer and
  printed in the What-it-does column of `PINS.md`; a unit test keeps it that way.
- Guide: a chapter per mode, the recipes, and the test status with the final counts.

### 1.0.0 (2026-10-10)

- First release: one block, sixteen modes (XY Pad, Swipe Layer, Joystick, PTZ Pad, Camera
  Framing, Dial, Knob, Fader, Panner, Zone Select, Drag & Drop, Matrix, Pattern Lock, Keypad,
  Sign-In, Whiteboard), common gesture pins in every mode, four themes plus Custom, a lock
  pin, Touch Activity support, a two-tap calibration tool, Demo, Q-SYS Camera and VISCA over
  IP camera drivers, and an offline test harness.

---
Nikita Visual Arts – nikitavisual.art
