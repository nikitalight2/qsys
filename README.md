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
| RGBW Fixture Selector | `plugins/NikitaRGBWSelector.qplug` | 1.0.0 |
| NEC NP-PA04UL-B Projector | `plugins/NikitaNECProjector.qplug` | 1.1.0 |

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

## RGBW Fixture Selector

One master Red / Green / Blue / White colour and any number of fixtures
(1 to 64). Every fixture you select follows the master colour; deselected
fixtures ignore it. Each fixture has its own Red, Green, Blue and White
output pins, ready to wire to your lighting or DMX blocks.

### Install

1. Copy `plugins/NikitaRGBWSelector.qplug` to your Q-SYS plugin folder.
2. Restart Q-SYS Designer and drag **Nikita Visual Arts → RGBW Fixture
   Selector** into the schematic.
3. Set the properties, then wire the pins.

### Properties

| Property | Choices | What it does |
|---|---|---|
| Fixture Count | 1 to 64 (default 8) | Number of fixtures, select buttons and output pin groups. |
| Value Range | 0-255 (DMX), 0-100 % | Scale of the master faders and the fixture outputs. |
| Deselected Fixtures | Hold last colour, Go to black | What a fixture does when it is not selected. |

### Pins

| Direction | Pins |
|---|---|
| Input | `Red`, `Green`, `Blue`, `White`, `Select 1` … `Select N` |
| Output | `Fixture 1 Red`, `Fixture 1 Green`, `Fixture 1 Blue`, `Fixture 1 White`, … up to `Fixture N White` |
| Optional input (enable in the control pins list) | `SelectAll`, `SelectNone`, `Preset 1` … `Preset 8` |

With a single fixture the select pin is named `Select`.

### How it behaves

- Moving a master fader updates every selected fixture at once.
- Selecting a fixture makes it take the current master colour straight away.
- Deselecting a fixture keeps its last colour (or sends it to 0 with
  *Go to black*), and later master changes no longer reach it.
- **QUICK COLOURS** set the master faders to Red, Amber, Green, Cyan, Blue,
  Magenta, White or Off. **SELECT ALL** / **SELECT NONE** act on every fixture.
- The bar above the master faders and on each fixture card previews the
  colour (white is shown added to R, G and B). The outputs always carry the
  raw R, G, B, W values.

Q-SYS plugins have no colour-wheel control, so the colour picker is the four
master faders plus the quick colour buttons.

### Not verified on hardware

Checked with an offline mock of the plugin host (all design-time functions
for 1 to 64 fixtures in both ranges, every control placed on the page, pin
counts, and the runtime select / hold / black / preset logic). It was not
loaded in Q-SYS Designer or run on a Core. Points to confirm there:

- the colour preview bars depend on the runtime `.Color` property of LEDs;
  on a Q-SYS version without it they only show on/off;
- the LED style may draw a rounded or circular shape instead of a bar;
- the fixture output faders are set read-only on the page; their pins are
  outputs and are driven only by the plugin.

## Repository layout

```
plugins/NikitaMicMixer.qplug       Mic Mixer plugin
plugins/NikitaRGBWSelector.qplug   RGBW Fixture Selector plugin
assets/brand/                      logo files used by the plugin and this README
```

---
Nikita Visual Arts – nikitavisual.art

## NEC NP-PA04UL-B Projector

Network control of an NEC NP-PA04UL-B projector: power on and off, shutter,
picture mute, zoom, focus and lens shift, with live feedback. When the
projector cannot be reached, the panel says so and asks the user to check
that it is plugged in to power and to the network.

### Install

1. Copy `plugins/NikitaNECProjector.qplug` to your Q-SYS plugin folder.
2. Restart Q-SYS Designer and drag **Nikita Visual Arts → NEC NP-PA04UL-B
   Projector** into the schematic.
3. Enter the projector's IP address in the **IP ADDRESS** box and keep
   **CONNECT** on.

### Projector setup

- Give the projector a fixed IP address (or a DHCP reservation).
- Set **Standby Mode** to **Network Standby** (the name depends on the
  firmware). In the deepest power-saving standby the projector's network
  port is switched off: it cannot be turned on over the network and the
  plugin will show it as *not reachable*.
- The plugin sends commands on TCP port **7142** (NEC control port) and
  reads power, picture mute and errors over **PJLink** (TCP 4352). PJLink
  is on by default on NEC projectors. If a PJLink password is set in the
  projector, enter the same password in the *PJLink Password* property.

