#!/usr/bin/env python3
# Nikita Visual Arts – nikitavisual.art
"""Static checks for a Q-SYS plugin (.qplug) file.

Usage:
    python3 check_plugin.py path/to/Plugin.qplug [--brand "Nikita Visual Arts"] [--no-brand]

Exit code 0 when no errors were found (warnings are allowed), 1 otherwise.

Checks:
  * Lua syntax, with `luac` or the `lupa` Python package (noted when neither exists).
  * With `lupa`: runs the design-time functions for the default properties and
    for each integer property's Min and Max, and cross-checks layout keys,
    wiring endpoints, duplicate names and component names.
  * PluginInfo table with Name, Version, Id (GUID shape), Author.
  * The design-time functions GetControls and GetControlLayout exist, and
    a runtime block `if Controls then` is present.
  * Control tables (ones carrying ControlType) do not use `Value =` for
    their default; Q-SYS reads `DefaultValue`.
  * Literal layout keys name a declared control.
  * Enumerated values (Style, Font, ControlUnit, ControlType, ButtonType,
    IndicatorType, PinStyle, MeterStyle, graphics Type) come from the
    documented sets.
  * A brand header comment and Author are present.
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ENUMS = {
    "Style": {"Fader", "Knob", "Button", "Text", "Meter", "Led", "ListBox", "ComboBox", "Media", "None"},
    "ControlType": {"Button", "Knob", "Text", "Indicator"},
    "ButtonType": {"Toggle", "Momentary", "Trigger", "StateTrigger"},
    "IndicatorType": {"Led", "Meter", "Status", "Text"},
    "ControlUnit": {"dB", "Float", "Hz", "Integer", "Pan", "Percent", "Position", "Seconds"},
    "PinStyle": {"Input", "Output", "Both", "None"},
    "MeterStyle": {"Level", "Reduction", "Gain", "Standard"},
    "ButtonStyle": {"Toggle", "Momentary", "Trigger", "StateTrigger", "On", "Off", "Custom"},
    "TextBoxStyle": {"Normal", "Meter", "NoBackground"},
    "HTextAlign": {"Left", "Center", "Right"},
    "VTextAlign": {"Top", "Center", "Bottom"},
    "IconType": {"Icon", "Image", "SVG"},
    "Direction": {"input", "output"},
    "Domain": {"audio", "serial"},
    "Font": {"Roboto", "Roboto Mono", "Roboto Slab", "Open Sans", "Lato", "Montserrat",
             "Noto Serif", "Poppins", "Droid Sans", "Adamina", "Slabo 27px"},
}
GRAPHIC_TYPES = {"Label", "GroupBox", "Header", "Image", "Svg"}
FONT_STYLES = {
    "Roboto": ["Thin", "Thin Italic", "Light", "Light Italic", "Regular", "Italic", "Medium", "Medium Italic", "Bold", "Bold Italic", "Black", "Black Italic"],
    "Roboto Mono": ["Thin", "Thin Italic", "Light", "Light Italic", "Regular", "Italic", "Medium", "Medium Italic", "Bold", "Bold Italic"],
    "Roboto Slab": ["Thin", "Light", "Regular", "Bold"],
    "Open Sans": ["Light", "Light Italic", "Regular", "Italic", "Semibold", "Semibold Italic", "Bold", "Bold Italic", "Extrabold", "Extrabold Italic"],
    "Lato": ["Light", "Light Italic", "Regular", "Italic", "Bold", "Bold Italic", "Black", "Black Italic"],
    "Montserrat": ["Thin", "Thin Italic", "ExtraLight", "ExtraLight Italic", "Light", "Light Italic", "Regular", "Italic", "Medium", "Medium Italic", "SemiBold", "SemiBold Italic", "Bold", "Bold Italic", "ExtraBold", "ExtraBold Italic", "Black", "Black Italic"],
    "Noto Serif": ["Regular", "Italic", "Bold", "BoldItalic"],
    "Poppins": ["Light", "Regular", "Medium", "SemiBold", "Bold"],
    "Droid Sans": ["Regular", "Bold"],
    "Adamina": ["Regular"],
    "Slabo 27px": ["Regular"],
}
PROPERTY_TYPES = {"string", "integer", "double", "boolean", "enum"}
GUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
TEMPLATE_GUID = "5b1f2a3c-9d4e-4f60-8a71-2c3d4e5f6a7b"


class Report:
    def __init__(self):
        self.errors, self.warnings, self.notes = [], [], []

    def error(self, msg):
        if msg not in self.errors: self.errors.append(msg)
    def warn(self, msg):
        if msg not in self.warnings: self.warnings.append(msg)
    def note(self, msg): self.notes.append(msg)


def strip_comments(src: str) -> str:
    """Remove Lua comments so string scans do not trip on commented-out code."""
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)


def enclosing_table(src: str, pos: int) -> str:
    """Return the text of the innermost `{ ... }` Lua table that contains pos."""
    depth = 0
    start = None
    for i in range(pos, -1, -1):
        ch = src[i]
        if ch == "}":
            depth += 1
        elif ch == "{":
            if depth == 0:
                start = i
                break
            depth -= 1
    if start is None:
        return src[max(0, pos - 200):pos + 200]
    depth = 0
    for j in range(start, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[start:j + 1]
    return src[start:]


def line_of(src: str, pos: int) -> int:
    return src.count("\n", 0, pos) + 1


def check_syntax(path: Path, rep: Report):
    luac = shutil.which("luac") or shutil.which("luac5.4") or shutil.which("luac5.3")
    if not luac:
        try:
            import lupa
            lua = lupa.LuaRuntime()
            lua.compile(path.read_text(encoding="utf-8", errors="replace"))
            rep.note("Lua syntax OK (lupa).")
        except ImportError:
            rep.note("luac not installed and `lupa` not available: Lua syntax was not checked.")
        except Exception as e:  # lupa.LuaSyntaxError
            rep.error("Lua syntax: " + str(e).splitlines()[0])
        return
    proc = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
    if proc.returncode != 0:
        rep.error("Lua syntax: " + proc.stderr.strip())
    else:
        rep.note(f"Lua syntax OK ({Path(luac).name}).")


def check_plugininfo(code: str, rep: Report):
    m = re.search(r"PluginInfo\s*=\s*\{(.*?)\n\}", code, flags=re.S)
    if not m:
        rep.error("PluginInfo table not found.")
        return
    body = m.group(1)
    fields = dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', body))
    for key in ("Name", "Version", "Id", "Author", "Description"):
        if key not in fields or not fields[key].strip():
            rep.error(f"PluginInfo.{key} is missing or empty.")
    guid = fields.get("Id", "")
    if guid and not GUID_RE.match(guid):
        rep.error(f"PluginInfo.Id is not a GUID: {guid!r}")
    if guid == TEMPLATE_GUID:
        rep.error("PluginInfo.Id is still the template GUID; generate a new one "
                  "(python3 -c 'import uuid; print(uuid.uuid4())').")
    if "BuildVersion" not in fields:
        rep.warn("PluginInfo.BuildVersion is missing (four-part build number).")


def check_functions(code: str, rep: Report):
    required = ["GetControls", "GetControlLayout"]
    optional = ["GetProperties", "GetPins", "GetComponents", "GetWiring", "GetPages",
                "GetColor", "GetPrettyName", "RectifyProperties"]
    for fn in required:
        if not re.search(rf"function\s+{fn}\s*\(", code):
            rep.error(f"function {fn}(props) is missing.")
    present = [fn for fn in optional if re.search(rf"function\s+{fn}\s*\(", code)]
    rep.note("Design-time functions present: " + ", ".join(required + present))
    if not re.search(r"\bif\s+Controls\s+then\b", code):
        rep.warn("No runtime block (`if Controls then ... end`) found.")
    has_components = re.search(r"function\s+GetComponents\s*\(", code)
    has_wiring = re.search(r"function\s+GetWiring\s*\(", code)
    if has_components and not has_wiring:
        rep.warn("GetComponents exists but GetWiring does not: embedded components carry no signal.")
    if re.search(r"function\s+GetPages\s*\(", code) and "page_index" not in code:
        rep.warn("GetPages exists but GetControlLayout never reads props[\"page_index\"].")


def control_tables(code: str):
    """Yield (start_pos, table_text) for every Lua table literal that declares a ControlType."""
    for m in re.finditer(r"\{[^{}]*ControlType\s*=\s*\"[^\"]+\"[^{}]*\}", code):
        yield m.start(), m.group(0)


def check_controls(code: str, rep: Report):
    names = set()
    count = 0
    for pos, tbl in control_tables(code):
        count += 1
        n = re.search(r'Name\s*=\s*"([^"]+)"', tbl)
        if n:
            names.add(n.group(1))
        else:
            n2 = re.search(r"Name\s*=\s*([^,}]+)", tbl)
            if n2:
                names.add("<dynamic>")
        if re.search(r"[,{]\s*Value\s*=", tbl):
            rep.error(f"line {line_of(code, pos)}: control uses `Value =`; Q-SYS reads `DefaultValue` for a control's initial value.")
        ct = re.search(r'ControlType\s*=\s*"([^"]+)"', tbl).group(1)
        if ct == "Knob" and "DefaultValue" not in tbl:
            rep.warn(f"line {line_of(code, pos)}: Knob without DefaultValue starts at its Min.")
        if ct == "Button" and "ButtonType" not in tbl:
            rep.warn(f"line {line_of(code, pos)}: Button without ButtonType.")
        if ct == "Indicator" and "IndicatorType" not in tbl:
            rep.warn(f"line {line_of(code, pos)}: Indicator without IndicatorType.")
    if count == 0:
        rep.error("No control tables (with ControlType) found.")
    else:
        rep.note(f"{count} control declaration(s): " + ", ".join(sorted(names)))
    return names


def check_layout_keys(code: str, names: set, rep: Report):
    dynamic = "<dynamic>" in names
    for m in re.finditer(r'layout\[\s*"([^"]+)"\s*\]', code):
        key = m.group(1)
        base = re.sub(r"\s+\d+$", "", key)
        if key not in names and base not in names and not dynamic:
            rep.error(f"line {line_of(code, m.start())}: layout key {key!r} names no declared control.")


def check_enums(code: str, rep: Report):
    for field, allowed in ENUMS.items():
        for m in re.finditer(rf'\b{field}\s*=\s*"([^"]*)"', code):
            val = m.group(1)
            if val not in allowed:
                rep.error(f"line {line_of(code, m.start())}: {field} = {val!r} is not one of {sorted(allowed)}.")
    for m in re.finditer(r'\bType\s*=\s*"([^"]*)"', code):
        val = m.group(1)
        if val in GRAPHIC_TYPES or val in PROPERTY_TYPES:
            continue
        # Component Type strings are free-form; only flag obvious graphic/property typos.
        if val.lower() in {t.lower() for t in GRAPHIC_TYPES | PROPERTY_TYPES}:
            rep.error(f"line {line_of(code, m.start())}: Type = {val!r} has the wrong case.")
    for m in re.finditer(r'\bFontStyle\s*=\s*"([^"]*)"', code):
        val = m.group(1)
        if not re.fullmatch(r"(Thin|ExtraLight|Light|Regular|Italic|Medium|SemiBold|Semibold|Bold|ExtraBold|Extrabold|Black|BoldItalic)( Italic)?", val):
            rep.warn(f"line {line_of(code, m.start())}: FontStyle = {val!r} is not a known style; check the font table.")
    # Font and FontStyle declared in the same table must be a supported pair.
    for m in re.finditer(r'\bFont\s*=\s*"([^"]*)"', code):
        font = m.group(1)
        tbl = enclosing_table(code, m.start())
        st = re.search(r'\bFontStyle\s*=\s*"([^"]*)"', tbl)
        if st and font in FONT_STYLES and st.group(1) not in FONT_STYLES[font]:
            rep.error(f"line {line_of(code, m.start())}: Font {font!r} has no style {st.group(1)!r}; "
                      f"supported: {', '.join(FONT_STYLES[font])}.")


def run_design_time(path: Path, rep: Report):
    """Execute the design-time half of the plugin in a Lua sandbox (needs the `lupa` package).

    Builds the property table from GetProperties, then calls every design-time
    function for the default property values and for each integer property's
    Min and Max, and cross-checks layout keys, wiring endpoints and names.
    """
    try:
        import lupa
    except ImportError:
        rep.note("python package `lupa` not installed: design-time functions were not executed "
                 "(pip install lupa to enable).")
        return
    src = path.read_text(encoding="utf-8", errors="replace")
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Controls = nil; Properties = nil")
    # Stub the Designer-only globals a plugin may touch at design time.
    lua.execute("Timer = { New = function() return { Start = function() end, Stop = function() end } end, CallAfter = function() end }")
    try:
        lua.execute(src)
    except lupa.LuaError as e:
        rep.error(f"design-time load failed: {str(e).splitlines()[0]}")
        return
    g = lua.globals()
    if g.GetProperties is None:
        rep.note("GetProperties missing: design-time run skipped.")
        return
    try:
        props_def = list(g.GetProperties().values())
    except lupa.LuaError as e:
        rep.error(f"GetProperties() failed: {e}")
        return

    def build_props(overrides):
        t = lua.table()
        for p in props_def:
            entry = lua.table(Value=overrides.get(p.Name, p.Value), Name=p.Name, Type=p.Type)
            t[p.Name] = entry
        t["page_index"] = lua.table(Value=1)
        return t

    def to_list(tbl):
        return [] if tbl is None else list(tbl.values())

    cases = [("defaults", {})]
    for p in props_def:
        if p.Type == "integer" and p.Min is not None and p.Max is not None:
            cases.append((f"{p.Name}={p.Min}", {p.Name: p.Min}))
            cases.append((f"{p.Name}={p.Max}", {p.Name: p.Max}))
    checked = 0
    for label, overrides in cases:
        props = build_props(overrides)
        try:
            if g.RectifyProperties is not None:
                g.RectifyProperties(props)
            if g.GetPrettyName is not None:
                g.GetPrettyName(props)
            if g.GetColor is not None:
                g.GetColor(props)
            pages = to_list(g.GetPages(props)) if g.GetPages is not None else [None]
            ctls = to_list(g.GetControls(props))
            pins = to_list(g.GetPins(props)) if g.GetPins is not None else []
            comps = to_list(g.GetComponents(props)) if g.GetComponents is not None else []
            wiring = to_list(g.GetWiring(props)) if g.GetWiring is not None else []
        except lupa.LuaError as e:
            rep.error(f"design-time run [{label}] raised: {str(e).splitlines()[0]}")
            continue

        ctl_keys = set()
        ctl_names = []
        for c in ctls:
            ctl_names.append(c.Name)
            count = int(c.Count or 1)
            if count == 1:
                ctl_keys.add(c.Name)
            else:
                ctl_keys.update(f"{c.Name} {i}" for i in range(1, count + 1))
        dupes = {n for n in ctl_names if ctl_names.count(n) > 1}
        if dupes:
            rep.error(f"[{label}] duplicate control names: {sorted(dupes)}")

        pin_names = [p.Name for p in pins]
        if len(pin_names) != len(set(pin_names)):
            rep.error(f"[{label}] duplicate pin names in GetPins.")
        comp_names = [c.Name for c in comps]
        for n in comp_names:
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", n or ""):
                rep.error(f"[{label}] component Name {n!r} is not a valid Lua identifier (it becomes a global).")
        if len(comp_names) != len(set(comp_names)):
            rep.error(f"[{label}] duplicate component names in GetComponents.")
        comp_set = set(comp_names)
        pin_set = set(pin_names)
        for w in wiring:
            ends = to_list(w)
            if len(ends) < 2:
                rep.warn(f"[{label}] a wire has fewer than two endpoints: {ends}")
            for e in ends:
                e = str(e)
                if e in pin_set:
                    continue
                # Component endpoints: "<component> <pin name>", where the pin name is
                # "Input n", "Output n" or a block-specific name such as "High".
                m = re.match(r"^(\S+)\s+\S", e)
                if m and m.group(1) in comp_set:
                    continue
                rep.error(f"wiring endpoint {e!r} is neither a plugin pin nor '<component> <pin>' "
                          f"for a declared component (case {label}).")

        for pi in range(1, len(pages) + 1):
            props["page_index"] = lua.table(Value=pi)
            try:
                layout, graphics = g.GetControlLayout(props)
            except lupa.LuaError as e:
                rep.error(f"GetControlLayout [{label}, page {pi}] raised: {str(e).splitlines()[0]}")
                continue
            except (TypeError, ValueError):
                rep.error(f"GetControlLayout [{label}, page {pi}] must return two tables (layout, graphics).")
                continue
            for key in (layout or {}).keys():
                if key not in ctl_keys:
                    rep.error(f"[{label}, page {pi}] layout key {key!r} matches no control "
                              f"(remember \"Name i\" keys when Count > 1).")
            for gfx in to_list(graphics):
                if gfx.Type not in GRAPHIC_TYPES:
                    rep.error(f"[{label}, page {pi}] graphic Type {gfx.Type!r} is not one of {sorted(GRAPHIC_TYPES)}.")
                if gfx.Type in ("Image", "Svg") and not gfx.Image:
                    rep.warn(f"[{label}, page {pi}] an {gfx.Type} graphic has an empty Image.")
        checked += 1
    rep.note(f"Design-time functions executed for {checked} property case(s) via lupa.")


def check_brand(raw: str, brand: str, rep: Report):
    head = raw[:600]
    if brand.lower() not in head.lower():
        rep.warn(f"No brand header comment with {brand!r} in the first lines of the file.")
    m = re.search(r'Author\s*=\s*"([^"]*)"', raw)
    if m and brand.lower() not in m.group(1).lower():
        rep.warn(f"PluginInfo.Author does not mention {brand!r}.")


def main():
    ap = argparse.ArgumentParser(description="Static checks for a Q-SYS .qplug plugin.")
    ap.add_argument("file", type=Path)
    ap.add_argument("--brand", default="Nikita Visual Arts", help="brand string expected in header and Author")
    ap.add_argument("--no-brand", action="store_true", help="skip the brand checks")
    ap.add_argument("--no-run", action="store_true", help="do not execute the design-time functions in a Lua sandbox")
    args = ap.parse_args()

    raw = args.file.read_text(encoding="utf-8", errors="replace")
    code = strip_comments(raw)
    rep = Report()

    check_syntax(args.file, rep)
    check_plugininfo(code, rep)
    check_functions(code, rep)
    names = check_controls(code, rep)
    check_layout_keys(code, names, rep)
    check_enums(code, rep)
    if not args.no_run:
        run_design_time(args.file, rep)
    if not args.no_brand:
        check_brand(raw, args.brand, rep)

    for n in rep.notes:
        print("note:    " + n)
    for w in rep.warnings:
        print("warning: " + w)
    for e in rep.errors:
        print("ERROR:   " + e)
    print(f"\n{args.file}: {len(rep.errors)} error(s), {len(rep.warnings)} warning(s)")
    sys.exit(1 if rep.errors else 0)


if __name__ == "__main__":
    main()
