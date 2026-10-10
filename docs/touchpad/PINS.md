<!-- Nikita Visual Arts – nikitavisual.art -->
# Touch Pad for Q-SYS: pins and controls

Nikita Visual Arts – nikitavisual.art

Built from `plugins/NikitaTouchPad.qplug` by `tools/touchpad/gen_pins.py` (plugin version 1.0.1). Do not edit by hand: run the script again after a change to the plugin.

## How to read this

- **Pin** is the name Designer shows under the block's **Control Pins** list, grouped by the part before the tilde (`Setup ~ Lock` sits in the *Setup* folder). Tick a pin there to expose it on the block and wire it. `none` means the control has no pin and is reached on the block's pages or from Lua.
- **Lua name** is the control's name for scripts. Set the Touch Pad block's **Script Access** property to **Script** or **All**, give it a **Code Name**, and then in a Text Controller or another plugin:

  ```lua
  local pad = Component.New("Lobby_Pad")     -- the block's Code Name
  print(pad.X.Value, pad.Y.Value)             -- a knob: .Value, .Position, .String
  pad.Lock.Boolean = true                     -- a toggle: .Boolean
  pad.Tap.EventHandler = function(ctl)        -- a trigger: fires on every pulse
    print("tapped")
  end
  local route = pad["Route 2"]                -- an array control: "Name n" with a space
  ```

  A control marked `Name n` is an array: its members are `Name 1`, `Name 2` and so on, and the count comes from the block's properties (Zones, Sources, Destinations, Speakers).
- **Type** is the control type with its button or indicator kind, the unit and the range; `x8` after it means an array of eight.
- **Dir** is the pin direction: `in` is driven from outside, `out` is written by the pad, `both` is written by the pad and can also be driven from outside.
- **What it does** comes from the control's own description in the plugin source; a blank cell means the mode has not written one yet. The user guide (`GUIDE.md`) describes every mode in prose.

Every mode carries the same common set (Setup, Live and Actions pins) first; the mode's own controls follow. Camera modes (Joystick, PTZ Pad, Camera Framing, Dial) are listed with **Camera Control = Demo (simulated)** so the camera controls appear; with *None* those rows are absent, *VISCA over IP* adds **Camera ~ Camera IP** and drops the Camera View display.

## Modes

