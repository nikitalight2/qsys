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
  every mode in `MODE_NAMES` with default property values (reported as "framework not
  present yet" while `40_framework.lua` does not exist).

Exit code 0 means the plugin was written and everything passed.

### Unit tests

    python3 tools/touchpad/harness/lua_unit.py --all
    python3 tools/touchpad/harness/lua_unit.py tools/touchpad/harness/tests/test_svg.lua -v

Each test file in `tools/touchpad/harness/tests/` is loaded into a fresh Lua state after
the source modules. Every global `test_*` function runs, with `T.eq`, `T.near`, `T.ok`,
`T.err`, `T.deq` and `T.instructions` available. The runner prints pass/fail per test
and the VM instruction count, which must stay well under the Core's per-callback budget.
