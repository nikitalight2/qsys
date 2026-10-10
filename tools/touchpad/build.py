#!/usr/bin/env python3
"""Build tools/touchpad: src/touchpad/*.lua -> plugins/NikitaTouchPad.qplug

Steps (every one must pass for exit code 0):
  1. Collect src/touchpad/*.lua in file-name order.
  2. Check that every file starts with the two brand header comment lines.
  3. Check that the only non-ASCII bytes are en dashes (U+2013) and that
     they sit inside comments, inside PluginInfo string literals or inside
     the NikitaAssets block. Offending line numbers are reported.
  4. Concatenate with a one-line separator comment per file.
  5. Compile the result with Lua 5.3 (lupa) and fail on a syntax error.
  6. Execute it in the same Lua state (Controls is nil, so the runtime
     section stays dormant) and smoke-test the framework functions for
     every Mode in MODE_NAMES with default property values. When the
     framework functions do not exist yet this only reports it.

    python3 tools/touchpad/build.py            build + check + smoke
    python3 tools/touchpad/build.py --check    checks only, writes nothing
    python3 tools/touchpad/build.py -v         list files and smoke details
"""
import argparse
import glob
import os
import re
import sys

import lupa.lua53 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_SRC = os.path.join(REPO, "src", "touchpad")
DEFAULT_OUT = os.path.join(REPO, "plugins", "NikitaTouchPad.qplug")

HEADER_LINE_1 = "-- Nikita Visual Arts – nikitavisual.art"
HEADER_LINE_2_PREFIX = "-- Touch Pad for Q-SYS: "
EN_DASH = "–"

FRAMEWORK_FUNCS = ("GetProperties", "GetControls", "GetControlLayout", "GetPages")
BLOCK_START = re.compile(r"^(PluginInfo|NikitaAssets)\b")


class BuildError(Exception):
    pass


# ---------------------------------------------------------------- sources

def source_files(src_dir):
    files = sorted(glob.glob(os.path.join(src_dir, "*.lua")), key=os.path.basename)
    if not files:
        raise BuildError("no .lua files in " + src_dir)
    return files


def read_text(path):
    with open(path, "rb") as fh:
        data = fh.read()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise BuildError("%s: not valid UTF-8 (%s)" % (path, exc))


def check_header(path, text):
    lines = text.split("\n")
    name = os.path.basename(path)
    problems = []
    if len(lines) < 2:
        return ["%s: file has fewer than two lines" % name]
    if lines[0] != HEADER_LINE_1:
        problems.append("%s:1: expected %r" % (name, HEADER_LINE_1))
    if not lines[1].startswith(HEADER_LINE_2_PREFIX) or len(lines[1]) <= len(HEADER_LINE_2_PREFIX):
        problems.append("%s:2: expected '%s<module name>'" % (name, HEADER_LINE_2_PREFIX))
    return problems


# ---------------------------------------------------------- ASCII checker

