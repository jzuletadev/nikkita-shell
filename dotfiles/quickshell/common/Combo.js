// ~/nikkita-shell/dotfiles/quickshell/common/Combo.js
//
// Shortcuts as Hyprland writes them ("SUPER + SHIFT + Q"), for Settings → Shortcuts:
// turning a key press into one, comparing two, and showing one to people. Not
// "Keys": imported under that name it would hide QtQuick's own Keys.
.pragma library

// Qt.KeyboardModifier flags, in the order they are written.
const MODS = [[0x10000000, "SUPER"], [0x04000000, "CTRL"], [0x08000000, "ALT"], [0x02000000, "SHIFT"]];
// Qt.Key codes of keys that are modifiers themselves: not a shortcut yet.
const MODIFIER_KEYS = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000024, 0x01000025, 0x01000026,
                       0x01000053, 0x01000054, 0x01000055, 0x01000056, 0x01000057, 0x01000058, 0x01001103];
const MODIFIER_NAMES = /^(Shift|Control|Alt|Super|Meta|Hyper)_[LR]$|^ISO_Level\d_(Shift|Latch|Lock)$|^(Caps|Num|Scroll)_Lock$|^Mode_switch$/;
// Keys that make sense on their own: nothing you would type.
const ALONE = /^(XF86\w+|F\d+|Print|Pause|Menu|Help|Sys_Req)$/;

// Qt.Key → the key's XKB name, for when keymap.py's table has no answer.
function fromQt(key) {
    if ((key >= 0x41 && key <= 0x5a) || (key >= 0x30 && key <= 0x39))
        return String.fromCharCode(key).toLowerCase();
    if (key >= 0x01000030 && key <= 0x01000052)
        return "F" + (key - 0x01000030 + 1);
    const names = { 0x20: "space", 0x01000000: "Escape", 0x01000001: "Tab", 0x01000002: "Tab", 0x01000003: "BackSpace",
        0x01000004: "Return", 0x01000005: "KP_Enter", 0x01000006: "Insert", 0x01000007: "Delete", 0x01000008: "Pause",
        0x01000009: "Print", 0x01000010: "Home", 0x01000011: "End", 0x01000012: "Left", 0x01000013: "Up",
        0x01000014: "Right", 0x01000015: "Down", 0x01000016: "Prior", 0x01000017: "Next" };
    return names[key] || "";
}

// A key press as a shortcut. `keymap` is keymap.py's {code: name}; `code` the
// event's nativeScanCode. Returns:
//   null                      only modifiers so far: keep waiting
//   { keys: "SUPER + Q" }     a shortcut
//   { error: "..." }          a key that can't be one, and why
function capture(modifiers, key, code, keymap) {
    const name = (keymap && keymap[String(code)]) || fromQt(key) || (code > 0 ? "code:" + code : "");
    if (MODIFIER_KEYS.indexOf(key) >= 0 || MODIFIER_NAMES.test(name))
        return null;
    if (name === "")
        return { error: "That key has no name Hyprland knows." };
    const mods = MODS.filter(m => modifiers & m[0]).map(m => m[1]);
    const strong = mods.some(m => m !== "SHIFT");
    if (!strong && !ALONE.test(name))
        return { error: "Hold SUPER, CTRL or ALT with it: alone, that key couldn't be typed anymore." };
    return { keys: mods.concat([name.length === 1 ? name.toUpperCase() : name]).join(" + ") };
}

function parts(keys) {
    return (keys || "").split("+").map(p => p.trim()).filter(p => p !== "");
}

// The same shortcut whatever the order and case it was written in.
function normalize(keys) {
    const p = parts(keys);
    if (p.length === 0)
        return "";
    const key = p[p.length - 1].toLowerCase();
    const mods = p.slice(0, -1).map(m => m.toUpperCase()).map(m => m === "CONTROL" ? "CTRL" : m === "MOD4" || m === "WIN" ? "SUPER" : m);
    return MODS.map(m => m[1]).filter(m => mods.indexOf(m) >= 0).concat([key]).join("+");
}

function same(a, b) {
    return normalize(a) !== "" && normalize(a) === normalize(b);
}

// How a key is shown: "/" for slash, "Volume up" for XF86AudioRaiseVolume.
function keyLabel(k) {
    const names = { "slash": "/", "space": "Space", "return": "Enter", "kp_enter": "Enter (keypad)", "prior": "Page Up", "next": "Page Down",
        "backspace": "Backspace", "minus": "-", "equal": "=", "comma": ",", "period": ".", "semicolon": ";", "apostrophe": "'",
        "grave": "`", "backslash": "\\", "bracketleft": "[", "bracketright": "]", "ntilde": "Ñ",
        "mouse:272": "Left drag", "mouse:273": "Right drag", "super_l": "tap",
        "xf86audioraisevolume": "Volume up key", "xf86audiolowervolume": "Volume down key", "xf86audiomute": "Mute key",
        "xf86audioplay": "Play key", "xf86audiopause": "Pause key", "xf86audionext": "Next key", "xf86audioprev": "Previous key",
        "xf86monbrightnessup": "Brightness up key", "xf86monbrightnessdown": "Brightness down key",
        "xf86kbdbrightnessup": "Keyboard light up key", "xf86kbdbrightnessdown": "Keyboard light down key" };
    const known = names[k.toLowerCase()];
    if (known)
        return known;
    if (k.length === 1)
        return k.toUpperCase();
    if (/^XF86/i.test(k))
        return k.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2") + " key";
    return k.charAt(0).toUpperCase() + k.slice(1);
}

// "SUPER + SHIFT + slash" → "SUPER + SHIFT + /"; "" → "".
function label(keys) {
    const p = parts(keys);
    if (p.length === 0)
        return "";
    return p.slice(0, -1).map(m => m.toUpperCase()).concat([keyLabel(p[p.length - 1])]).join(" + ");
}
