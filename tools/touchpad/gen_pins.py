#!/usr/bin/env python3
"""Nikita Visual Arts – nikitavisual.art
Touch Pad for Q-SYS: build docs/touchpad/PINS.md from the built plugin.

The built plugin (plugins/NikitaTouchPad.qplug) is loaded into a fresh Lua 5.3
state exactly as build.py's smoke test does (compile, run with Controls nil so
the runtime stays dormant). For every mode in MODE_NAMES the script sets the
default properties (plus Camera Control = "Demo (simulated)" for the camera
modes, so the camera controls appear), runs RectifyProperties, GetPages,
GetControls and GetControlLayout for every page, and writes one Markdown
section per mode with a table of every control: pin name, Lua name, type,
direction and description.

    python3 tools/touchpad/gen_pins.py             # writes docs/touchpad/PINS.md
    python3 tools/touchpad/gen_pins.py --stdout    # prints instead of writing
    python3 tools/touchpad/gen_pins.py --plugin plugins/.build/NikitaTouchPad-xy.qplug --out /tmp/pins.md

Exit code 1 on any Lua error (syntax, load, or a reserved function failing for
any mode or page), 0 when the file was written.
"""
import argparse
import os
import sys

import lupa.lua53 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_PLUGIN = os.path.join(REPO, "plugins", "NikitaTouchPad.qplug")
DEFAULT_OUT = os.path.join(REPO, "docs", "touchpad", "PINS.md")

BRAND_LINE = "Nikita Visual Arts – nikitavisual.art"
CAMERA_DEMO = "Demo (simulated)"

# Runs inside the plugin's Lua state and returns, per mode, the pages, the
# controls and the PrettyName each pinned control carries in the layout.
# Nothing here is wrapped in pcall: a failure anywhere must stop the script.
COLLECT = r"""
local cameraDemo = ...
for _, name in ipairs({ "GetProperties", "GetControls", "GetControlLayout", "GetPages", "GetPrettyName" }) do
  if type(_G[name]) ~= "function" then error("reserved function " .. name .. " is missing from the plugin", 0) end
end
if type(MODE_NAMES) ~= "table" or #MODE_NAMES == 0 then error("MODE_NAMES is missing or empty", 0) end

local function defaults()
  local props = GetProperties()
  if type(props) ~= "table" then error("GetProperties returned " .. type(props), 0) end
  local out = {}
  for _, p in ipairs(props) do
    if type(p.Name) ~= "string" then error("GetProperties: a property without a Name", 0) end
    out[p.Name] = { Value = p.Value }
  end
  if out["Mode"] == nil then error("GetProperties: no Mode property", 0) end
  return out
end

local result = { version = tostring(PluginInfo and PluginInfo.Version or "?"), modes = {} }
for _, mode in ipairs(MODE_NAMES) do
  local props = defaults()
  props["Mode"].Value = mode
  local camera = false
  if CAMERA_MODES and CAMERA_MODES[mode] and props["Camera Control"] then
    props["Camera Control"].Value = cameraDemo
    camera = true
  end
  if type(RectifyProperties) == "function" then RectifyProperties(props) end
  local pretty = GetPrettyName(props)
  local pages = GetPages(props)
  if type(pages) ~= "table" or #pages == 0 then error("GetPages returned no pages for mode " .. mode, 0) end
  local controls = GetControls(props)
  if type(controls) ~= "table" or #controls == 0 then error("GetControls returned no controls for mode " .. mode, 0) end

  -- PrettyName per layout key, from the first page that places the control.
  local prettyNames, problems = {}, {}
  local pageNames = {}
  for i, p in ipairs(pages) do
    if type(p) ~= "table" or type(p.name) ~= "string" then error("GetPages entry " .. i .. " has no name (mode " .. mode .. ")", 0) end
    pageNames[i] = p.name
    props["page_index"] = { Value = i }
    local layout = GetControlLayout(props)
    if type(layout) ~= "table" then error("GetControlLayout returned " .. type(layout) .. " for mode " .. mode .. ", page " .. p.name, 0) end
    for key, e in pairs(layout) do
      if type(e) == "table" and type(e.PrettyName) == "string" and prettyNames[key] == nil then
        prettyNames[key] = e.PrettyName
      end
    end
    if type(LAYOUT_PROBLEMS) == "table" then
      for _, msg in ipairs(LAYOUT_PROBLEMS) do problems[#problems + 1] = p.name .. ": " .. tostring(msg) end
    end
  end

  local rows = {}
  for _, c in ipairs(controls) do
    if type(c) ~= "table" or type(c.Name) ~= "string" then error("GetControls: a control without a Name (mode " .. mode .. ")", 0) end
    local count = tonumber(c.Count) or 1
    local key = (count == 1) and c.Name or (c.Name .. " 1")
    rows[#rows + 1] = {
      Name = c.Name, Count = count, ControlType = c.ControlType, ButtonType = c.ButtonType,
      IndicatorType = c.IndicatorType, ControlUnit = c.ControlUnit, Min = c.Min, Max = c.Max,
      DefaultValue = c.DefaultValue, PinStyle = c.PinStyle, UserPin = c.UserPin,
      Description = c.Description, PrettyName = prettyNames[key],
    }
  end
  result.modes[#result.modes + 1] = { mode = mode, pretty = pretty, camera = camera, pages = pageNames,
                                      rows = rows, problems = problems }
end
return result
"""