### Panel

| Section | Controls |
|---|---|
| Connection | IP address, CONNECT, status, ONLINE LED, user message |
| Power | ON, OFF buttons, LEDs for On / Off / Warm-up / Cool-down / Error, power and error text, SHUTTER, PICTURE MUTE |
| Lens | ZOOM − / +, FOCUS − / +, lens-shift pad ▲ ▼ ◀ ▶, STOP |

Lens buttons are hold-to-move: the lens moves while the button is pressed
and stops when it is released. **STOP** stops every lens motor.

### Properties

| Property | Default | What it does |
|---|---|---|
| Port | 7142 | NEC control port (commands, and the fallback feedback). |
| Power Feedback | PJLink + NEC (recommended) | Where power, picture-mute and error feedback come from. *NEC only* reads the NEC status reply instead. |
| PJLink Port | 4352 | PJLink port. |
| PJLink Password | empty | The projector's PJLink password, if one is set. |
| Poll Interval (s) | 2 | How often the projector state is read. |
| Offline After (s) | 8 | Time without an answer before the projector is shown as not reachable. |
| Message Language | English | Language of the user message and power text (English or Hebrew). |
| Invert Horizontal Shift / Invert Vertical Shift | off | Swap the shift directions, for ceiling mounting or rear projection. |
| Debug | off | Prints every command and reply to the debug output. |

### Pins

| Direction | Pins |
|---|---|
| Input | `PowerOn`, `PowerOff` |
| Input / output | `Shutter`, `PictureMute` |
| Output | `Online`, `Message`, `PowerState`, `OffState` |
| Optional (enable in the control pins list) | `IPAddress`, `Connect`, `Status`, `PowerToggle`, `WarmingUp`, `CoolingDown`, `PowerText`, `ShutterClose`, `ShutterOpen`, `Error`, `ErrorText`, `FeedbackSource`, `ZoomPlus`, `ZoomMinus`, `FocusPlus`, `FocusMinus`, `ShiftUp`, `ShiftDown`, `ShiftLeft`, `ShiftRight`, `LensStop` |

### Offline detection

The projector is shown as **online** while it answers status requests.
If the TCP connection fails, or the projector stops answering for longer
than *Offline After*, the **Status** turns red, **ONLINE** goes off and the
message reads *"Projector not reachable – check it is plugged in to power
and network"* (or the Hebrew text). Wire the `Online` or `Message` pin to a
UCI to show this to the user.

### Power feedback

The **FEEDBACK** line at the bottom of the panel shows where the state
comes from: *PJLink* when PJLink answers, otherwise *NEC status*. With
PJLink the power text reads Off (standby), Warming up, On or Cooling down,
and the matching LED lights. If PJLink stops answering, the plugin falls
back to the NEC status reply.

The raw NEC status bytes are printed to the debug output whenever they
change (`NEC running status: …`). If the state is still wrong, send those
lines, taken once with the projector on and once off.

### What changed in 1.1.0

- Power feedback is read over PJLink, a standard protocol, because the
  power byte in the NEC status reply is not in the same place on every
  NEC model. In 1.0.0 this caused the power state to stay on *Unknown*.
- New **OFF** LED and `OffState` pin; the power text shows *Off (standby)*.
- NEC replies are matched by their command byte, so a late reply can no
  longer be taken for the answer to another command.
- Picture mute and errors are read over PJLink (AVMT and ERST).
- Picture mute and shutter feedback reset when the projector turns off.

### Not verified on hardware

Version 1.0.0 was loaded on a Core and connected to the projector; its power
feedback stayed on *Unknown*, which 1.1.0 fixes. Version 1.1.0 itself was
checked with a Lua 5.3 syntax check and an offline mock of
the plugin host and the projector (NEC and PJLink, including PJLink
password authentication, checked against a reference MD5). It has not yet
been run on the projector. To confirm on site:

- that PJLink is enabled on the projector (Network settings);
- the NEC status-byte layout, only if PJLink is not used;
- which way "+" moves zoom and focus, and which way shift goes on your
  mounting (use the invert properties if needed);
- the shutter state is taken from the projector's answer to the shutter
  command; it is not read back by polling, so a shutter changed from the
  projector's own remote is not shown.

If something does not behave as expected, turn on the *Debug* property and
send the debug output together with the Q-SYS Designer version.
