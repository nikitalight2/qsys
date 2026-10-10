#!/usr/bin/env python3
# Nikita Visual Arts – nikitavisual.art
"""Push, fetch or list Lua scripts on a Q-SYS Core (or Designer emulation) over QRC.

QRC is the Q-SYS Remote Control protocol: JSON-RPC 2.0 over TCP port 1710,
one object per message, each terminated by a NUL byte.

Usage:
    qrc_deploy.py --host HOST [--port 1710] [--user U] [--password P] [--timeout S] list
    qrc_deploy.py --host HOST ... get  COMPONENT [--out file.lua]
    qrc_deploy.py --host HOST ... push COMPONENT file.lua [--force]

`push` refuses a component whose Type is not a script component unless
--force is given. The password can also come from the QSYS_PASSWORD
environment variable so it never has to be written into a file.
"""
import argparse
import json
import os
import socket
import sys

SCRIPT_TYPES = {"device_controller_script", "control_script_2", "scriptable_controls", "device_controller_proxy"}


class Qrc:
    def __init__(self, host, port=1710, timeout=10.0):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.buf = b""
        self.next_id = 1

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass

    def _read_message(self):
        while b"\0" not in self.buf:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("connection closed by the Core")
            self.buf += chunk
        raw, self.buf = self.buf.split(b"\0", 1)
        return json.loads(raw.decode("utf-8"))

    def call(self, method, params=None):
        msg_id = self.next_id
        self.next_id += 1
        payload = {"jsonrpc": "2.0", "method": method, "id": msg_id}
        if params is not None:
            payload["params"] = params
        self.sock.sendall(json.dumps(payload).encode("utf-8") + b"\0")
        while True:
            msg = self._read_message()
            if msg.get("id") == msg_id:
                if "error" in msg:
                    err = msg["error"]
                    raise RuntimeError(f"{method}: {err.get('message', err)} (code {err.get('code')})")
                return msg.get("result")
            # Unsolicited messages (EngineStatus and the like) are ignored.

    def logon(self, user, password):
        return self.call("Logon", {"User": user, "Password": password})

    def components(self):
        result = self.call("Component.GetComponents")
        if isinstance(result, dict) and "Components" in result:
            return result["Components"]
        return result or []

    def get_code(self, name):
        result = self.call("Component.Get", {"Name": name, "Controls": ["code"]})
        for c in (result or {}).get("Controls", []):
            if c.get("Name") == "code":
                return c.get("Value", "") or ""
        raise RuntimeError(f"component {name!r} returned no `code` control")

    def set_code(self, name, code):
        return self.call("Component.Set", {"Name": name, "Controls": [{"Name": "code", "Value": code}]})


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", type=int, default=1710)
    ap.add_argument("--user")
    ap.add_argument("--password", default=os.environ.get("QSYS_PASSWORD"))
    ap.add_argument("--timeout", type=float, default=10.0)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list", help="list components and their types")
    g = sub.add_parser("get", help="print a component's script")
    g.add_argument("component")
    g.add_argument("--out", help="write the script to this file instead of stdout")
    p = sub.add_parser("push", help="write a Lua file into a script component")
    p.add_argument("component")
    p.add_argument("file")
    p.add_argument("--force", action="store_true", help="push even if the component type is not a known script type")
    args = ap.parse_args()

    try:
        qrc = Qrc(args.host, args.port, args.timeout)
    except OSError as e:
        print(f"cannot connect to {args.host}:{args.port}: {e}", file=sys.stderr)
        return 2
    try:
        if args.user:
            qrc.logon(args.user, args.password or "")
        if args.cmd == "list":
            comps = qrc.components()
            width = max((len(c.get("Name", "")) for c in comps), default=4)
            for c in sorted(comps, key=lambda c: c.get("Name", "")):
                mark = "*" if c.get("Type") in SCRIPT_TYPES else " "
                print(f"{mark} {c.get('Name',''):<{width}}  {c.get('Type','')}")
            print(f"\n{len(comps)} components; * = script component (code can be pushed)")
        elif args.cmd == "get":
            code = qrc.get_code(args.component)
            if args.out:
                with open(args.out, "w", encoding="utf-8") as fh:
                    fh.write(code)
                print(f"wrote {len(code)} characters to {args.out}")
            else:
                sys.stdout.write(code)
        elif args.cmd == "push":
            with open(args.file, encoding="utf-8") as fh:
                code = fh.read()
            types = {c.get("Name"): c.get("Type") for c in qrc.components()}
            if args.component not in types:
                print(f"no component named {args.component!r} on {args.host}", file=sys.stderr)
                return 1
            if types[args.component] not in SCRIPT_TYPES and not args.force:
                print(f"{args.component!r} is a {types[args.component]!r}, not a script component; use --force to push anyway",
                      file=sys.stderr)
                return 1
            qrc.set_code(args.component, code)
            print(f"pushed {len(code)} characters from {args.file} to {args.component!r} on {args.host}")
        return 0
    except (RuntimeError, ConnectionError, OSError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    finally:
        qrc.close()


if __name__ == "__main__":
    sys.exit(main())