class LineScanner:
    """Classifies each character of a Lua file as code, comment or string.

    Tracks long strings / long comments and backslash-continued short strings
    across lines so a non-ASCII byte can be attributed to the region it lives
    in, and follows the brace depth of the PluginInfo / NikitaAssets tables
    (where en dashes in strings are allowed). Lua syntax is only approximated
    (no nesting of long brackets is needed for our sources).
    """

    def __init__(self):
        self.long_level = None     # level of an open [=*[ ... ]=*] block
        self.long_is_comment = False
        self.quote = None          # short string continued from the previous line
        self.block = None          # "PluginInfo" / "NikitaAssets" while inside that table
        self.depth = 0             # brace depth inside the block

    @property
    def in_block(self):
        return self.block is not None

    def code_char(self, ch, line):
        """Updates the block state for one code character; returns its kind."""
        if ch == "{":
            if self.block is None:
                match = BLOCK_START.match(line.lstrip())
                if match:
                    self.block, self.depth = match.group(1), 0
            if self.block is not None:
                self.depth += 1
        elif ch == "}" and self.block is not None:
            self.depth -= 1
            if self.depth <= 0:
                self.block = None
        return "code"

    @staticmethod
    def _long_open(line, i):
        # returns level when line[i:] starts with [ =* [ else None
        if i >= len(line) or line[i] != "[":
            return None
        j = i + 1
        while j < len(line) and line[j] == "=":
            j += 1
        if j < len(line) and line[j] == "[":
            return j - i - 1
        return None

    def _close_long(self, line, i):
        close = "]" + "=" * self.long_level + "]"
        return line.startswith(close, i), len(close)

    def classify(self, line):
        """Returns a list of (char, kind, in_block) for the line.

        kind is code / comment / string; in_block is True while the character
        sits inside the PluginInfo or NikitaAssets table.
        """
        out = []
        i = 0
        n = len(line)
        quote, self.quote = self.quote, None
        while i < n:
            ch = line[i]
            if self.long_level is not None:
                closed, length = self._close_long(line, i)
                kind = "comment" if self.long_is_comment else "string"
                if closed:
                    out.extend((c, kind, self.in_block) for c in line[i:i + length])
                    i += length
                    self.long_level = None
                    continue
                out.append((ch, kind, self.in_block))
                i += 1
                continue
            if quote is not None:
                out.append((ch, "string", self.in_block))
                if ch == "\\":
                    if i + 1 < n:
                        out.append((line[i + 1], "string", self.in_block))
                        i += 2
                        continue
                    self.quote = quote          # "\<newline>" continues the string
                    break
                if ch == quote:
                    quote = None
                i += 1
                continue
            if line.startswith("--", i):
                level = self._long_open(line, i + 2)
                if level is not None:
                    self.long_level = level
                    self.long_is_comment = True
                    out.extend((c, "comment", self.in_block) for c in line[i:i + 2])
                    i += 2
                    continue
                out.extend((c, "comment", self.in_block) for c in line[i:])
                break
            level = self._long_open(line, i)
            if level is not None:
                self.long_level = level
                self.long_is_comment = False
                out.append((ch, "string", self.in_block))
                i += 1
                continue
            if ch in "\"'":
                quote = ch
                out.append((ch, "string", self.in_block))
                i += 1
                continue
            out.append((ch, self.code_char(ch, line), self.in_block))
            i += 1
        return out


def check_ascii(path, text):
    """Returns a list of problem strings (empty when the file is clean)."""
    name = os.path.basename(path)
    problems = []
    scanner = LineScanner()
    for lineno, line in enumerate(text.split("\n"), 1):
        for ch, kind, allowed_string in scanner.classify(line):
            if ord(ch) < 128:
                continue
            if ch != EN_DASH:
                problems.append("%s:%d: non-ASCII character U+%04X (only the en dash is allowed)"
                                % (name, lineno, ord(ch)))
            elif kind == "code":
                problems.append("%s:%d: en dash outside comments and strings" % (name, lineno))
            elif kind == "string" and not allowed_string:
                problems.append("%s:%d: en dash in a string literal outside PluginInfo / NikitaAssets"
                                % (name, lineno))
    return problems


# ------------------------------------------------- checker self-test

SELFTEST_HEADER = HEADER_LINE_1 + "\n" + HEADER_LINE_2_PREFIX + "probe\n"