- [XY Pad](#xy-pad): 27 controls, 23 with pins
- [Swipe Layer](#swipe-layer): 28 controls, 24 with pins
- [Joystick](#joystick): 46 controls, 41 with pins
- [PTZ Pad](#ptz-pad): 47 controls, 42 with pins
- [Camera Framing](#camera-framing): 44 controls, 39 with pins
- [Dial](#dial): 40 controls, 35 with pins
- [Knob](#knob): 33 controls, 29 with pins
- [Fader](#fader): 36 controls, 32 with pins
- [Panner](#panner): 32 controls, 28 with pins
- [Zone Select](#zone-select): 37 controls, 33 with pins
- [Drag & Drop](#drag--drop): 36 controls, 32 with pins
- [Matrix](#matrix): 33 controls, 29 with pins
- [Pattern Lock](#pattern-lock): 38 controls, 34 with pins
- [Keypad](#keypad): 37 controls, 33 with pins
- [Sign-In](#sign-in): 40 controls, 36 with pins
- [Whiteboard](#whiteboard): 35 controls, 31 with pins

## XY Pad

Block name: `Touch Pad: XY Pad 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |

## Swipe Layer

Block name: `Touch Pad: Swipe Layer 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Setup ~ Swipe Distance | `SwipeDistance` | Knob Float 0.05..0.8 (default 0.2) | in | Fraction of the pad diagonal a swipe must cover. |

## Joystick

Block name: `Touch Pad: Joystick 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in | Hold to zoom the camera in. |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in | Hold to zoom the camera out. |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in | The fastest pan and tilt speed sent to the camera, in percent. |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in | The zoom speed sent to the camera, in percent. |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out | The camera driver's status text. |
| none | `CameraView` | Button Momentary |  | The Demo camera's view; copy it onto the UCI like the pad's Display. |
| Joystick ~ Joy X | `JoyX` | Knob Float -1..1 (default 0) | out | The stick's horizontal position, -1 left to 1 right. |
| Joystick ~ Joy Y | `JoyY` | Knob Float -1..1 (default 0) | out | The stick's vertical position, -1 down to 1 up. |
| Joystick ~ Magnitude | `Magnitude` | Knob Float 0..1 (default 0) | out | How far the stick is from the centre, 0 to 1. |
| Joystick ~ Dir Left | `DirLeft` | Indicator Led | out | On while the stick points left. |
| Joystick ~ Dir Right | `DirRight` | Indicator Led | out | On while the stick points right. |
| Joystick ~ Dir Up | `DirUp` | Indicator Led | out | On while the stick points up. |
| Joystick ~ Dir Down | `DirDown` | Indicator Led | out | On while the stick points down. |
| Joystick ~ Deadzone | `Deadzone` | Knob Float 0..0.5 (default 0.08) | in | Radius around the centre that outputs zero. |
| Joystick ~ Curve | `Curve` | Text (default Linear) | in | Response curve of the stick: Linear, Squared or Cubed. |
| Joystick ~ Sticky | `Sticky` | Button Toggle | in | On: the stick stays where it is left; off: it springs back on release. |
| Joystick ~ Home | `Home` | Button Trigger | both | Re-centres the stick and sends the camera home; pulses when the pad does it. |
| Joystick ~ Invert Pan | `InvertPan` | Button Toggle | both | Mirrors the horizontal axis. |
| Joystick ~ Invert Tilt | `InvertTilt` | Button Toggle | both | Mirrors the vertical axis. |

## PTZ Pad

Block name: `Touch Pad: PTZ Pad 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in | Hold to zoom the camera in. |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in | Hold to zoom the camera out. |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in | The fastest pan and tilt speed sent to the camera, in percent. |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in | The zoom speed sent to the camera, in percent. |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out | The camera driver's status text. |
| none | `CameraView` | Button Momentary |  | The Demo camera's view; copy it onto the UCI like the pad's Display. |
| PTZ Pad ~ Pan | `Pan` | Knob Float 0..1 (default 0.5) | out | Absolute pan aim, 0 to 1; 0.5 is home. |
| PTZ Pad ~ Tilt | `Tilt` | Knob Float 0..1 (default 0.5) | out | Absolute tilt aim, 0 to 1; 0.5 is home. |
| PTZ Pad ~ Pan Speed | `PanSpeed` | Knob Float -1..1 (default 0) | out | Pan speed while dragging, -1 to 1. |
| PTZ Pad ~ Tilt Speed | `TiltSpeed` | Knob Float -1..1 (default 0) | out | Tilt speed while dragging, -1 to 1. |
| PTZ Pad ~ Dir Left | `DirLeft` | Indicator Led | out | On while the aim moves left. |
| PTZ Pad ~ Dir Right | `DirRight` | Indicator Led | out | On while the aim moves right. |
| PTZ Pad ~ Dir Up | `DirUp` | Indicator Led | out | On while the aim moves up. |
| PTZ Pad ~ Dir Down | `DirDown` | Indicator Led | out | On while the aim moves down. |
| PTZ Pad ~ Sensitivity | `Sensitivity` | Knob Float 0.2..3 (default 1) | in | How far the aim moves for a given drag. |
| PTZ Pad ~ Home | `Home` | Button Trigger | both | Sends the aim and the camera home; pulses when the pad does it. |
| PTZ Pad ~ Invert Pan | `InvertPan` | Button Toggle | both | Mirrors the pan direction. |
| PTZ Pad ~ Invert Tilt | `InvertTilt` | Button Toggle | both | Mirrors the tilt direction. |
| Camera ~ HFOV | `HFOV` | Knob Float 20..120 (default 60) | in | The camera's horizontal field of view in degrees; sizes the view box. |
| Camera ~ Optical Zoom | `OpticalZoom` | Knob Float 1..40 (default 12) | in | The camera's maximum optical zoom factor. |

## Camera Framing

Block name: `Touch Pad: Camera Framing 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in | Hold to zoom the camera in. |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in | Hold to zoom the camera out. |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in | The fastest pan and tilt speed sent to the camera, in percent. |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in | The zoom speed sent to the camera, in percent. |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out | The camera driver's status text. |
| none | `CameraView` | Button Momentary |  | The Demo camera's view; copy it onto the UCI like the pad's Display. |
| Camera Framing ~ Frame Pan | `FramePan` | Knob Float 0..1 (default 0.5) | out | Horizontal centre of the applied frame within the home view, 0 to 1. |
| Camera Framing ~ Frame Tilt | `FrameTilt` | Knob Float 0..1 (default 0.5) | out | Vertical centre of the applied frame within the home view, 0 to 1. |
| Camera Framing ~ Frame Zoom | `FrameZoom` | Knob Float 0..1 (default 0) | out | Tightness of the applied frame: 0 is the whole view, 1 the tightest. |
| Camera Framing ~ Apply | `Apply` | Button Trigger | both | Pulses when a shot is sent to the camera; pulse it to apply the current box. |
| Camera Framing ~ Reset | `Reset` | Button Trigger | both | Zooms all the way out; pulses when the pad does it. |
| Camera Framing ~ Home | `Home` | Button Trigger | both | Zooms out and sends the camera home; pulses when the pad does it. |
| Camera Framing ~ Min Frame | `MinFrame` | Knob Float 0.1..0.6 (default 0.25) | in | The smallest frame as a fraction of the home view. |
| Camera Framing ~ Invert Pan | `InvertPan` | Button Toggle | both | Mirrors the pan direction of the outputs and the camera. |
| Camera Framing ~ Invert Tilt | `InvertTilt` | Button Toggle | both | Mirrors the tilt direction of the outputs and the camera. |
| Camera ~ HFOV | `HFOV` | Knob Float 20..120 (default 60) | in | The camera's horizontal field of view in degrees. |
| Camera ~ Optical Zoom | `OpticalZoom` | Knob Float 1..40 (default 12) | in | The camera's maximum optical zoom factor. |

## Dial

Block name: `Touch Pad: Dial 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in | Hold to zoom the camera in. |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in | Hold to zoom the camera out. |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in | The fastest pan and tilt speed sent to the camera, in percent. |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in | The zoom speed sent to the camera, in percent. |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out | The camera driver's status text. |
| none | `CameraView` | Button Momentary |  | The Demo camera's view; copy it onto the UCI like the pad's Display. |
| Dial ~ Dial Value | `DialValue` | Knob Float 0..1 (default 0) | both | The dial's level, 0 to 1; clockwise raises it. |
| Dial ~ Step Up | `StepUp` | Button Trigger | out | Pulses once per detent turned clockwise. |
| Dial ~ Step Down | `StepDown` | Button Trigger | out | Pulses once per detent turned anticlockwise. |
| Dial ~ Turns | `Turns` | Knob Float 0.5..10 (default 2) | in | How many full turns cover the whole range. |
| Dial ~ Detents | `Detents` | Knob Integer 0..72 (default 24) | in | Notches per turn; 0 for none. |
| Dial ~ Dial Target | `DialTarget` | Text | in | A control driven directly, as CodeName~control. |
| Camera ~ Optical Zoom | `OpticalZoom` | Knob Float 1..40 (default 12) | in | The camera's maximum optical zoom factor; sizes the zoom readout. |

## Knob

Block name: `Touch Pad: Knob 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Knob ~ Knob Min | `KnobMin` | Knob Float -1000..1000 (default 0) | in | The value shown at the bottom of the sweep. |
| Knob ~ Knob Max | `KnobMax` | Knob Float -1000..1000 (default 100) | in | The value shown at the top of the sweep. |
| Knob ~ Units | `Units` | Text | in | The unit text shown after the value. |
| Knob ~ Knob Value | `KnobValue` | Knob Float -1000..1000 (default 0) | both | The knob's value in display units. |
| Knob ~ Knob Position | `KnobPosition` | Knob Float 0..1 (default 0) | both | The knob's position, 0 to 1. |
| Knob ~ Dial Target | `DialTarget` | Text | in | A control driven directly, as CodeName~control. |

## Fader

Block name: `Touch Pad: Fader 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Fader ~ Fader Min | `FaderMin` | Knob Float -1000..1000 (default -100) | in | The value at the bottom of the fader. |
| Fader ~ Fader Max | `FaderMax` | Knob Float -1000..1000 (default 10) | in | The value at the top of the fader. |
| Fader ~ Units | `Units` | Text (default dB) | in | The unit text shown after the value. |
| Fader ~ Fader Value | `FaderValue` | Knob Float -1000..1000 (default -100) | both | The fader's value in display units. |
| Fader ~ Fader Position | `FaderPosition` | Knob Float 0..1 (default 0) | both | The fader's position, 0 to 1. |
| Fader ~ Grab Mode | `GrabMode` | Text (default Jump) | in | Jump sets the value where you touch; Relative moves it from where it was. |
| Fader ~ Taper | `Taper` | Text (default Linear) | in | Linear or Audio; Audio puts 0 dB at 75 percent of the travel for a -100..10 range. |
| Fader ~ Snap Center | `SnapCenter` | Button Toggle | in | Snaps to the centre value within 3 percent of the travel. |
| Fader ~ Dial Target | `DialTarget` | Text | in | A control driven directly, as CodeName~control. |

## Panner

Block name: `Touch Pad: Panner 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Panner ~ Pan X | `PanX` | Knob Float -1..1 (default 0) | both | The source's left-right position, -1 to 1. |
| Panner ~ Pan Y | `PanY` | Knob Float -1..1 (default 0) | both | The source's back-front position, -1 to 1. |
| Panner ~ Pan | `Pan` | Knob Float -1..1 (default 0) | both | A stereo pan for a pan control such as the Mic Mixer's MicPan, -1 to 1. |
| Panner ~ Speaker Gain n | `SpeakerGain n` | Knob dB -80..0 (default 0), x2 | out | The gain of each speaker in dB from a constant-power law. |
| Panner ~ Divergence | `Divergence` | Knob Float 0..1 (default 0.5) | in | How widely the source spreads over the speakers, 0 to 1. |

## Zone Select

Block name: `Touch Pad: Zone Select 500x500`. Pages: Pad, Setup, Names, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Zones ~ Zone Name n | `ZoneName n` | Text, x8 | in | The name drawn on each zone. |
| Zones ~ Zone Selected n | `ZoneSelected n` | Button Toggle, x8 | both | Whether each zone is selected. |
| Zones ~ Select All | `SelectAll` | Button Trigger | in | Selects every zone. |
| Zones ~ Clear All | `ClearAll` | Button Trigger | in | Clears every zone. |
| Zones ~ Selected List | `SelectedList` | Text | out | The selected zone numbers, comma separated. |
| Zones ~ Edit | `Edit` | Button Toggle | in | On: drag zones to move or resize them and redraw the last touched one. |
| Zones ~ Show Background | `ShowBackground` | Button Toggle (default True) | in | Draws the pad background behind the zones. |
| Zones ~ Zone Layout | `ZoneLayout` | Text | both | The zone rectangles as a JSON list of {x,y,w,h} in 0..1 pad units. |
| Zones ~ Exclusive | `Exclusive` | Button Toggle | in | On: one zone at a time, like a radio group. |
| Zones ~ Columns | `Columns` | Knob Integer 1..8 (default 4) | in | Columns of the default grid when Zone Layout is blank. |

## Drag & Drop

Block name: `Touch Pad: Drag & Drop 500x500`. Pages: Pad, Setup, Names, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Sources ~ Source Name n | `SourceName n` | Text, x4 | in | The name drawn on each source tile. |
| Sources ~ Source Active n | `SourceActive n` | Button Toggle (default True), x4 | in | Signal present on each source; off dims the tile. |
| Routing ~ Dest Name n | `DestName n` | Text, x2 | in | The name drawn on each destination tile. |
| Routing ~ Route n | `Route n` | Knob Integer 0..4 (default 0), x2 | both | The source number routed to each destination; 0 is none. |
| Routing ~ Routed n | `Routed n` | Button Trigger, x2 | out | Pulses when each destination's route changes. |
| Routing ~ Route Name n | `RouteName n` | Text, x2 | out | The name of the source routed to each destination. |
| Routing ~ Clear Routes | `ClearRoutes` | Button Trigger | in | Clears every route. |
| Routing ~ Tap Only | `TapOnly` | Button Toggle | in | On: no drags; tap a source and then a screen. |
| Routing ~ Allow Calls | `AllowCalls` | Button Toggle (default True) | in | On: a double tap on a source skips screens whose name holds a call word. |

## Matrix

Block name: `Touch Pad: Matrix 500x500`. Pages: Pad, Setup, Names, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Sources ~ Source Name n | `SourceName n` | Text, x4 | in | The name of each row. |
| Routing ~ Dest Name n | `DestName n` | Text, x2 | in | The name of each column. |
| Matrix ~ Cross n | `Cross n` | Button Toggle, x8 | both | Each crosspoint; the index is (row - 1) * columns + column. |
| Routing ~ Route n | `Route n` | Knob Integer 0..4 (default 0), x2 | both | The source number routed to each column; 0 is none. |
| Routing ~ Exclusive Columns | `ExclusiveColumns` | Button Toggle (default True) | in | On: a column carries one source at a time. |
| Routing ~ Clear All | `ClearAll` | Button Trigger | in | Clears every crosspoint. |

## Pattern Lock

Block name: `Touch Pad: Pattern Lock 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Pattern Lock ~ Grid Size | `GridSize` | Knob Integer 3..5 (default 3) | in | Dots per side of the grid, 3 to 5. |
| Pattern Lock ~ Pattern | `Pattern` | Text | in | The secret as digits, 1-5-9-6 or 1596, numbered left to right, top to bottom. |
| Pattern Lock ~ Unlocked | `Unlocked` | Button Trigger | out | Pulses when the drawn pattern matches. |
| Pattern Lock ~ Failed | `Failed` | Button Trigger | out | Pulses when the drawn pattern does not match. |
| Pattern Lock ~ Locked | `Locked` | Button Toggle | both | On after Max Tries failures for Lockout Seconds; off clears the lockout. |
| Pattern Lock ~ Max Tries | `MaxTries` | Knob Integer 1..10 (default 5) | in | Failures allowed before the lockout. |
| Pattern Lock ~ Lockout Seconds | `LockoutSeconds` | Knob Integer 10..3600 (default 60) | in | How long the lockout lasts. |
| Pattern Lock ~ Last Pattern | `LastPattern` | Indicator Text | out | The pattern just drawn. |
| Pattern Lock ~ Learn | `Learn` | Button Toggle | in | On: the next drawn pattern is stored as the secret. |
| Pattern Lock ~ Masked | `Masked` | Button Toggle | in | Hides the trail; a row of small dots counts the joined dots instead. |
| Pattern Lock ~ Auto Submit | `AutoSubmit` | Button Toggle | in | Checks as soon as the drawn pattern is as long as the secret. |

## Keypad

Block name: `Touch Pad: Keypad 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Keypad ~ Pin | `Pin` | Text (default 1234) | in | The accepted code or codes, separated by commas. |
| Keypad ~ Entry | `Entry` | Text | out | The digits entered so far. |
| Keypad ~ Masked | `Masked` | Button Toggle (default True) | in | Shows dots instead of digits on the pad. |
| Keypad ~ Auto Submit | `AutoSubmit` | Button Toggle (default True) | in | Submits as soon as the entry is as long as a code. |
| Keypad ~ Learn | `Learn` | Button Toggle | in | On: the next code entered and confirmed with Enter is stored as the Pin. |
| Keypad ~ Accepted | `Accepted` | Button Trigger | out | Pulses when an entered code is accepted. |
| Keypad ~ Rejected | `Rejected` | Button Trigger | out | Pulses when an entered code is rejected. |
| Keypad ~ Locked | `Locked` | Button Toggle | both | On after Max Tries failures for Lockout Seconds; off clears the lockout. |
| Keypad ~ Max Tries | `MaxTries` | Knob Integer 1..10 (default 5) | in | Failures allowed before the lockout. |
| Keypad ~ Lockout Seconds | `LockoutSeconds` | Knob Integer 10..3600 (default 60) | in | How long the lockout lasts. |

## Sign-In

Block name: `Touch Pad: Sign-In 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Guest ~ Guest Name | `GuestName` | Text | both | The guest's name. |
| Guest ~ Guest Company | `GuestCompany` | Text | both | The guest's company. |
| Guest ~ Visiting | `Visiting` | Text | both | Who the guest is visiting. |
| Sign-In ~ Submit | `Submit` | Button Trigger | in | Signs the guest in: saves the signature and the log line. |
| Sign-In ~ Clear | `Clear` | Button Trigger | in | Clears the form and the signature. |
| Sign-In ~ Clear Signature | `ClearSignature` | Button Trigger | in | Clears the signature only. |
| Sign-In ~ Submitted | `Submitted` | Button Trigger | out | Pulses after a successful sign-in. |
| Sign-In ~ Last Guest | `LastGuest` | Text | out | The name of the last guest signed in. |
| Sign-In ~ Today Count | `TodayCount` | Text | out | How many guests signed in today. |
| Sign-In ~ Room Name | `RoomName` | Text | in | The room name written to the log and the webhook. |
| Sign-In ~ Webhook Url | `WebhookUrl` | Text | in | Where each sign-in is posted when the Sign-In Webhook property is on. |
| Sign-In ~ Send Status | `SendStatus` | Text | out | The result of the last webhook post. |
| Sign-In ~ Pen Width | `PenWidth` | Knob Float 1..8 (default 3) | in | The signature pen width in pixels. |

## Whiteboard

Block name: `Touch Pad: Whiteboard 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out | The plugin's status: OK while bound to the picker, otherwise the problem. |
| none | `Display` | Button Momentary |  | The pad drawing; copy it from the Display page onto the UCI. Disabled at run time so touches pass through. |
| Setup ~ Picker | `Picker` | Text | in | Code Name of the Color Picker to read; blank uses the Color Picker property. |
| Setup ~ Refresh | `Refresh` | Button Trigger | in | Re-scans the design for the picker and rebinds. |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in | Wire the touch panel's Touch Activity here for exact press and release. |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in | Two-tap calibration tool: on shows two targets to tap in turn, off cancels. |
| none | `Calibration` | Text |  | Calibration lines, P x0 y0 w h for panels and D x0 y0 w h for Designer; editable. |
| none | `PickerLayout` | Indicator Text |  | The computed picker size and placement for the current pad size. |
| none | `SetupVersion` | Indicator Text |  | Records that the first-start defaults of the toggles were written once. |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in | Silence counted as a lift when Panel Touch is not wired. |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in | How long a still finger must rest for a long press. |
| Setup ~ Lock | `Lock` | Button Toggle | in | On: touches are ignored and the pad draws dimmed with a lock icon. |
| Live ~ Touching | `Touching` | Indicator Led | out | On while a finger is on the pad. |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out | Live finger position from left (0) to right (1). |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out | Live finger position from bottom (0) to top (1). |
| Actions ~ Tap | `Tap` | Button Trigger | both | Pulses on a tap. |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both | Pulses on a double tap. |
| Actions ~ Long Press | `LongPress` | Button Trigger | both | Pulses when a finger rests still for Long Press Time. |
| Actions ~ Press | `Press` | Button Trigger | out | Pulses on touch down. |
| Actions ~ Release | `Release` | Button Trigger | out | Pulses on a confirmed lift. |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both | Pulses on a swipe to the left; every mode, not only Swipe Layer. |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both | Pulses on a swipe to the right; every mode, not only Swipe Layer. |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both | Pulses on a swipe upwards; every mode, not only Swipe Layer. |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both | Pulses on a swipe downwards; every mode, not only Swipe Layer. |
| Live ~ Gesture | `Gesture` | Indicator Text | out | The last gesture or the hint text, in upper case. |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out | Normalised distance of the current or last drag; the pad diagonal is 1. |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out | Degrees of the current or last drag; 0 is right, 90 is up. |
| Whiteboard ~ Pen Width | `PenWidth` | Knob Float 1..8 (default 3) | in | The pen width in pixels. |
| Whiteboard ~ Pen Color | `PenColor` | Text (default Accent) | in | The pen colour: Accent, White, Black, Red, Green or Blue. |
| Whiteboard ~ Eraser | `Eraser` | Button Toggle | in | On: the finger removes every stroke it crosses. |
| Whiteboard ~ Undo | `Undo` | Button Trigger | in | Removes the last stroke. |
| Whiteboard ~ Clear Board | `ClearBoard` | Button Trigger | in | Empties the board. |
| Whiteboard ~ Snapshot | `Snapshot` | Button Trigger | in | Writes the board as an SVG file and names it on Last File. |
| Whiteboard ~ Strokes | `Strokes` | Indicator Text | out | How many strokes are on the board. |
| Whiteboard ~ Last File | `LastFile` | Text | out | The file written by the last snapshot. |

---
Nikita Visual Arts – nikitavisual.art
