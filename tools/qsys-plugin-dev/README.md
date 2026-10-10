<!-- Nikita Visual Arts – nikitavisual.art -->
<p align="center">
  <img src="assets/brand/logo-horizontal.png" alt="Nikita Visual Arts" width="280"><br>
  <strong>Nikita Visual Arts – nikitavisual.art</strong>
</p>

# Q-SYS Plugin Dev

A coding-assistant plugin that teaches the assistant how to write, extend and
check Q-SYS Designer plugins (`.qplug`) in Lua. It bundles one skill,
`qsys-plugin-dev`, with:

- a compact guide to the plugin framework: the design-time functions, every
  control, layout, graphics, pin, component and wiring field, and the runtime
  API (`Controls`, embedded components, timers, Status values);
- the practical traps learned on real plugins (`DefaultValue` versus `Value`,
  the `Count = 1` single-object quirk, pages, silently dropped component
  types);
- a branded plugin template to start every new block from;
- `check_plugin.py`, a static checker for `.qplug` files;
- `embed_image.py`, which turns a PNG or SVG into a Lua base64 string for the
  header logo;
- `qrc_deploy.py`, which lists, fetches and pushes Lua scripts on a Q-SYS
  Core or Designer emulation over the QRC protocol.

## Install

**As a plugin.** Point the assistant at this folder as a plugin directory,
or copy it into your plugin marketplace. The manifest is in
`.claude-plugin/plugin.json`.

**As a bare skill.** Copy `skills/qsys-plugin-dev/` into your skills folder.
The skill is self-contained; the scripts need only Python 3.

The skill triggers on any mention of a `.qplug` file, a Q-SYS plugin, plugin
controls, layouts, pins, embedded components or wiring, and on requests for a
Q-SYS DSP or control block even when the word "plugin" is not used.

## Layout

```
.claude-plugin/plugin.json            plugin manifest
assets/brand/                         logo files
skills/qsys-plugin-dev/
  SKILL.md                            the workflow the assistant follows
  references/design-time-api.md       PluginInfo, properties, controls, layout, graphics, pins, components, wiring
  references/runtime-api.md           Controls, Properties, components, Timer, Status
  references/ui-style-reference.md    fonts, colours, enumerations, sizes
  references/deploy-and-test.md       installing plugins, pushing scripts over QRC
  assets/plugin-template.qplug        starting point for a new plugin
  scripts/check_plugin.py             static checker
  scripts/embed_image.py              image to base64 Lua string
  scripts/qrc_deploy.py               QRC list / get / push for script components
  evals/evals.json                    example prompts used to test the skill
```

## Checking a plugin by hand

```bash
python3 skills/qsys-plugin-dev/scripts/check_plugin.py ../../plugins/NikitaMicMixer.qplug
```

Install `luac` (Lua 5.3 or 5.4) to add a real syntax check; without it the
script still runs every structural check.

## Sources

Field names and allowed values were cross-checked against the Q-SYS
Developer Help and these open-source VS Code extensions:

- [Better Lua for Q-SYS Plugins](https://github.com/hojoworks/better-qsys-vscode-extension) (MIT)
- [Lua for Q-SYS Plugins](https://github.com/shorty456132/qsys-vscode-extension)
- [Q-SYS Lua Script Deployment](https://github.com/White-Label-AV/qsys-deploy-vscode) (MIT), for the QRC details

---
Nikita Visual Arts – nikitavisual.art