# (name, source after the header, expected problem count)
SELFTEST_CASES = [
    ("flat block", 'PluginInfo = {\n  Author = "a – b",\n}\n', 0),
    ("nested table closed on its own line",
     'PluginInfo = {\n  Extra = {\n    a = 1\n  },\n  Author = "a – b",\n  Description = "c – d",\n}\n', 0),
    ("nested table on one line", 'PluginInfo = {\n  Nested = { Author = "a – b" },\n  Description = "c – d",\n}\n', 0),
    ("string after the block", 'PluginInfo = {\n  Author = "a – b",\n}\nlocal t = "a – b"\n', 1),
    ("one-line block", 'PluginInfo = { Name = "x" }\nlocal t = "a – b"\n', 1),
    ("assets block", 'NikitaAssets = {\n  icon = "a – b",\n}\n', 0),
    ("backslash-newline string", 'local s = "a\\\nb – c"\n', 1),
    ("continued string then code", 'local s = "a\\\nb" .. x – y\n', 1),
    ("comment", '-- a – b\nlocal x = 1 --[[ c – d ]]\n', 0),
    ("long comment", '--[[\n a – b\n]]\n', 0),
    ("en dash in code", 'local x = 1 – 2\n', 1),
    ("other non-ascii", 'local s = "é"\n', 1),
    ("plugininfo field access", 'local n = PluginInfo.Name\nlocal t = "a – b"\n', 1),
]


def selftest():
    """Runs check_ascii on the probe sources; returns a list of failures."""
    failures = []
    for name, body, expected in SELFTEST_CASES:
        problems = check_ascii("probe.lua", SELFTEST_HEADER + body)
        if len(problems) != expected:
            failures.append("%s: expected %d problem(s), got %d: %s" % (name, expected, len(problems), problems))
    return failures


# ------------------------------------------------------------- assemble

def assemble(files):
    """Returns (source, starts); starts maps each file to its first line."""
    parts = []
    starts = []
    line = 1
    for path in files:
        text = read_text(path)
        if not text.endswith("\n"):
            text += "\n"
        starts.append((line, os.path.basename(path)))
        parts.append("-- ===== %s =====\n" % os.path.basename(path))
        parts.append(text)
        line += 1 + text.count("\n")
    return "".join(parts), starts


def locate(starts, message):
    """Rewrites '[string "<python>"]:N:' in a Lua message as 'file:line:'."""
    def repl(match):
        n = int(match.group(1))
        name, first = "?", 1
        for start, fname in starts:
            if start <= n:
                name, first = fname, start
        return "%s:%d (qplug line %d):" % (name, n - first, n)
    return re.sub(r'\[string "<python>"\]:(\d+):', repl, message)


# ------------------------------------------------- compile and smoke test

SMOKE = r"""
local modes = MODE_NAMES or {}
local report = {}
local present = {}
local missing = {}
for _, name in ipairs({ "GetProperties", "GetControls", "GetControlLayout", "GetPages" }) do
  if type(_G[name]) == "function" then present[#present + 1] = name
  else missing[#missing + 1] = name end
end
if #present == 0 then
  return { status = "absent" }
end
if #missing > 0 then
  return { status = "fail", msg = "framework incomplete, missing: " .. table.concat(missing, ", ") }
end
local function try(label, fn, ...)
  local ok, res = pcall(fn, ...)
  if not ok then error(label .. ": " .. tostring(res), 0) end
  return res
end
local function defaults()
  local props = try("GetProperties", GetProperties)
  if type(props) ~= "table" then error("GetProperties returned " .. type(props), 0) end
  local out = {}
  for _, p in ipairs(props) do
    if type(p.Name) ~= "string" then error("GetProperties: property without Name", 0) end
    out[p.Name] = { Value = p.Value }
  end
  if out["Mode"] == nil then error("GetProperties: no Mode property", 0) end
  return out
end
local function run_mode(mode)
  local props = defaults()
  props["Mode"].Value = mode
  if type(RectifyProperties) == "function" then try("RectifyProperties", RectifyProperties, props) end
  local pages = try("GetPages", GetPages, props)
  local controls = try("GetControls", GetControls, props)
  local layout, graphics = try("GetControlLayout", GetControlLayout, props)
  if type(pages) ~= "table" or #pages == 0 then error("GetPages returned no pages", 0) end
  if type(controls) ~= "table" or #controls == 0 then error("GetControls returned no controls", 0) end
  if type(layout) ~= "table" then error("GetControlLayout returned " .. type(layout), 0) end
  local n = 0
  for _ in pairs(layout) do n = n + 1 end
  if type(GetPrettyName) == "function" then
    local pretty = try("GetPrettyName", GetPrettyName, props)
    if type(pretty) ~= "string" then error("GetPrettyName returned " .. type(pretty), 0) end
  end
  return { pages = #pages, controls = #controls, layout = n }
end
for _, mode in ipairs(modes) do
  local ok, res = pcall(run_mode, mode)
  if not ok then
    return { status = "fail", msg = "Mode '" .. mode .. "': " .. tostring(res) }
  end
  report[#report + 1] = { mode = mode, pages = res.pages, controls = res.controls, layout = res.layout }
end
return { status = "ok", modes = report }
"""


