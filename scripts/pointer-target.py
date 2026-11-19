#!/usr/bin/env python3
# ~/nikita-shell/scripts/pointer-target.py
#
# Prints the address of the window under the pointer (the one in front, on the
# workspace showing on that monitor), or nothing if the pointer is over the bare
# desktop, or "self" when the window in front is Settings itself. Settings uses it to
# tell "clicked another window" from "clicked nothing" (or from the focus moving by
# itself, when windows come back).
import json
import subprocess


def hypr(what):
    out = subprocess.run(["hyprctl", what, "-j"], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


cursor = hypr("cursorpos")
x, y = cursor["x"], cursor["y"]
monitor = next((m for m in hypr("monitors")
                if m["x"] <= x < m["x"] + m["width"] / m["scale"] and m["y"] <= y < m["y"] + m["height"] / m["scale"]), None)
if monitor is None:
    raise SystemExit(0)
shown = monitor["activeWorkspace"]["id"]
under = [c for c in hypr("clients")
         if c["mapped"] and not c["hidden"] and c["workspace"]["id"] == shown
         and c["at"][0] <= x < c["at"][0] + c["size"][0] and c["at"][1] <= y < c["at"][1] + c["size"][1]]
# In front: floating over tiled, then the most recently focused.
under.sort(key=lambda c: (not c["floating"], c["focusHistoryID"]))
if under:
    print("self" if under[0]["title"] == "Settings" else under[0]["address"])
