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

Tooling for writing and checking plugins lives in `tools/qsys-plugin-dev/`
(see [Plugin development tooling](#plugin-development-tooling)).

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
tools/qsys-plugin-dev/         coding-assistant plugin + skill for Q-SYS plugin work
.vscode/                       editor settings and recommended extensions
```

## Plugin development tooling

`tools/qsys-plugin-dev/` is a coding-assistant plugin that bundles the
`qsys-plugin-dev` skill: a guide to the Q-SYS plugin framework (design-time
tables, layout, pins, components, wiring, runtime API), a branded plugin
template, and three scripts that work on their own:

| Script | What it does |
|---|---|
| `scripts/check_plugin.py` | Static checks for a `.qplug`: syntax, `PluginInfo`, `DefaultValue` versus `Value`, layout keys, enumerations, and (with the `lupa` Python package) a sandbox run of every design-time function with wiring cross-checks. |
| `scripts/embed_image.py` | Turns a PNG or SVG into the base64 Lua string used for the header logo. |
| `scripts/qrc_deploy.py` | Lists, fetches and pushes Lua scripts on a Q-SYS Core or Designer emulation over the QRC protocol (port 1710). |

```bash
pip install lupa   # optional, enables the syntax check and sandbox run
python3 tools/qsys-plugin-dev/skills/qsys-plugin-dev/scripts/check_plugin.py plugins/NikitaMicMixer.qplug
```

See `tools/qsys-plugin-dev/README.md` for installing it as a plugin or as a
bare skill.

## Editing the plugins in VS Code

Install **[Better Lua for Q-SYS Plugins](https://marketplace.visualstudio.com/items?itemName=integratorblocks.qsys-intellisense)**
(`integratorblocks.qsys-intellisense`). It adds autocomplete and hover
documentation for the Q-SYS plugin design-time functions and properties, based
on the Q-SYS Developer Documentation, and works in `.lua` and `.qplug` files.

Two more extensions are worth having:

- **[Lua for Q-SYS Plugins](https://github.com/shorty456132/qsys-vscode-extension)**
  (`shorty456132.lua-for-qsys`): snippets for the plugin tables
  (`ctrls`, `props`, `layout`, `graphics`, `components`).
- **[Q-SYS Lua Script Deployment](https://github.com/White-Label-AV/qsys-deploy-vscode)**
  (`WhiteLabelAV.qsys-deploy-vscode`): pushes a Lua file into a Text
  Controller or Control Script on a Core or Designer emulation from the
  editor (Ctrl+Alt+D). The `qrc_deploy.py` script in `tools/` does the same
  from the terminal.

Opening this folder in VS Code prompts you to install them (they are listed
in `.vscode/extensions.json`), and `.vscode/settings.json` maps `*.qplug` to
Lua so highlighting and IntelliSense apply to the plugin sources.

---
Nikita Visual Arts – nikitavisual.art
