<!-- Nikita Visual Arts – nikitavisual.art -->
<p align="center">
  <img src="assets/brand/logo-horizontal.png" alt="Nikita Visual Arts" width="280"><br>
  <strong>Nikita Visual Arts – nikitavisual.art</strong>
</p>

# Q-SYS plugins

Q-SYS Designer plugins by Nikita Visual Arts.

| Plugin | File | Version |
|---|---|---|
| Mic Mixer | `plugins/NikitaMicMixer.qplug` | 2.0.0 |
| Touch Pad | `plugins/NikitaTouchPad.qplug` | 1.0.0 |

## Mic Mixer

A multi-mic console block for Q-SYS: any number of mics (1 to 16), optional
stereo line inputs, a linked stereo MAIN bus and up to 8 mono monitor mixes.
Every mic has gain, pan, mute, solo, a high-pass filter, a reverb send and a
send knob per monitor. The shared reverb returns on every output through its
own FX RTN knob, and a master limiter protects L/R.

### Install

1. Copy `plugins/NikitaMicMixer.qplug` to your Q-SYS plugin folder
   (`%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins` on Windows).
2. Restart Q-SYS Designer and drag **Nikita Visual Arts → Mic Mixer** into
   the schematic.
3. Set *Mic Count*, *Stereo Input Count* and *Monitor Count* in the
   properties, then wire the audio pins.

### Using the effects

| Effect | Where | How |
|---|---|---|
| Reverb | Setup page **ON**, **DECAY**, **PRE-DELAY** | Turn **ON**, raise the **VERB** knob on a mic, and keep the **FX RTN** knob on an output above the floor (it defaults to 0 dB). |
| High-pass filter | Setup page **HPF** per mic, **CUTOFF** | Press **HPF** on a mic. The cutoff is shared by all mics. Leave **SOURCE** on *Auto*. |
| Limiter | Setup page **ON**, **THRESHOLD** | Acts on L/R only. Monitors are never limited. |

The **EFFECT ENGINES** box on the Setup page shows which embedded engines
loaded on your Q-SYS version. The same text is printed to the debug output
on every start, together with the plugin version.

### What changed in 2.0.0

- Control defaults now use the plugin framework's `DefaultValue` key. Older
  builds used a key Q-SYS ignores, so every knob started at its minimum: the
  main fader at -100 dB, all pans hard left, reverb returns off, reverb decay
  at 0.2 s and the limiter threshold at -24 dB. Designs built with an older
  build are fixed once at start-up: knobs still sitting on that old floor are
  lifted to sensible values, and a hidden marker prevents it from running again.
- Reverb: one engine (the Q-SYS Reverb Effect) instead of three guesses, the
  real control names tried first, and both reverb outputs returned to every
  bus so a mono or stereo engine both reach L and R. The SIZE knob, which the
  engine has no control for, is replaced by PRE-DELAY.
- HPF: the embedded crossover is 2-way by default, so the old "band 3" path
  never existed. The filtered signal is now taken from whichever output
  carries the high band: the low band is muted inside the crossover and all
  its outputs are summed, so the result is correct whatever the pin order. A
  dedicated High-Pass Filter block is declared as well and is preferred when
  the Q-SYS version provides it. **SOURCE** on the Setup page lets you force a
  specific output if Auto ever sounds wrong.
- Layout: buttons declare their style explicitly, panel strokes use the
  correct key, and the header shows the brand name and website.

### Not verified on hardware

This release was checked with a Lua syntax check and an offline mock of the
plugin host (all design-time functions, wiring consistency, and the runtime
logic for every effect, with and without each engine present). It was not
loaded in Q-SYS Designer or run on a Core. In particular these points depend
on the Q-SYS build and should be confirmed in the EFFECT ENGINES box and by
ear:

- the Type string of the dedicated High-Pass Filter block;
- the output-pin names of the embedded crossover;
- the exact Lua control names of the reverb's pre-delay and bypass.

If an engine shows **NOT AVAILABLE**, enable the *Debug* property and send
the debug output together with the Q-SYS Designer version.

### Repository layout

```
plugins/NikitaMicMixer.qplug   the plugin
assets/brand/                  logo files used by the plugin and this README
```

## Touch Pad

Real touch gestures on any Q-SYS UCI with no extra hardware. A native Color
Picker hidden under the page reports where a finger is; the Touch Pad block
reads it, works out the gesture (tap, double tap, long press, drag, swipe)
and draws its own interface on top of the page as a script-set icon. Every
result is a pin: live X and Y, a pulse per gesture, and the outputs of the
mode you pick. One block is one pad; every mode shares the same setup.

Modes: XY Pad, Swipe Layer, Joystick, PTZ Pad, Camera Framing, Dial, Knob,
Fader, Panner, Zone Select, Drag & Drop, Matrix, Pattern Lock, Keypad,
Sign-In and Whiteboard.

### Install

1. Copy `plugins/NikitaTouchPad.qplug` to the same plugin folder as the Mic
   Mixer (`%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins` on Windows).
2. Restart Q-SYS Designer. The block appears under **Plugins > User >
   Custom** as **Nikita Visual Arts > Touch Pad**; drag it into the
   schematic.

### Set up a pad

1. Block: pick the *Mode* and set *Pad Width* and *Pad Height*.
2. Color Picker: add one, set its Script Access to All, and type its Code
   Name into the block's *Color Picker* property.
3. Read the block's Setup page: the picker's size, and where the pad can go.
4. UCI: the picker's color surface at that size and place, sent to the back.
5. A Group Box over the picker, in the page color, 2 px bigger on every side.
6. Where the pad goes: a box in the pad's color, then the Display from the
   block's Display page pasted three times on top.
7. UCI: Swipe Disabled on.
8. Test. On a TSC, tick and wire the panel's Touch Activity to the block's
   Panel Touch.

The user guide, [docs/touchpad/GUIDE.md](docs/touchpad/GUIDE.md), explains
every step, the properties, calibration, Touch Activity, the themes and the
status messages. [docs/touchpad/PINS.md](docs/touchpad/PINS.md) lists every
pin and control of every mode, built from the plugin by
`tools/touchpad/gen_pins.py`.

### Test status

Built and tested only in an offline harness that fakes the Q-SYS runtime
(108 scenario tests and 98 unit tests at the time of writing, with mode-level
tests for XY Pad only); never opened in Q-SYS Designer, never run on a Core
or a touch panel. The Color Picker's control names and axis orientation are
inferred, with Swap Axes, Flip X, Flip Y and the Calibrate tool as the
remedies. See "What has been tested, honestly" in the guide.

### Repository layout

```
plugins/NikitaTouchPad.qplug   the plugin (built from src/touchpad/)
src/touchpad/                  the Lua modules
tools/touchpad/                build.py, gen_pins.py and the offline test harness
docs/touchpad/                 GUIDE.md and PINS.md
```

---
Nikita Visual Arts – nikitavisual.art
