#!/usr/bin/env python3
# Nikita Visual Arts – nikitavisual.art
"""Print a PNG, JPG or SVG file as a base64 string ready for a Q-SYS graphics table.

Usage:
    python3 embed_image.py assets/brand/logo-icon.png [--name Icon] [--wrap 100]

Output is a Lua assignment such as:
    Icon = "iVBORw0KGgo...",
Paste it into the asset table at the top of the plugin and use it as
    table.insert(graphics, { Type = "Image", Image = NikitaAssets.Icon, Position = {16, 11}, Size = {26, 26} })
For an SVG file use Type = "Svg" instead.
"""
import argparse
import base64
import struct
import sys
from pathlib import Path


def png_size(data: bytes):
    if data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR":
        return struct.unpack(">II", data[16:24])
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file", type=Path)
    ap.add_argument("--name", default=None, help="Lua key name (default: file stem, capitalised)")
    ap.add_argument("--wrap", type=int, default=0, help="wrap the string every N characters using Lua concatenation")
    args = ap.parse_args()

    data = args.file.read_bytes()
    b64 = base64.b64encode(data).decode("ascii")
    name = args.name or args.file.stem.replace("-", "_").replace(" ", "_").capitalize()
    size = png_size(data)
    comment = f"-- {args.file.name}" + (f" ({size[0]}x{size[1]} PNG)" if size else "") + f", {len(data)} bytes"
    print(comment)
    if args.wrap and args.wrap > 0:
        parts = [b64[i:i + args.wrap] for i in range(0, len(b64), args.wrap)]
        print(f'{name} = "' + '"\n  .. "'.join(parts) + '",')
    else:
        print(f'{name} = "{b64}",')
    return 0


if __name__ == "__main__":
    sys.exit(main())
