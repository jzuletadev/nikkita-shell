#!/usr/bin/env python3
# ~/nikkita-shell/tests/click.py
#
# A real left click (or a turn of the wheel) at (X, Y) on the running desktop, for
# trying a change by hand:
# a virtual pointer (zwlr_virtual_pointer_v1, which Hyprland offers), spoken in
# the raw Wayland protocol so it needs nothing installed. wtype only types, and
# warping the cursor with hyprctl isn't a click.
#
#   tests/click.py X Y                   a left click there (layout pixels)
#   tests/click.py X Y scroll N          the wheel instead: N notches down (-N: up)
#   tests/click.py X Y move              only move the pointer there
#   NIKKITA_LAYOUT=3840x1080                 the whole layout, if not 1920x1080
#
# It clicks whatever is there: aim at an empty workspace or a window of your own.
# usage: click.py X Y [WIDTH HEIGHT]
import os, socket, struct, sys, time

x, y = int(sys.argv[1]), int(sys.argv[2])
what = sys.argv[3] if len(sys.argv) > 3 else "click"
notches = int(sys.argv[4]) if what == "scroll" else 0
W, H = (int(v) for v in os.environ.get("NIKKITA_LAYOUT", "1920x1080").split("x"))
sock = socket.socket(socket.AF_UNIX)
sock.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ.get("WAYLAND_DISPLAY", "wayland-1")))
next_id = [2]
def new():
    i = next_id[0]; next_id[0] += 1; return i
def string(s):
    b = s.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * ((4 - len(b) % 4) % 4)
def send(obj, op, payload=b""):
    sock.sendall(struct.pack("<II", obj, ((8 + len(payload)) << 16) | op) + payload)
buf = b""
def events():
    global buf
    while len(buf) < 8 or len(buf) < 8 + (struct.unpack_from("<I", buf, 4)[0] >> 16) - 8:
        buf += sock.recv(65536)
    obj, word = struct.unpack_from("<II", buf)
    size = word >> 16
    msg, buf = buf[8:size], buf[size:]
    return obj, word & 0xffff, msg
def roundtrip(globals_):
    cb = new(); send(1, 0, struct.pack("<I", cb))
    while True:
        obj, op, msg = events()
        if obj == cb:
            return
        if obj == registry and op == 0:
            name, = struct.unpack_from("<I", msg)
            ln, = struct.unpack_from("<I", msg, 4)
            iface = msg[8:8 + ln - 1].decode()
            globals_[iface] = name
registry = new(); send(1, 1, struct.pack("<I", registry))
g = {}
roundtrip(g)
def bind(iface, version):
    i = new(); send(registry, 0, struct.pack("<I", g[iface]) + string(iface) + struct.pack("<II", version, i)); return i
seat = bind("wl_seat", 1)
mgr = bind("zwlr_virtual_pointer_manager_v1", 1)
ptr = new(); send(mgr, 0, struct.pack("<II", seat, ptr))
t = lambda: int(time.monotonic() * 1000) & 0xffffffff
send(ptr, 1, struct.pack("<IIIII", t(), x, y, W, H)); send(ptr, 4)          # motion_absolute, frame
roundtrip(g); time.sleep(0.15)
if what == "click":
    send(ptr, 2, struct.pack("<III", t(), 0x110, 1)); send(ptr, 4)          # BTN_LEFT down
    roundtrip(g); time.sleep(0.06)
    send(ptr, 2, struct.pack("<III", t(), 0x110, 0)); send(ptr, 4)          # up
    roundtrip(g); time.sleep(0.1)
elif what == "scroll":
    step = 1 if notches > 0 else -1
    for _ in range(abs(notches)):
        send(ptr, 5, struct.pack("<I", 0))                                  # axis_source: wheel
        send(ptr, 7, struct.pack("<IIii", t(), 0, step * 15 * 256, step))   # axis_discrete: vertical, 15 px, one notch
        send(ptr, 4)
        roundtrip(g); time.sleep(0.03)
send(ptr, 8); roundtrip(g)                                                  # destroy
