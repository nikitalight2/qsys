#!/usr/bin/env python3
# Nikita Visual Arts – nikitavisual.art
# Touch Pad for Q-SYS: offline test runner
"""Runs the harness scenario tests and the plugin layout lint.

    python3 tools/touchpad/harness/run_tests.py            # everything
    python3 tools/touchpad/harness/run_tests.py -k tap     # tests whose name contains "tap"
    python3 tools/touchpad/harness/run_tests.py tests/test_harness.py -v
    python3 tools/touchpad/harness/run_tests.py --no-lint  # skip the built-plugin lint

Discovers tests/test_*.py, imports each, runs every function named test_* in
file order and prints a table with the result and the instruction maxima of
every QSys instance the test created (max per handler apart from the load,
max per frame, the load dispatch itself). A
test fails when it raises, when a QSys instance breached a budget (120,000
instructions per handler, 60,000 per frame) or when a Lua callback raised an
error the plugin did not catch. A test that provokes those on purpose sets
`q.allow_budget = True` / `q.allow_errors = True` on the instance.

Before the tests, the built plugin (plugins/NikitaTouchPad.qplug, or --plugin)
is loaded once per mode in MODE_NAMES and `layout_lint` runs GetPages,
GetControls and GetControlLayout for every page and every property set in
LINT_MATRIX. Lint problems are failures. A plugin without the framework
functions yet is reported and skipped.

Exit code 1 on any failure or budget breach.
"""
import argparse
import importlib.util
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)

from harness import qsys_fake  # noqa: E402
from harness.qsys_fake import (  # noqa: E402
    QSys, BudgetError, DEFAULT_PLUGIN, HANDLER_BUDGET, FRAME_BUDGET, plugin_has_framework, plugin_modes,
)

# Property sets the lint runs for every mode (unknown names are skipped per mode).
LINT_MATRIX = [
    {},
    {"Pad Width": 120, "Pad Height": 120},
    {"Pad Width": 1600, "Pad Height": 1200},
    {"Camera Control": "Demo (simulated)"},
    {"Camera Control": "VISCA over IP"},
    {"Zones": 32, "Sources": 64, "Destinations": 64},
    {"Zones": 1, "Sources": 1, "Destinations": 1},
    {"Background": "Transparent", "Theme": "Light"},
]


def discover(tests_dir, explicit):
    if explicit:
        return [os.path.abspath(p) for p in explicit]
    names = sorted(n for n in os.listdir(tests_dir) if n.startswith("test_") and n.endswith(".py"))
    return [os.path.join(tests_dir, n) for n in names]


def load_module(path):
    name = "harness_tests." + os.path.splitext(os.path.basename(path))[0]
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_functions(module):
    funcs = [(n, f) for n, f in vars(module).items() if n.startswith("test_") and callable(f)]
    funcs.sort(key=lambda nf: getattr(nf[1], "__code__", None) and nf[1].__code__.co_firstlineno or 0)
    return funcs


def run_one(fn):
    """Returns (ok, message, max_handler, max_frame, max_load, secs)."""
    qsys_fake.reset_registry()
    t0 = time.time()
    ok, message = True, ""
    try:
        fn()
    except BudgetError as exc:
        ok, message = False, "budget: %s" % exc
    except Exception:
        ok, message = False, traceback.format_exc().rstrip()
    instances = qsys_fake.active()
    max_handler = max_frame = max_load = 0
    for q in instances:
        try:
            b = q.budget(strict=False)
        except Exception as exc:  # a broken state is a failure too
            ok, message = False, "budget(): %s" % exc
            continue
        max_handler = max(max_handler, b["max_handler"])
        max_frame = max(max_frame, b["max_frame"])
        max_load = max(max_load, b["load"])
        if ok:
            over = [(k, v) for k, v in b["handlers"].items()
                    if (k.startswith("frame:") and v > FRAME_BUDGET) or (not k.startswith("frame:") and v > HANDLER_BUDGET)]
            if over and getattr(q, "allow_budget", False):
                over = []
            if over:
                ok, message = False, "budget breach: " + ", ".join("%s=%d" % kv for kv in sorted(over))
            elif q.errors and not getattr(q, "allow_errors", False):
                ok, message = False, "uncaught Lua error: %s" % q.errors[-1][1].splitlines()[0]
    for q in instances:
        q.close()
    return ok, message, max_handler, max_frame, max_load, time.time() - t0


