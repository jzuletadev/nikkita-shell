#!/usr/bin/env python3
# ~/nikita-shell/scripts/keymap.py
#
# Which key is which, for Settings → Shortcuts: the name Hyprland knows each key
# by, per key code, in the first keyboard layout (Hyprland matches a shortcut's
# key against that layout's unshifted symbol: "1", not "!"). JSON on stdout:
# {"24": "q", "10": "1", "113": "Left", "123": "XF86AudioRaiseVolume", ...}.
#
#   keymap.py [LAYOUT [VARIANT [OPTIONS]]]      default: us

import json
import re
import subprocess
import sys


def main():
    layout, variant, options = (sys.argv[1:4] + ["", "", ""])[:3]
    argv = ["xkbcli", "compile-keymap", "--layout", layout or "us"]
    if variant:
        argv += ["--variant", variant]
    if options:
        argv += ["--options", options]
    try:
        keymap = subprocess.run(argv, capture_output=True, text=True, check=True).stdout
    except FileNotFoundError:
        sys.exit("xkbcli isn't installed: sudo pacman -S libxkbcommon")
    except subprocess.CalledProcessError as e:
        sys.exit((e.stderr or "").strip().splitlines()[-1] if e.stderr.strip() else "xkbcli failed")

    codes = {name: int(code) for name, code in re.findall(r"<([^>]+)>\s*=\s*(\d+);", keymap)}
    out = {}
    # key <AD01> { [ q, Q ] };   or   key <PRSC> { type= "...", symbols[1]= [ Print, Sys_Req ] };
    # The first list is the first layout's; its first symbol, the unshifted one.
    for name, body in re.findall(r"key\s+<([^>]+)>\s*\{(.*?)\};", keymap, re.S):
        first = re.search(r"\[\s*([A-Za-z0-9_]+)", re.sub(r"symbols\[[^\]]*\]\s*=", "", body))
        if first and name in codes and first.group(1) not in ("NoSymbol", "VoidSymbol"):
            out[str(codes[name])] = first.group(1)
    json.dump(out, sys.stdout)


main()
