#!/usr/bin/env python3
# ~/nikita-shell/scripts/xkb-layouts.py
#
# Every keyboard layout XKB knows, with its variants, for Settings → Keyboard.
# JSON on stdout: [{"layout": "es", "variant": "", "name": "Spanish"},
# {"layout": "es", "variant": "dvorak", "name": "Spanish (Dvorak)"}, ...]

import json
import sys
from pathlib import Path

RULES = Path("/usr/share/X11/xkb/rules/evdev.lst")


def main():
    if not RULES.exists():
        sys.exit(f"{RULES} is missing: sudo pacman -S xkeyboard-config")
    section, out = "", []
    for line in RULES.read_text(errors="replace").splitlines():
        if line.startswith("!"):
            section = line[1:].strip()
            continue
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        if section == "layout":
            out.append({"layout": parts[0], "variant": "", "name": parts[1].strip()})
        elif section == "variant":
            # "dvorak          es: Spanish (Dvorak)"
            layout, _, name = parts[1].partition(":")
            out.append({"layout": layout.strip(), "variant": parts[0], "name": name.strip()})
    out.sort(key=lambda x: (x["name"].lower()))
    json.dump(out, sys.stdout, ensure_ascii=False)


main()