def lint_plugin(path, verbose):
    """Returns (problems, note)."""
    if not os.path.exists(path):
        return [], "plugin not built (%s): lint skipped" % os.path.relpath(path, REPO)
    if not plugin_has_framework(path):
        return [], "plugin has no framework functions yet: lint skipped"
    modes = plugin_modes(path)
    problems = []
    for mode in modes:
        try:
            q = QSys(mode=mode, plugin=path, picker=None, runtime=False)
        except Exception as exc:
            problems.append("%s: cannot load: %s" % (mode, exc))
            continue
        names = {p["Name"] for p in [dict(spec.items()) for spec in qsys_fake._lua_list(q.G.GetProperties())]}
        matrix = [m for m in LINT_MATRIX if all(k in names for k in m)]
        found = q.layout_lint(matrix=matrix)
        if verbose:
            print("  lint %-16s %d property sets, %d problems" % (mode, len(matrix), len(found)))
        problems.extend(found)
        q.close()
    return problems, "lint: %d modes, %d property sets, %d problems" % (len(modes), len(LINT_MATRIX), len(problems))


def main(argv):
    ap = argparse.ArgumentParser(description="Run the Touch Pad harness tests")
    ap.add_argument("tests", nargs="*", help="test files (default: tests/test_*.py)")
    ap.add_argument("-k", dest="pattern", default="", help="only tests whose name contains this")
    ap.add_argument("-v", "--verbose", action="store_true", help="show tracebacks and lint detail")
    ap.add_argument("--plugin", default=DEFAULT_PLUGIN, help="plugin to lint (default plugins/NikitaTouchPad.qplug)")
    ap.add_argument("--no-lint", action="store_true", help="skip the plugin layout lint")
    ap.add_argument("--tests-dir", default=os.path.join(HERE, "tests"))
    args = ap.parse_args(argv)

    failures = 0
    if not args.no_lint:
        problems, note = lint_plugin(args.plugin, args.verbose)
        print(note)
        for p in problems:
            print("  LINT " + p)
        failures += len(problems)

    rows = []
    total = passed = 0
    for path in discover(args.tests_dir, args.tests):
        rel = os.path.relpath(path, REPO)
        try:
            module = load_module(path)
        except Exception:
            rows.append((rel, "<import>", False, "import failed:\n" + traceback.format_exc().rstrip(), 0, 0, 0, 0.0))
            failures += 1
            continue
        for name, fn in test_functions(module):
            if args.pattern and args.pattern not in name:
                continue
            total += 1
            ok, message, mh, mf, ml, secs = run_one(fn)
            if ok:
                passed += 1
            else:
                failures += 1
            rows.append((rel, name, ok, message, mh, mf, ml, secs))

    print()
    print("%-5s %-44s %9s %9s %9s %6s" % ("", "test", "handler", "frame", "load", "secs"))
    for rel, name, ok, message, mh, mf, ml, secs in rows:
        print("%-5s %-44s %9d %9d %9d %6.2f" % ("PASS" if ok else "FAIL", name[:44], mh, mf, ml, secs))
        if not ok:
            text = message if args.verbose else message.splitlines()[-1] if message else ""
            print("      " + text.replace("\n", "\n      "))
    print()
    print("budgets: %d instructions per handler, %d per frame" % (HANDLER_BUDGET, FRAME_BUDGET))
    print("TOTAL: %d passed, %d failed, %d tests" % (passed, total - passed, total))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
