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
| Bettear CASTER | `plugins/BettearCaster.qplug` | 1.0.0 |

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

## Bettear CASTER

<p>
  <img src="assets/brand/bettear-logo.png" alt="Bettear" width="100"><br>
  Bettear – <a href="https://bettear.com">bettear.com</a> ·
  <a href="https://bettear.com/products/caster">CASTER product page</a>
</p>

Control plugin for the Bettear CASTER Auracast streamer. It speaks the
CASTER UDP API (reference v1.03, firmware 1.4.3 and above) and mirrors every
documented field on one panel per unit: broadcast (enable, advertised name,
preset, stereo/dual mono, program info), encryption, audio input (gain, mute,
link, mono mix, AGC, low-pass, per-channel high-pass), RF (TX power, antenna),
LEDs and timecode. Static IP, controller port and ID stay on the unit's own
management page. The plugin is branded with the Bettear word mark and website,
not with mine.

### Install

1. Copy `plugins/BettearCaster.qplug` to your Q-SYS plugin folder
   (`%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins` on Windows).
2. Restart Q-SYS Designer and drag **Bettear → CASTER** into the schematic.
3. Set *Device Count* (one page per unit), *Poll Interval* and, if the Core
   must use a different controller port, *Local UDP Port* (default 9000).
   *Network Interface* stays on **Any** (the socket listens on every Core
   interface) unless the units or the multicast group live on one specific
   network; then pick LAN A, LAN B, AUX A or AUX B.
4. On each device page enter the unit's IP address. Port 9000 and device ID
   255 are filled in automatically; change them if your unit differs.

### How it talks to the unit

| Item | Behaviour |
|---|---|
| Transport | One UDP socket per plugin instance, bound to the controller port (9000). The CASTER answers to the sender's IP on that port, so the Core must own it. A second instance on the same Core cannot bind it: raise *Device Count* instead. |
| Interface | *Network Interface* = Any binds all interfaces. A named interface binds that interface's address (looked up through the Core's network table) and falls back to Any if it is not found; the Setup page shows what was bound. |
| Commands | `Device#<id> <command>` + LF. The panel sends SET when you change a control and GET for every field on each poll; PING keeps the Status LED honest. |
| Status | OK = answering. Compromised = the unit reported REBOOT REQUIRED. Initializing = rebooting. Missing = three polls unanswered. Not Present = no IP set. |
| Multicast | Enter a multicast group as the IP and 0 as the device ID to reach several units; replies are matched by the ID the unit puts in its answer. |
| Knobs | Gain is rounded to the API's 0.5 dB steps (-12 … +32 dB), TX power to 1 %. Both are sent once the knob rests for 150 ms. |
| Errors | `ERR ...` replies are printed to the debug output (turn on the *Debug* property to see all traffic). |

Pins are exposed on the useful controls (IP address, online LED, reboot
required, all broadcast/audio/RF settings, timecode) so a UCI or a script can
drive the unit through the plugin.

### Not verified on hardware

This plugin was checked with a Lua 5.3 syntax check and an offline mock of
the plugin host that includes a simulated CASTER implementing the documented
protocol (every page's layout, control declarations, and the runtime for 1, 2
and 3 devices, including a unit reached over multicast). It was not loaded in
Q-SYS Designer or run on a Core, and it has never spoken to a real CASTER.
Points that depend on that:

- The exact form of `UdpSocket:Open` that binds only a port. The plugin tries
  `Open(nil, port)`, `Open("0.0.0.0", port)`, `Open("", port)`, each Core
  interface address, and finally an ephemeral port, and reports which one
  worked on the Setup page.
- Whether the unit's `OK` line carries the `Device#<id>` prefix, and whether
  a quoted advertised name comes back with or without its quotes. Both forms
  are accepted. The plugin itself loads and renders in Q-SYS Designer 10.5
  (checked by the author).
- The default device ID. The API examples use 255 and `controller.id`
  defaults to 255, so that is the preset; change it on the device page if
  your unit answers to another ID.
- Program info is quoted when it contains spaces, like the advertised name.
  The API only states the quoting rule for the name.
- Label wrapping in Designer: all notes are kept to single lines so nothing
  depends on it.

### Repository layout

```
plugins/NikitaMicMixer.qplug   Mic Mixer
plugins/BettearCaster.qplug    Bettear CASTER control
assets/brand/                  logo files used by the plugins and this README
                               (bettear-logo.svg/.png belong to Bettear)
```

---
Nikita Visual Arts – nikitavisual.art
