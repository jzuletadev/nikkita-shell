// ~/nikkita-shell/tests/qml/tst_combo.qml
//
// Shortcut capture and comparison (dotfiles/quickshell/common/Combo.js). Run with tests/run.sh.
import QtQuick
import QtTest
import "../../dotfiles/quickshell/common/Combo.js" as Combo

TestCase {
    name: "Combo"

    // What keymap.py gives for the US layout, in part.
    readonly property var us: ({ "24": "q", "10": "1", "65": "space", "61": "slash", "113": "Left", "36": "Return",
        "123": "XF86AudioRaiseVolume", "107": "Print", "67": "F1", "133": "Super_L", "50": "Shift_L", "64": "Alt_L", "23": "Tab" })
    readonly property int sup: Qt.MetaModifier
    readonly property int shift: Qt.ShiftModifier

    function test_a_plain_shortcut() {
        compare(Combo.capture(sup, Qt.Key_Q, 24, us).keys, "SUPER + Q");
        compare(Combo.capture(sup | Qt.ControlModifier | Qt.AltModifier | shift, Qt.Key_Q, 24, us).keys, "SUPER + CTRL + ALT + SHIFT + Q");
        compare(Combo.capture(Qt.AltModifier, Qt.Key_Tab, 23, us).keys, "ALT + Tab");
        compare(Combo.capture(sup, Qt.Key_Left, 113, us).keys, "SUPER + Left");
    }

    // Hyprland matches the unshifted symbol: SHIFT + 1 is "1", though Qt says "!".
    function test_shift_keeps_the_unshifted_key() {
        compare(Combo.capture(sup | shift, Qt.Key_Exclam, 10, us).keys, "SUPER + SHIFT + 1");
        compare(Combo.capture(sup | shift, Qt.Key_Question, 61, us).keys, "SUPER + SHIFT + slash");
    }

    function test_modifiers_alone_wait() {
        compare(Combo.capture(sup, Qt.Key_Meta, 133, us), null);
        compare(Combo.capture(sup, Qt.Key_Super_L, 133, us), null);
        compare(Combo.capture(shift, Qt.Key_Shift, 50, us), null);
        compare(Combo.capture(Qt.AltModifier, Qt.Key_Alt, 64, us), null);
        // The table knows it is a modifier even when Qt's code is something else.
        compare(Combo.capture(0, 0, 133, us), null);
    }

    function test_a_key_you_type_needs_a_modifier() {
        verify(Combo.capture(0, Qt.Key_Q, 24, us).error !== undefined);
        verify(Combo.capture(shift, Qt.Key_Q, 24, us).error !== undefined);
        compare(Combo.capture(0, Qt.Key_VolumeUp, 123, us).keys, "XF86AudioRaiseVolume");
        compare(Combo.capture(0, Qt.Key_Print, 107, us).keys, "Print");
        compare(Combo.capture(0, Qt.Key_F1, 67, us).keys, "F1");
    }

    function test_without_the_table() {
        compare(Combo.capture(sup, Qt.Key_Q, 24, null).keys, "SUPER + Q");
        compare(Combo.capture(sup, Qt.Key_Return, 36, ({})).keys, "SUPER + Return");
        compare(Combo.capture(sup, Qt.Key_F5, 71, null).keys, "SUPER + F5");
        compare(Combo.capture(sup, Qt.Key_Backtab, 23, null).keys, "SUPER + Tab");
        // No name at all: the key's code, which Hyprland also takes.
        compare(Combo.capture(sup, 0x01ffffff, 200, null).keys, "SUPER + code:200");
        verify(Combo.capture(sup, 0x01ffffff, 0, null).error !== undefined);
    }

    function test_same_shortcut_however_written() {
        verify(Combo.same("SUPER + SHIFT + Q", "SHIFT+super+q"));
        verify(Combo.same("SUPER + slash", "SUPER + Slash"));
        verify(Combo.same("CONTROL + ALT + T", "ALT + CTRL + t"));
        verify(!Combo.same("SUPER + Q", "SUPER + SHIFT + Q"));
        verify(!Combo.same("", ""));
        compare(Combo.normalize("XF86AudioMute"), "xf86audiomute");
    }

    function test_labels() {
        compare(Combo.label("SUPER + slash"), "SUPER + /");
        compare(Combo.label("SUPER + SHIFT + q"), "SUPER + SHIFT + Q");
        compare(Combo.label("XF86AudioRaiseVolume"), "Volume up key");
        compare(Combo.label("XF86Calculator"), "Calculator key");
        compare(Combo.label("SUPER + Super_L"), "SUPER + tap");
        compare(Combo.label("SUPER + mouse:272"), "SUPER + Left drag");
        compare(Combo.label("SUPER + Return"), "SUPER + Enter");
        compare(Combo.label(""), "");
    }
}
