<!-- Nikita Visual Arts – nikitavisual.art -->
<p align="center">
  <img src="../../assets/brand/logo-horizontal.png" alt="Nikita Visual Arts" width="280"><br>
  <strong>Nikita Visual Arts – nikitavisual.art</strong>
</p>

# Touch Pad for Q-SYS: user guide

Version 1.0.0. The plugin is `plugins/NikitaTouchPad.qplug`. The pin reference built from
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
| Background | Solid, Transparent, Panel | Solid | Solid fills the pad with the theme's background color. Transparent draws no pad background or frame, so the page art shows through. Panel fills it with the theme's lighter panel color. |
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
  the cards and tiles), so the whole pad reads as one card. Use the panel color above under
  the copies; in 1.0.0 the Display page still prints the Solid value.
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

### XY Pad

Filled in after the mode's tests pass.

### Swipe Layer

Filled in after the mode's tests pass.

### Joystick

Filled in after the mode's tests pass.

### PTZ Pad

Filled in after the mode's tests pass.

### Camera Framing

Filled in after the mode's tests pass.

### Dial

Filled in after the mode's tests pass.

### Knob

Filled in after the mode's tests pass.

### Fader

Filled in after the mode's tests pass.

### Panner

Filled in after the mode's tests pass.

### Zone Select

Filled in after the mode's tests pass.

### Drag & Drop

Filled in after the mode's tests pass.

### Matrix

Filled in after the mode's tests pass.

### Pattern Lock

Filled in after the mode's tests pass.

### Keypad

Filled in after the mode's tests pass.

### Sign-In

Filled in after the mode's tests pass.

### Whiteboard

Filled in after the mode's tests pass.

## Recipes

Filled in after the mode's tests pass. Planned: a router mapping script for Drag & Drop and
Matrix (QSC routers count inputs from 1), a Swipe Layer that changes UCI pages, a Panner
driving a Mic Mixer's pan, and a Keypad opening a door strike.

## What has been tested, honestly

- The plugin was **built and tested only in an offline test harness** that fakes the Q-SYS
  runtime in Python and Lua 5.3 (`tools/touchpad/harness`). At the time of writing that is
  **108 scenario tests** (`python3 tools/touchpad/harness/run_tests.py`: the layout lint of
  every page of every mode, the harness's own checks, the engine, and the XY Pad mode) and
  **98 unit tests with 1741 assertions** (`python3 tools/touchpad/harness/lua_unit.py --all`:
  the utilities, the font metrics, the SVG canvas, the shared shapes and the design-time
  framework). The mode-level scenario tests cover XY Pad only; the other fifteen modes are
  being written and have no tests yet.
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
  server.

If you try it, please report the Q-SYS version, the panel model, what Status said, and
whether drags feel smooth.

## Credits

Touch Pad is by Nikita Visual Arts (nikitavisual.art). The technique, a native Color Picker
read from a script and a drawing set as the icon of a disabled button, follows the approach
documented by the open Gesture Pad project by Timothy McKinney; this plugin is a separate
implementation written from that project's public documentation. Q-SYS is a trademark of
QSC, LLC. Touch Pad is not made or endorsed by QSC.

## Changelog

### 1.0.0 (2026-10-10)

- First release: one block, sixteen modes (XY Pad, Swipe Layer, Joystick, PTZ Pad, Camera
  Framing, Dial, Knob, Fader, Panner, Zone Select, Drag & Drop, Matrix, Pattern Lock, Keypad,
  Sign-In, Whiteboard), common gesture pins in every mode, four themes plus Custom, a lock
  pin, Touch Activity support, a two-tap calibration tool, Demo, Q-SYS Camera and VISCA over
  IP camera drivers, and an offline test harness.

---
Nikita Visual Arts – nikitavisual.art
