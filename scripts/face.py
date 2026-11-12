#!/usr/bin/env python3
# ~/nikkita-shell/scripts/face.py
#
# Your picture, ~/.face: the lock and login screens show it. Settings → Appearance
# runs it.
#
#   face.py choose     ask for an image (the desktop portal's file chooser), then set it
#   face.py set FILE   set FILE: turned upright, cropped to a square, 512 px, PNG
#   face.py remove     no picture: the screens show your initial
#
# Exit 0 done, 1 cancelled, 2 error (the reason on stderr). Then greeter-sync.sh
# copies it for the login screen.
import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, Gio, GLib  # noqa: E402

FACE = Path.home() / ".face"
SIZE = 512
SYNC = Path(__file__).resolve().parent / "greeter-sync.sh"


def choose():
    """The portal's OpenFile: the answer comes as a Response signal on a request object."""
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    token = f"nikkita_face_{os.getpid()}"
    sender = bus.get_unique_name()[1:].replace(".", "_")
    request = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
    loop = GLib.MainLoop()
    picked = []

    def on_response(_conn, _sender, _path, _iface, _signal, params):
        code, results = params.unpack()
        if code == 0:
            picked.extend(results.get("uris", []))
        loop.quit()

    # Subscribed before asking, or a fast answer could be missed.
    bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
                         request, None, Gio.DBusSignalFlags.NONE, on_response)
    options = {
        "handle_token": GLib.Variant("s", token),
        "modal": GLib.Variant("b", True),
        "filters": GLib.Variant("a(sa(us))", [("Images", [(1, "image/*")])]),
        "current_folder": GLib.Variant("ay", str(Path.home() / "Pictures").encode() + b"\0"),
    }
    bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                  "org.freedesktop.portal.FileChooser", "OpenFile",
                  GLib.Variant("(ssa{sv})", ("", "Choose your picture", options)),
                  None, Gio.DBusCallFlags.NONE, -1, None)
    loop.run()
    return unquote(urlparse(picked[0]).path) if picked else None


def set_face(src):
    image = GdkPixbuf.Pixbuf.new_from_file(src).apply_embedded_orientation()
    side = min(image.get_width(), image.get_height())
    square = image.new_subpixbuf((image.get_width() - side) // 2, (image.get_height() - side) // 2, side, side)
    square = square.scale_simple(SIZE, SIZE, GdkPixbuf.InterpType.HYPER)
    tmp = FACE.with_name(".face.new")
    square.savev(str(tmp), "png", [], [])
    tmp.replace(FACE)


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if what == "choose":
            src = choose()
            if not src:
                return 1
            set_face(src)
        elif what == "set" and len(sys.argv) == 3:
            set_face(sys.argv[2])
        elif what == "remove":
            FACE.unlink(missing_ok=True)
        else:
            print("usage: face.py choose | set FILE | remove", file=sys.stderr)
            return 2
    except GLib.Error as e:
        print(f"Couldn't use that image: {e.message}", file=sys.stderr)
        return 2
    subprocess.run([str(SYNC)], check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
