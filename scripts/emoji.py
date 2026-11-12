#!/usr/bin/env python3
# ~/nikkita-shell/scripts/emoji.py
#
# The emoji the launcher offers (type ":" first): every single-character emoji
# the installed emoji font can draw, with its Unicode name. JSON on stdout:
# [["😀", "grinning face"], ...]. Flags, skin tones and joined emoji (families)
# are left out: they are sequences, not one character.

import json
import subprocess
import sys
import unicodedata

# Parts of sequences, not emoji on their own: regional indicators, skin tones,
# joiners, variation selectors, tags, keycap bases.
SKIP = [(0x1F1E6, 0x1F1FF), (0x1F3FB, 0x1F3FF), (0x200D, 0x200D), (0xFE00, 0xFE0F),
        (0x20E3, 0x20E3), (0xE0000, 0xE007F), (0x0000, 0x00FF)]


def font_chars():
    font = subprocess.run(["fc-match", "-f", "%{file}", "Noto Color Emoji"],
                          capture_output=True, text=True, check=True).stdout.strip()
    if "emoji" not in font.lower():
        sys.exit("No emoji font: sudo pacman -S noto-fonts-emoji")
    charset = subprocess.run(["fc-query", "-f", "%{charset}", font],
                             capture_output=True, text=True, check=True).stdout
    for part in charset.split():
        a, _, b = part.partition("-")
        yield from range(int(a, 16), int(b or a, 16) + 1)


def main():
    out = []
    for cp in font_chars():
        if any(a <= cp <= b for a, b in SKIP):
            continue
        name = unicodedata.name(chr(cp), "")
        if not name:
            continue
        # Below U+1F000 most are drawn as text unless asked for the emoji look.
        char = chr(cp) + ("️" if cp < 0x1F000 else "")
        out.append([char, name.lower()])
    json.dump(out, sys.stdout, ensure_ascii=False)


main()
