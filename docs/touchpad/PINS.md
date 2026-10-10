<!-- Nikita Visual Arts – nikitavisual.art -->
# Touch Pad for Q-SYS: pins and controls

Nikita Visual Arts – nikitavisual.art

Built from `plugins/NikitaTouchPad.qplug` by `tools/touchpad/gen_pins.py` (plugin version 1.0.0). Do not edit by hand: run the script again after a change to the plugin.

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

- [XY Pad](#xy-pad): 26 controls, 23 with pins
- [Swipe Layer](#swipe-layer): 26 controls, 23 with pins
- [Joystick](#joystick): 32 controls, 28 with pins
- [PTZ Pad](#ptz-pad): 32 controls, 28 with pins
- [Camera Framing](#camera-framing): 32 controls, 28 with pins
- [Dial](#dial): 32 controls, 28 with pins
- [Knob](#knob): 26 controls, 23 with pins
- [Fader](#fader): 26 controls, 23 with pins
- [Panner](#panner): 26 controls, 23 with pins
- [Zone Select](#zone-select): 26 controls, 23 with pins
- [Drag & Drop](#drag--drop): 26 controls, 23 with pins
- [Matrix](#matrix): 26 controls, 23 with pins
- [Pattern Lock](#pattern-lock): 26 controls, 23 with pins
- [Keypad](#keypad): 26 controls, 23 with pins
- [Sign-In](#sign-in): 26 controls, 23 with pins
- [Whiteboard](#whiteboard): 26 controls, 23 with pins

## XY Pad

Block name: `Touch Pad: XY Pad 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Swipe Layer

Block name: `Touch Pad: Swipe Layer 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Joystick

Block name: `Touch Pad: Joystick 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in |  |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in |  |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out |  |
| none | `CameraView` | Button Momentary |  |  |

## PTZ Pad

Block name: `Touch Pad: PTZ Pad 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in |  |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in |  |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out |  |
| none | `CameraView` | Button Momentary |  |  |

## Camera Framing

Block name: `Touch Pad: Camera Framing 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in |  |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in |  |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out |  |
| none | `CameraView` | Button Momentary |  |  |

## Dial

Block name: `Touch Pad: Dial 500x500`. Pages: Pad, Setup, Camera View, Outputs, Display, About. Listed with Camera Control = Demo (simulated).

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |
| Camera ~ Zoom In | `ZoomIn` | Button Momentary | in |  |
| Camera ~ Zoom Out | `ZoomOut` | Button Momentary | in |  |
| Camera ~ Max Speed | `MaxSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Zoom Speed | `ZoomSpeed` | Knob Percent 1..100 (default 50) | in |  |
| Camera ~ Camera Status | `CameraStatus` | Indicator Text | out |  |
| none | `CameraView` | Button Momentary |  |  |

## Knob

Block name: `Touch Pad: Knob 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Fader

Block name: `Touch Pad: Fader 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Panner

Block name: `Touch Pad: Panner 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Zone Select

Block name: `Touch Pad: Zone Select 500x500`. Pages: Pad, Setup, Names, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Drag & Drop

Block name: `Touch Pad: Drag & Drop 500x500`. Pages: Pad, Setup, Names, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Matrix

Block name: `Touch Pad: Matrix 500x500`. Pages: Pad, Setup, Names, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Pattern Lock

Block name: `Touch Pad: Pattern Lock 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Keypad

Block name: `Touch Pad: Keypad 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Sign-In

Block name: `Touch Pad: Sign-In 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

## Whiteboard

Block name: `Touch Pad: Whiteboard 500x500`. Pages: Pad, Setup, Outputs, Display, About.

| Pin | Lua name | Type | Dir | What it does |
|---|---|---|---|---|
| Setup ~ Status | `Status` | Indicator Status | out |  |
| none | `Display` | Button Momentary |  |  |
| Setup ~ Picker | `Picker` | Text | in |  |
| Setup ~ Refresh | `Refresh` | Button Trigger | in |  |
| Setup ~ Panel Touch | `PanelTouch` | Button Toggle | in |  |
| Setup ~ Calibrate | `Calibrate` | Button Toggle | in |  |
| none | `Calibration` | Text |  |  |
| none | `PickerLayout` | Indicator Text |  |  |
| Setup ~ Release Time | `ReleaseTime` | Knob Seconds 0.1..1 (default 0.25) | in |  |
| Setup ~ Long Press Time | `LongPressTime` | Knob Seconds 0.3..3 (default 0.6) | in |  |
| Setup ~ Lock | `Lock` | Button Toggle | in |  |
| Live ~ Touching | `Touching` | Indicator Led | out |  |
| Live ~ X | `X` | Knob Float 0..1 (default 0) | out |  |
| Live ~ Y | `Y` | Knob Float 0..1 (default 0) | out |  |
| Actions ~ Tap | `Tap` | Button Trigger | both |  |
| Actions ~ Double Tap | `DoubleTap` | Button Trigger | both |  |
| Actions ~ Long Press | `LongPress` | Button Trigger | both |  |
| Actions ~ Press | `Press` | Button Trigger | out |  |
| Actions ~ Release | `Release` | Button Trigger | out |  |
| Actions ~ Swipe Left | `SwipeLeft` | Button Trigger | both |  |
| Actions ~ Swipe Right | `SwipeRight` | Button Trigger | both |  |
| Actions ~ Swipe Up | `SwipeUp` | Button Trigger | both |  |
| Actions ~ Swipe Down | `SwipeDown` | Button Trigger | both |  |
| Live ~ Gesture | `Gesture` | Indicator Text | out |  |
| Live ~ Drag Distance | `DragDistance` | Knob Float 0..2 (default 0) | out |  |
| Live ~ Drag Angle | `DragAngle` | Knob Float -180..180 (default 0) | out |  |

---
Nikita Visual Arts – nikitavisual.art
