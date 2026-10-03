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
| Color Picker RGBW | `plugins/NikitaColorPickerRGBW.qplug` | 1.1.0 |

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

## Color Picker RGBW

A basic colour picker for RGBW LED fixtures, built around the vertical hue
strip from the Q-SYS Designer colour picker: a rainbow bar with a fader
beside it, a brightness knob and a white-mix knob. No saturation or value
plane and no 16-million-colour picker. You pick a hue, set how bright it
is and how much of the white emitter to add, and the plugin puts the four
channel values on its output pins.

### Controls

| Control | Type | What it does |
|---|---|---|
| **Hue** | fader, input/output pin | 0 to 360 degrees, bottom to top, matching the strip (red, yellow, green, cyan, blue, magenta, red) |
| **Brightness** | knob, input/output pin | 0 to 100 %, master dimmer for all four channels |
| **WhiteMix** | knob, input/output pin | 0 to 100 %, level of the W emitter on top of the hue |
| **Red**, **Green**, **Blue**, **White** | knob, output pin | one value per emitter channel |
| **RGBW** | text, output pin | all four as one string, e.g. `0,38,255,0` |
| **ColorName** | text, output pin | plain name and angle of the hue, e.g. `Blue  231°` |

The *Output Scale* property sets the range of the four value pins:
`0-255` (default, integers), `0-100` (percent) or `0-1` (floats with three
decimals). The RGBW string follows the same scale.

The hue is converted at full saturation, so R, G and B carry the pure
colour and the W channel is driven only by *WhiteMix*. Brightness 0 is a
blackout on all four channels.

### Install

1. Copy `plugins/NikitaColorPickerRGBW.qplug` to your Q-SYS plugin folder
   (`%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins` on Windows).
2. Restart Q-SYS Designer and drag **Nikita Visual Arts → Color Picker RGBW**
   into the schematic.
3. Wire the **Red / Green / Blue / White** pins (or the **RGBW** string) to
   whatever drives the fixture, for example the percent inputs of an sACN
   Transmit block.

### Not verified on hardware

Checked with a Lua syntax check and an offline mock of the plugin host
(design-time functions, layout bounds, the hue maths at every 30° step,
and the runtime at all three output scales). It was not loaded in Q-SYS
Designer or run on a Core. Two points depend on the Q-SYS build: the
rainbow strip is an embedded PNG drawn next to a standard fader, so the
fader's handle sits beside the strip rather than on it, and the preview
lamp is recoloured from the runtime through the control's `Color`
property.

### Repository layout

```
plugins/NikitaMicMixer.qplug          Mic Mixer
plugins/NikitaColorPickerRGBW.qplug   Color Picker RGBW
assets/brand/                         logo files used by the plugins and this README
```

---
Nikita Visual Arts – nikitavisual.art
