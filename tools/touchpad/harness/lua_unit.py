#!/usr/bin/env python3
"""Unit-test runner for the pure-Lua Touch Pad modules.

Loads the plugin source files (src/touchpad/*.lua, name order) into a fresh
Lua 5.3 state (lupa), injects a tiny assertion framework `T`, runs one test
file and reports pass/fail per `test_*` function.

    python3 tools/touchpad/harness/lua_unit.py tests/test_util.lua
    python3 tools/touchpad/harness/lua_unit.py --all
    python3 tools/touchpad/harness/lua_unit.py --all --src src/touchpad -v

Lua side (available to every test file):
    T.eq(a, b, msg)          a == b
    T.near(a, b, eps, msg)   |a - b| <= eps
    T.ok(cond, msg)          cond is truthy
    T.err(fn, msg)           fn() raises an error
    T.deq(a, b, msg)         arrays / tables equal (deep)
    T.instructions(fn)       VM instructions spent by fn()
Every global function named test_* runs in sorted order. A VM instruction
count is reported per test so the Core's per-callback budget can be watched.
"""
import argparse
import os
import sys

import lupa.lua53 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_SRC = os.path.join(REPO, "src", "touchpad")
DEFAULT_TESTS = os.path.join(HERE, "tests")
EN_DASH = "–".encode("utf-8")

FRAMEWORK = br"""
T = {}
T.__count = 0
local function fail(msg, detail)
  error({ unit = true, msg = (msg or "assertion") .. ": " .. detail }, 0)
end
local function show(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end
function T.eq(a, b, msg)
  T.__count = T.__count + 1
  if a ~= b then fail(msg, "expected " .. show(b) .. " got " .. show(a)) end
end
function T.near(a, b, eps, msg)
  T.__count = T.__count + 1
  if type(a) ~= "number" or type(b) ~= "number" or math.abs(a - b) > eps then
    fail(msg, "expected " .. show(b) .. " +- " .. tostring(eps) .. " got " .. show(a))
  end
end
function T.ok(cond, msg)
  T.__count = T.__count + 1
  if not cond then fail(msg, "condition is " .. show(cond)) end
end
function T.err(fn, msg)
  T.__count = T.__count + 1
  local ok = pcall(fn)
  if ok then fail(msg, "expected an error, none raised") end
end
local function deq(a, b, path)
  if type(a) ~= "table" or type(b) ~= "table" then
    if a ~= b then return path .. ": expected " .. show(b) .. " got " .. show(a) end
    return nil
  end
  for k, v in pairs(b) do
    local d = deq(a[k], v, path .. "." .. tostring(k))
    if d then return d end
  end
  for k in pairs(a) do
    if b[k] == nil then return path .. "." .. tostring(k) .. ": unexpected " .. show(a[k]) end
  end
  return nil
end
function T.deq(a, b, msg)
  T.__count = T.__count + 1
  local d = deq(a, b, "value")
  if d then fail(msg, d) end
end

-- VM instructions spent by fn (count hook, granularity 10); restores any outer hook
function T.instructions(fn)
  local h, m, c = debug.gethook()
  local ticks = 0
  debug.sethook(function() ticks = ticks + 1 end, "", 10)
  fn()
  debug.sethook(h, m, c)
  return ticks * 10
end

function __load_chunk(code, name)
  local f, e = load(code, "@" .. name)
  if not f then error(e, 0) end
  return f()
end

function __run_tests()
  local names = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and k:sub(1, 5) == "test_" and type(v) == "function" then
      names[#names + 1] = k
    end
  end
  table.sort(names)
  local results = {}
  for _, name in ipairs(names) do
    T.__count = 0
    local ticks = 0
    debug.sethook(function() ticks = ticks + 1 end, "", 1000)
    local ok, err = xpcall(_G[name], function(e)
      if type(e) == "table" and e.unit then return e.msg end
      return debug.traceback(tostring(e), 2)
    end)
    debug.sethook()
    results[#results + 1] = { name = name, ok = ok, err = ok and "" or tostring(err),
                              asserts = T.__count, instr = ticks * 1000 }
  end
  return results
end
"""