class GenError(Exception):
    pass


# ---------------------------------------------------------------- Lua side

def load_plugin(path):
    """Compiles and runs the plugin in a fresh Lua state, as build.py does."""
    with open(path, "rb") as fh:
        source = fh.read().decode("utf-8")
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    try:
        chunk = lua.compile(source)
    except lupa.LuaSyntaxError as exc:
        raise GenError("syntax error in %s: %s" % (path, exc))
    try:
        chunk()
    except lupa.LuaError as exc:
        raise GenError("error while loading %s: %s" % (path, exc))
    return lua


def collect(lua):
    try:
        fn = lua.execute("return function(...) " + COLLECT + " end")
        return fn(CAMERA_DEMO)
    except lupa.LuaError as exc:
        raise GenError("Lua error while collecting the controls: %s" % exc)


def lua_list(t):
    """A Lua array table as a Python list."""
    if t is None:
        return []
    return [t[i] for i in range(1, len(t) + 1)]


# ------------------------------------------------------------- formatting

def num(v):
    if v is None:
        return ""
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".")
    return str(v)


def spaced(name):
    """Same rule as the framework: "DoubleTap" -> "Double Tap", "ZoneSelected 3" -> "Zone Selected 3"."""
    out = []
    for i, ch in enumerate(name):
        if i > 0 and ch.isupper() and (name[i - 1].islower() or name[i - 1].isdigit()):
            out.append(" ")
        out.append(ch)
    return "".join(out)


def pin_text(row):
    """PrettyName "Group~Name" (or "Group~Name 1" for arrays) as "Group ~ Name [n]"; "none" when unpinned."""
    if row["PinStyle"] is None:
        return "none"
    pretty = row["PrettyName"]
    count = int(row["Count"])
    if not pretty:
        pretty = spaced(row["Name"])
        if count > 1:
            pretty += " 1"
    if count > 1 and pretty.endswith(" 1"):
        pretty = pretty[:-2] + " n"
    return " ~ ".join(part.strip() for part in pretty.split("~"))


def lua_name(row):
    name = row["Name"]
    if int(row["Count"]) > 1:
        name += " n"
    return "`%s`" % name


def type_text(row):
    parts = [str(row["ControlType"] or "?")]
    for key in ("ButtonType", "IndicatorType", "ControlUnit"):
        if row[key] is not None:
            parts.append(str(row[key]))
    if row["Min"] is not None or row["Max"] is not None:
        parts.append("%s..%s" % (num(row["Min"]), num(row["Max"])))
    if row["DefaultValue"] is not None:
        parts.append("(default %s)" % num(row["DefaultValue"]))
    text = " ".join(parts)
    count = int(row["Count"])
    if count > 1:
        text += ", x%d" % count
    return text


DIR = {"Input": "in", "Output": "out", "Both": "both"}


def dir_text(row):
    style = row["PinStyle"]
    if style is None:
        return ""
    return DIR.get(str(style), str(style).lower())


def cell(text):
    return str(text or "").replace("|", "\\|").replace("\n", " ")


