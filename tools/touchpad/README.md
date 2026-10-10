# Nikita Visual Arts – nikitavisual.art
## Touch Pad for Q-SYS: build and test tools

The plugin is written as small Lua 5.3 modules in `src/touchpad/` and shipped as one
file, `plugins/NikitaTouchPad.qplug`. Lua runs here through Python (`lupa`), so the only
requirement is `python3 -m pip install lupa`.

### Build

    python3 tools/touchpad/build.py          # build, check and smoke-test
    python3 tools/touchpad/build.py --check  # checks only, writes nothing
    python3 tools/touchpad/build.py -v       # list files and per-mode smoke details
    python3 tools/touchpad/build.py --selftest  # exercise the ASCII checker on probe sources

`build.py` concatenates `src/touchpad/*.lua` in file-name order (one `-- ===== file =====`
separator per file), then refuses to write the plugin unless every check passes:

- every source file starts with the two brand comment lines;
- the only non-ASCII character is the en dash of the brand line, and it appears only in
  comments, in `PluginInfo` strings or in the `NikitaAssets` block (offending lines are
  listed). The checker classifies every character as code, comment or string, follows
  long brackets and backslash-continued strings across lines, and tracks the brace
  depth of the two tables so nested tables inside them neither end the block early nor
  leave it open; `--selftest` runs it against built-in probe sources;
- the result compiles and loads in Lua 5.3;
- `GetProperties`, `GetPages`, `GetControls` and `GetControlLayout` run without error for
  every mode in `MODE_NAMES` with default property values and a few property variants per
  mode (camera kinds, 20 x 20 sources and destinations, 32 zones, the Custom theme with a
  1600 px pad), on every page of every mode (reported as "framework not present yet" while
  `40_framework.lua` does not exist);
- the layout lint passes for every page: every control from `GetControls` is placed on at
  least one page, no control is placed twice on one page (the builder `L` records that in
  `LAYOUT_PROBLEMS`, as it does unknown keys and mode layout errors), every layout key is a
  control, positions and sizes stay inside the page (the first graphics entry is the page
  background and gives its size), every graphics text is ASCII except the brand en dash, and
  every control with a `UserPin` carries a `PrettyName` of the form `Group~Name` in one of
  the pin groups (Setup, Live, Outputs, Actions, Camera, Zones, Sources, Routing, Guest or
  the mode's own name), the same on every page it appears on.

Exit code 0 means the plugin was written and everything passed.

### Unit tests

    python3 tools/touchpad/harness/lua_unit.py --all
    python3 tools/touchpad/harness/lua_unit.py tools/touchpad/harness/tests/test_svg.lua -v

Each test file in `tools/touchpad/harness/tests/` is loaded into a fresh Lua state after
the source modules. Every global `test_*` function runs, with `T.eq`, `T.near`, `T.ok`,
`T.err`, `T.deq` and `T.instructions` available. The runner prints pass/fail per test
and the VM instruction count, which must stay well under the Core's per-callback budget.

`test_framework.lua` covers the design-time framework (`40_framework.lua`): property order
and hiding per mode, the common control list with its pins, `Count` values taken from
properties, page lists, the `L` layout helpers and the picker geometry text.

### Scenario harness (fake Q-SYS runtime)

    python3 tools/touchpad/harness/run_tests.py          # layout lint of the built plugin + tests/test_*.py
    python3 tools/touchpad/harness/run_tests.py -k tap -v

`tools/touchpad/harness/qsys_fake.py` runs the plugin inside a fake control
engine (fake Controls, Timer on a virtual clock, Component with a fake Color
Picker, HttpClient, sockets, sandboxed files) and counts the VM instructions
of every callback against the budgets of the spec. `harness/README.md`
documents the Python API (`from harness import QSys`) and how to write a test.