def compile_and_smoke(source, starts, verbose):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    try:
        chunk = lua.compile(source)
    except lupa.LuaSyntaxError as exc:
        raise BuildError("syntax error: %s" % locate(starts, str(exc)))
    try:
        chunk()
    except lupa.LuaError as exc:
        raise BuildError("runtime error while loading the plugin: %s" % locate(starts, str(exc)))
    for name in ("PluginInfo", "MODE_NAMES", "THEMES", "U", "Font", "Svg", "Shapes"):
        if lua.globals()[name] is None:
            raise BuildError("global '%s' is missing after loading the plugin" % name)
    try:
        result = lua.execute(SMOKE)
    except lupa.LuaError as exc:
        raise BuildError("smoke test crashed: %s" % locate(starts, str(exc)))
    status = result["status"]
    if status == "absent":
        return "smoke: framework not present yet (GetProperties / GetControls / GetControlLayout / GetPages)"
    if status != "ok":
        raise BuildError("smoke test failed: %s" % locate(starts, result["msg"]))
    lines = []
    count = 0
    for i in range(1, len(result["modes"]) + 1):
        row = result["modes"][i]
        count += 1
        if verbose:
            lines.append("  %-16s pages %d  controls %3d  layout %3d"
                         % (row["mode"], row["pages"], row["controls"], row["layout"]))
    head = "smoke: %d modes passed GetProperties / GetPages / GetControls / GetControlLayout" % count
    return "\n".join([head] + lines)


# ------------------------------------------------------------------ main

def build(src_dir, out_path, check_only, verbose):
    files = source_files(src_dir)
    problems = []
    for path in files:
        text = read_text(path)
        problems.extend(check_header(path, text))
        problems.extend(check_ascii(path, text))
        if verbose:
            print("  %s (%d lines)" % (os.path.basename(path), text.count("\n")))
    if problems:
        raise BuildError("\n".join(problems))
    source, starts = assemble(files)
    print(compile_and_smoke(source, starts, verbose))
    if check_only:
        print("check only: %d files, %d bytes, nothing written" % (len(files), len(source)))
        return
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(source)
    print("wrote %s (%d files, %d lines, %d bytes)"
          % (os.path.relpath(out_path, REPO), len(files), source.count("\n"), len(source)))


def main(argv):
    ap = argparse.ArgumentParser(description="Build the Touch Pad plugin from src/touchpad.")
    ap.add_argument("--src", default=DEFAULT_SRC, help="source directory (default src/touchpad)")
    ap.add_argument("--out", default=DEFAULT_OUT, help="output .qplug path")
    ap.add_argument("--check", action="store_true", help="run every check but write nothing")
    ap.add_argument("--selftest", action="store_true", help="test the ASCII checker on probe sources only")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args(argv)
    if args.selftest:
        failures = selftest()
        for line in failures:
            print("SELFTEST FAILED " + line, file=sys.stderr)
        print("selftest: %d cases, %d failed" % (len(SELFTEST_CASES), len(failures)))
        return 1 if failures else 0
    try:
        build(args.src, args.out, args.check, args.verbose)
    except BuildError as exc:
        print("BUILD FAILED\n" + str(exc), file=sys.stderr)
        return 1
    print("BUILD OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