def render(result, plugin_rel):
    version = str(result["version"])
    modes = lua_list(result["modes"])
    lines = []
    lines.append("<!-- %s -->" % BRAND_LINE)
    lines.append("# Touch Pad for Q-SYS: pins and controls")
    lines.append("")
    lines.append(BRAND_LINE)
    lines.append("")
    lines.append("Built from `%s` by `tools/touchpad/gen_pins.py` (plugin version %s). Do not edit by hand: "
                 "run the script again after a change to the plugin." % (plugin_rel, version))
    lines.append("")
    lines.append("## How to read this")
    lines.append("")
    lines.append("- **Pin** is the name Designer shows under the block's **Control Pins** list, grouped by the part "
                 "before the tilde (`Setup ~ Lock` sits in the *Setup* folder). Tick a pin there to expose it on the "
                 "block and wire it. `none` means the control has no pin and is reached on the block's pages or from Lua.")
    lines.append("- **Lua name** is the control's name for scripts. Set the Touch Pad block's **Script Access** property "
                 "to **Script** or **All**, give it a **Code Name**, and then in a Text Controller or another plugin:")
    lines.append("")
    lines.append("  ```lua")
    lines.append('  local pad = Component.New("Lobby_Pad")     -- the block\'s Code Name')
    lines.append("  print(pad.X.Value, pad.Y.Value)             -- a knob: .Value, .Position, .String")
    lines.append("  pad.Lock.Boolean = true                     -- a toggle: .Boolean")
    lines.append("  pad.Tap.EventHandler = function(ctl)        -- a trigger: fires on every pulse")
    lines.append("    print(\"tapped\")")
    lines.append("  end")
    lines.append('  local route = pad["Route 2"]                -- an array control: "Name n" with a space')
    lines.append("  ```")
    lines.append("")
    lines.append("  A control marked `Name n` is an array: its members are `Name 1`, `Name 2` and so on, and the "
                 "count comes from the block's properties (Zones, Sources, Destinations, Speakers).")
    lines.append("- **Type** is the control type with its button or indicator kind, the unit and the range; "
                 "`x8` after it means an array of eight.")
    lines.append("- **Dir** is the pin direction: `in` is driven from outside, `out` is written by the pad, `both` "
                 "is written by the pad and can also be driven from outside.")
    lines.append("- **What it does** comes from the control's own description in the plugin source; a blank cell "
                 "means the mode has not written one yet. The user guide (`GUIDE.md`) describes every mode in prose.")
    lines.append("")
    lines.append("Every mode carries the same common set (Setup, Live and Actions pins) first; the mode's own "
                 "controls follow. Camera modes (Joystick, PTZ Pad, Camera Framing, Dial) are listed with "
                 "**Camera Control = %s** so the camera controls appear; with *None* those rows are absent, "
                 "*VISCA over IP* adds **Camera ~ Camera IP** and drops the Camera View display." % CAMERA_DEMO)
    lines.append("")
    lines.append("## Modes")
    lines.append("")
    for m in modes:
        rows = lua_list(m["rows"])
        pinned = sum(1 for r in rows if r["PinStyle"] is not None)
        lines.append("- [%s](#%s): %d controls, %d with pins" % (m["mode"], anchor(str(m["mode"])), len(rows), pinned))
    lines.append("")
    for m in modes:
        mode = str(m["mode"])
        rows = lua_list(m["rows"])
        pages = [str(p) for p in lua_list(m["pages"])]
        lines.append("## %s" % mode)
        lines.append("")
        note = "Block name: `%s`. Pages: %s." % (m["pretty"], ", ".join(pages))
        if m["camera"]:
            note += " Listed with Camera Control = %s." % CAMERA_DEMO
        lines.append(note)
        lines.append("")
        lines.append("| Pin | Lua name | Type | Dir | What it does |")
        lines.append("|---|---|---|---|---|")
        for r in rows:
            lines.append("| %s | %s | %s | %s | %s |" % (cell(pin_text(r)), lua_name(r), cell(type_text(r)),
                                                        dir_text(r), cell(r["Description"])))
        lines.append("")
    lines.append("---")
    lines.append(BRAND_LINE)
    lines.append("")
    return "\n".join(lines)


def anchor(title):
    out = []
    for ch in title.lower():
        if ch.isalnum():
            out.append(ch)
        elif ch in " -":
            out.append("-")
    return "".join(out)


# ------------------------------------------------------------------ main

def main(argv):
    ap = argparse.ArgumentParser(description="Build docs/touchpad/PINS.md from the built Touch Pad plugin.")
    ap.add_argument("--plugin", default=DEFAULT_PLUGIN, help="the .qplug to read (default plugins/NikitaTouchPad.qplug)")
    ap.add_argument("--out", default=DEFAULT_OUT, help="the Markdown file to write (default docs/touchpad/PINS.md)")
    ap.add_argument("--stdout", action="store_true", help="print the Markdown instead of writing the file")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args(argv)
    try:
        if not os.path.isfile(args.plugin):
            raise GenError("plugin not found: %s (run tools/touchpad/build.py first)" % args.plugin)
        lua = load_plugin(args.plugin)
        result = collect(lua)
        modes = lua_list(result["modes"])
        for m in modes:
            problems = [str(p) for p in lua_list(m["problems"])]
            for p in problems:
                print("warning: mode '%s': layout problem: %s" % (m["mode"], p), file=sys.stderr)
            if args.verbose:
                rows = lua_list(m["rows"])
                print("  %-16s pages %d  controls %3d" % (m["mode"], len(lua_list(m["pages"])), len(rows)))
        text = render(result, os.path.relpath(args.plugin, REPO))
    except GenError as exc:
        print("GEN_PINS FAILED\n" + str(exc), file=sys.stderr)
        return 1
    except lupa.LuaError as exc:
        print("GEN_PINS FAILED\nLua error: %s" % exc, file=sys.stderr)
        return 1
    if args.stdout:
        sys.stdout.write(text)
        return 0
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("wrote %s (%d modes, %d lines)" % (os.path.relpath(args.out, REPO), len(modes), text.count("\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
