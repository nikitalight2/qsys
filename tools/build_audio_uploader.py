#!/usr/bin/env python3
# Nikita Visual Arts – nikitavisual.art
#
# Builds the Audio File Uploader deliverables from their sources:
#   web/AudioUploader.template.html  ->  embedded in plugins/NikitaAudioUploader.qplug
#                                    ->  web/AudioUploader.html (standalone, logo inlined)
#   assets/brand/*.png               ->  NikitaAssets in the plugin
# Run from anywhere: python3 tools/build_audio_uploader.py
import base64
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLUGIN = ROOT / "plugins" / "NikitaAudioUploader.qplug"
TEMPLATE = ROOT / "web" / "AudioUploader.template.html"
STANDALONE = ROOT / "web" / "AudioUploader.html"
LOGO = ROOT / "assets" / "brand" / "logo-horizontal.png"
ICON = ROOT / "assets" / "brand" / "logo-icon.png"


def b64(path):
    return base64.b64encode(path.read_bytes()).decode("ascii")


def lua_long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    # A newline right after the opening bracket is dropped by Lua.
    return "[" + eq + "[\n" + text + "]" + eq + "]"


def replace_block(src, name, body):
    pattern = re.compile(r"(-- @@%s_BEGIN[^\n]*\n).*?(-- @@%s_END)" % (name, name), re.S)
    if not pattern.search(src):
        raise SystemExit("marker %s not found in %s" % (name, PLUGIN))
    return pattern.sub(lambda m: m.group(1) + body + "\n" + m.group(2), src, count=1)


def main():
    logo, icon = b64(LOGO), b64(ICON)
    page = TEMPLATE.read_text(encoding="utf-8")

    src = PLUGIN.read_text(encoding="utf-8")
    assets = (
        "NikitaAssets = {\n"
        "  -- 560x202 horizontal logo (PNG, base64)\n"
        '  Logo = "%s",\n'
        "  -- 128x130 icon mark (PNG, base64)\n"
        '  Icon = "%s",\n'
        "}" % (logo, icon)
    )
    src = replace_block(src, "ASSETS", assets)
    src = replace_block(src, "WEBPAGE", "WEB_PAGE = " + lua_long_string(page))
    PLUGIN.write_text(src, encoding="utf-8", newline="\n")

    STANDALONE.write_text(page.replace("{{LOGO}}", logo), encoding="utf-8", newline="\n")
    print("wrote", PLUGIN.relative_to(ROOT), "and", STANDALONE.relative_to(ROOT))


if __name__ == "__main__":
    main()
