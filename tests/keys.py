#!/usr/bin/env python3
# ~/nikkita-shell/tests/keys.py
#
# Real key presses on a running desktop, for trying a change by hand: a virtual
# keyboard (zwp_virtual_keyboard_v1) spoken in the raw Wayland protocol, so it
# needs nothing installed. It loads the same key table a real keyboard has
# (xkbcli, the layout given) and sends the same key codes, so what receives them
# can't tell the difference: Settings → Shortcuts reads these presses as it
# would yours.
#
#   tests/keys.py SUPER+SHIFT+y          press and let go a combination
#   tests/keys.py Escape Return          several, one after another
#   tests/keys.py --type "kitty -e"      type text (what the layout has unshifted,
#                                        plus capitals and its shifted symbols)
#   tests/keys.py --hold 800 ALT+Tab     keep the last key's modifiers down 800 ms
#   NIKKITA_KEYS_LAYOUT=es                   the layout to load (default: us)
#
# Modifiers: SUPER, CTRL, ALT, SHIFT. Keys by their XKB name (q, 1, space, Tab,
# Left, XF86AudioMute), as scripts/keymap.py prints them.
#
# It types into whatever has the keyboard: aim it at a test instance
# (WAYLAND_DISPLAY) or a window of your own. Hyprland doesn't run its own
# shortcuts for a virtual keyboard; the window under it gets the keys.

import array
import os
import re
import socket
import struct
import subprocess
import sys
import time

MODS = {"SHIFT": (0, "Shift_L"), "CTRL": (2, "Control_L"), "ALT": (3, "Alt_L"), "SUPER": (6, "Super_L")}


def keymap(layout):
    text = subprocess.run(["xkbcli", "compile-keymap", "--layout", layout], capture_output=True, text=True, check=True).stdout
    codes = {name: int(code) for name, code in re.findall(r"<([^>]+)>\s*=\s*(\d+);", text)}
    plain, shifted = {}, {}
    for name, body in re.findall(r"key\s+<([^>]+)>\s*\{(.*?)\};", text, re.S):
        levels = re.search(r"\[([^\]]*)\]", re.sub(r"symbols\[[^\]]*\]\s*=", "", body))
        if not levels or name not in codes:
            continue
        syms = [s.strip() for s in levels.group(1).split(",")]
        plain.setdefault(syms[0], codes[name])
        if len(syms) > 1:
            shifted.setdefault(syms[1], codes[name])
    return text, plain, shifted


class Keyboard:
    def __init__(self, layout):
        self.text, self.plain, self.shifted = keymap(layout)
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ.get("WAYLAND_DISPLAY", "wayland-1")))
        self.next_id = 2
        self.buf = b""
        self.globals = {}
        self.registry = self.new()
        self.send(1, 1, struct.pack("<I", self.registry))
        self.roundtrip()
        seat = self.bind("wl_seat", 1)
        manager = self.bind("zwp_virtual_keyboard_manager_v1", 1)
        self.kb = self.new()
        self.send(manager, 0, struct.pack("<II", seat, self.kb))
        data = self.text.encode() + b"\0"
        fd = os.memfd_create("keymap")
        os.write(fd, data)
        # keymap(format = xkb_v1, fd, size): the fd travels beside the message.
        self.send(self.kb, 0, struct.pack("<II", 1, len(data)), fd)
        os.close(fd)
        self.roundtrip()
        self.mods = 0

    def new(self):
        self.next_id += 1
        return self.next_id - 1

    def send(self, obj, opcode, payload=b"", fd=None):
        msg = struct.pack("<II", obj, ((8 + len(payload)) << 16) | opcode) + payload
        if fd is None:
            self.sock.sendall(msg)
        else:
            self.sock.sendmsg([msg], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", [fd]))])

    def event(self):
        while len(self.buf) < 8 or len(self.buf) < (struct.unpack_from("<I", self.buf, 4)[0] >> 16):
            self.buf += self.sock.recv(65536)
        obj, word = struct.unpack_from("<II", self.buf)
        size = word >> 16
        msg, self.buf = self.buf[8:size], self.buf[size:]
        return obj, word & 0xFFFF, msg

    def roundtrip(self):
        callback = self.new()
        self.send(1, 0, struct.pack("<I", callback))
        while True:
            obj, opcode, msg = self.event()
            if obj == callback:
                return
            if obj == self.registry and opcode == 0:
                name, length = struct.unpack_from("<II", msg)
                self.globals[msg[8:8 + length - 1].decode()] = name

    def bind(self, interface, version):
        if interface not in self.globals:
            sys.exit(f"The compositor doesn't offer {interface}.")
        name = interface.encode() + b"\0"
        padded = name + b"\0" * ((4 - len(name) % 4) % 4)
        obj = self.new()
        self.send(self.registry, 0, struct.pack("<II", self.globals[interface], len(name)) + padded + struct.pack("<II", version, obj))
        return obj

    def now(self):
        return int(time.monotonic() * 1000) & 0xFFFFFFFF

    def key(self, code, down):
        # The protocol counts keys as evdev does: 8 below XKB's codes.
        self.send(self.kb, 1, struct.pack("<III", self.now(), code - 8, 1 if down else 0))
        self.roundtrip()
        time.sleep(0.02)

    def modifier(self, name, down):
        bit, key = MODS[name]
        self.key(self.plain[key], down)
        self.mods = self.mods | (1 << bit) if down else self.mods & ~(1 << bit)
        self.send(self.kb, 2, struct.pack("<IIII", self.mods, 0, 0, 0))
        self.roundtrip()

    def combo(self, spec, hold=0.0):
        parts = [p.strip() for p in spec.split("+") if p.strip()]
        mods, name = [p.upper() for p in parts[:-1]], parts[-1]
        for m in mods:
            if m not in MODS:
                sys.exit(f"{m} isn't a modifier this knows: {', '.join(MODS)}.")
        code = self.plain.get(name) or self.plain.get(name.lower())
        if code is None:
            sys.exit(f"The layout has no key named {name}.")
        for m in mods:
            self.modifier(m, True)
        self.key(code, True)
        self.key(code, False)
        time.sleep(hold)
        for m in reversed(mods):
            self.modifier(m, False)

    def type(self, text):
        names = {" ": "space", "-": "minus", ".": "period", ",": "comma", "/": "slash", ";": "semicolon", "'": "apostrophe",
                 "=": "equal", ":": "colon", "_": "underscore", "!": "exclam", "?": "question", "\"": "quotedbl", "\n": "Return"}
        for ch in text:
            name = names.get(ch, ch)
            if name in self.plain:
                self.key(self.plain[name], True)
                self.key(self.plain[name], False)
            elif name in self.shifted:
                self.modifier("SHIFT", True)
                self.key(self.shifted[name], True)
                self.key(self.shifted[name], False)
                self.modifier("SHIFT", False)
            else:
                sys.exit(f"The layout can't type {ch!r}.")

    def close(self):
        self.send(self.kb, 3)
        self.roundtrip()


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__ or "usage: keys.py [--hold MS] [--type TEXT] COMBO...")
    kb = Keyboard(os.environ.get("NIKKITA_KEYS_LAYOUT", "us"))
    hold = 0.0
    while args:
        a = args.pop(0)
        if a == "--hold":
            hold = int(args.pop(0)) / 1000
        elif a == "--type":
            kb.type(args.pop(0))
        else:
            kb.combo(a, hold)
            hold = 0.0
        time.sleep(0.05)
    kb.close()


main()
