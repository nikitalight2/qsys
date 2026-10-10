<!-- Nikita Visual Arts – nikitavisual.art -->

# Deploying and testing Q-SYS Lua

Two different things get tested, and they go to the Core by different roads.

## 1. Plugins (.qplug) are installed, not deployed

Designer reads plugins from the plugin folder on the machine running
Designer. There is no remote API that installs a plugin on a Core.

1. Copy the file to `%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins`.
2. Restart Designer (it scans the folder at start).
3. Place the block, set its properties, press F5 to emulate, or push the
   design to a Core.

On every edit of a plugin that is already in a design, Designer notices the
changed file on the next open; the block in the design must be updated to the
new version from its Properties pane when the version changed.

## 2. Scripts can be pushed over QRC

Text Controller, Control Script, Scriptable Controls and Device Controller
Proxy components expose their Lua as a control named `code`, and the Q-SYS
Remote Control protocol (QRC) can write it while the design runs. That makes
a fast loop for the runtime half of a plugin: paste the runtime block into a
Text Controller in a test design and push edits without re-installing.

The component's Script Access must be set to External or All in Designer.

Protocol facts, confirmed from the "Q-SYS Lua Script Deployment" VS Code
extension source (github.com/White-Label-AV/qsys-deploy-vscode, MIT):

| Item | Value |
|---|---|
| Transport | TCP, port 1710, plain text |
| Framing | One JSON-RPC 2.0 object per message, terminated by a NUL byte (`\0`), no newline |
| Logon | `{"jsonrpc":"2.0","method":"Logon","params":{"User":"...","Password":"..."},"id":1}` (only when the Core has access control on) |
| List components | method `Component.GetComponents`, no params; result is an array of `{ Name, Type, ... }` |
| Write a script | method `Component.Set`, params `{ "Name": "<component>", "Controls": [ { "Name": "code", "Value": "<lua>" } ] }` |
| Read a script | method `Component.Get`, params `{ "Name": "<component>", "Controls": [ "code" ] }` |
| Keep-alive | method `NoOp` about once a minute on long-lived connections |
| Designer emulation | connect to `127.0.0.1` while Designer runs the design with F5 |
| Script component types | `device_controller_script`, `control_script_2`, `scriptable_controls`, `device_controller_proxy` |

`scripts/qrc_deploy.py` in this skill does these from the terminal with only
the Python standard library:

```bash
python3 scripts/qrc_deploy.py --host 192.168.1.100 list
python3 scripts/qrc_deploy.py --host 192.168.1.100 get  "MainController"
python3 scripts/qrc_deploy.py --host 192.168.1.100 push "MainController" scripts/main.lua
python3 scripts/qrc_deploy.py --host 127.0.0.1 --user admin --password secret push "Test" test.lua
```

Never put a Core password into a file that is committed; pass it on the
command line or read it from an environment variable. The script refuses to
push a file into a component whose `Type` is not a script component, so a
typo in the name cannot overwrite a mixer.

## 3. What to tell the user after testing

Say which of these actually happened, and which did not:

- Lua syntax check (`luac -p`) passed.
- `scripts/check_plugin.py` passed with these warnings.
- The runtime block was pushed to a Text Controller on a Core or in
  emulation and ran without errors (only if the user gave you a reachable
  host).
- The plugin was loaded in Designer (never true from this environment unless
  the user did it and reported back).