def lint_source(path):
    """Brand header on the first two lines; ASCII only except the en dash."""
    problems = []
    with open(path, "rb") as fh:
        data = fh.read()
    lines = data.split(b"\n")
    if len(lines) < 2 or lines[0] != b"-- Nikita Visual Arts " + EN_DASH + b" nikitavisual.art":
        problems.append("missing brand comment on line 1")
    if len(lines) < 2 or not lines[1].startswith(b"-- Touch Pad for Q-SYS: "):
        problems.append("missing module comment on line 2")
    stripped = data.replace(EN_DASH, b"-")
    for lineno, line in enumerate(stripped.split(b"\n"), 1):
        if any(b > 126 for b in line):
            problems.append("non-ASCII byte on line %d" % lineno)
            break
    return problems


def source_files(src_dir):
    names = sorted(n for n in os.listdir(src_dir) if n.endswith(".lua"))
    return [os.path.join(src_dir, n) for n in names]


def new_runtime(srcs):
    rt = lupa.LuaRuntime(encoding=None, unpack_returned_tuples=True)
    rt.execute(FRAMEWORK)
    load_chunk = rt.globals()[b"__load_chunk"]
    for path in srcs:
        with open(path, "rb") as fh:
            load_chunk(fh.read(), os.path.basename(path).encode())
    return rt


def run_file(test_path, srcs, verbose):
    rt = new_runtime(srcs)
    load_chunk = rt.globals()[b"__load_chunk"]
    with open(test_path, "rb") as fh:
        load_chunk(fh.read(), os.path.basename(test_path).encode())
    results = rt.globals()[b"__run_tests"]()
    passed = failed = asserts = 0
    max_instr = 0
    rows = []
    for i in range(1, len(results) + 1):
        r = results[i]
        name = r[b"name"].decode()
        ok = bool(r[b"ok"])
        asserts += int(r[b"asserts"])
        max_instr = max(max_instr, int(r[b"instr"]))
        if ok:
            passed += 1
            if verbose:
                rows.append("  PASS %-40s %4d asserts %8d instr" % (name, r[b"asserts"], r[b"instr"]))
        else:
            failed += 1
            rows.append("  FAIL %s\n       %s" % (name, r[b"err"].decode(errors="replace").replace("\n", "\n       ")))
    return passed, failed, asserts, max_instr, rows


def main():
    ap = argparse.ArgumentParser(description="Run Lua unit tests for the Touch Pad modules")
    ap.add_argument("tests", nargs="*", help="Lua test files (default: --all)")
    ap.add_argument("--all", action="store_true", help="run every tests/test_*.lua")
    ap.add_argument("--src", default=DEFAULT_SRC, help="directory with the plugin source files")
    ap.add_argument("--tests-dir", default=DEFAULT_TESTS, help="directory searched by --all")
    ap.add_argument("-v", "--verbose", action="store_true", help="list passing tests too")
    args = ap.parse_args()

    tests = list(args.tests)
    if args.all or not tests:
        tests += sorted(os.path.join(args.tests_dir, n) for n in os.listdir(args.tests_dir)
                        if n.startswith("test_") and n.endswith(".lua"))
    srcs = source_files(args.src)
    lint_failed = False
    for path in srcs:
        for p in lint_source(path):
            lint_failed = True
            print("LINT %s: %s" % (os.path.relpath(path, REPO), p))

    total_pass = total_fail = total_asserts = 0
    for test_path in tests:
        try:
            passed, failed, asserts, max_instr, rows = run_file(test_path, srcs, args.verbose)
        except Exception as exc:  # load error in a source or test file
            print("%s: ERROR %s" % (os.path.relpath(test_path, REPO), exc))
            total_fail += 1
            continue
        print("%s: %d passed, %d failed, %d assertions, max %d instr/test"
              % (os.path.relpath(test_path, REPO), passed, failed, asserts, max_instr))
        for row in rows:
            print(row)
        total_pass += passed
        total_fail += failed
        total_asserts += asserts
    print("TOTAL: %d passed, %d failed, %d assertions, %d files"
          % (total_pass, total_fail, total_asserts, len(tests)))
    sys.exit(1 if (total_fail or lint_failed) else 0)


if __name__ == "__main__":
    main()
