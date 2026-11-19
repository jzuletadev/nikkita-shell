#!/usr/bin/env python3
# ~/nikita-shell/scripts/brand-assets.py
#
# The one-color logos the desktop draws (common/Logo.qml), made from the artwork in
# nikita-brand/svg. Run it again after changing that artwork.
#
#   assets/brand/hexagon.svg        the hexagon with the rocket cut out of it
#   assets/brand/rocket.svg         the rocket alone
#   *-small.svg                     without stars, stitches or exhaust, for under 32 px
import os
import re

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(REPO, "nikita-brand/svg/nikita-icon-dark.svg")
OUT = os.path.join(REPO, "assets/brand")
BODY_AREA = 3200   # the rocket's body and window are the only shapes above this


def box(d):
    n = [float(v) for v in re.findall(r"-?\d+\.?\d*", d)]
    xs, ys = n[0::2], n[1::2]
    return min(xs), min(ys), max(xs), max(ys)


def area(d):
    x0, y0, x1, y1 = box(d)
    return (x1 - x0) * (y1 - y0)


def save(name, around, *paths):
    x0, y0, x1, y1 = box(around)
    side = max(x1 - x0, y1 - y0) + 10
    left, top = (x0 + x1 - side) / 2, (y0 + y1 - side) / 2
    with open(os.path.join(OUT, name), "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{left:.1f} {top:.1f} {side:.1f} {side:.1f}">'
                f'<path fill="#000" fill-rule="evenodd" d="{" ".join(paths)}"/></svg>\n')


def main():
    paths = re.findall(r'<path [^>]*\bd="([^"]+)"', open(SOURCE).read())
    hexagon, rocket = paths[0], paths[1]
    shapes = ["M" + s.strip() for s in rocket.split("M") if s.strip()]
    body = " ".join(s for s in shapes if area(s) > BODY_AREA)
    os.makedirs(OUT, exist_ok=True)
    save("hexagon.svg", hexagon, hexagon, rocket)
    save("hexagon-small.svg", hexagon, hexagon, body)
    save("rocket.svg", rocket, rocket)
    save("rocket-small.svg", body, body)


main()
