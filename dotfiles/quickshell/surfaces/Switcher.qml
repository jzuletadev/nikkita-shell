// ~/nikita-shell/dotfiles/quickshell/surfaces/Switcher.qml
//
// ALT+TAB's keyboard: an invisible surface that takes the keys while the switcher
// is open (services/WindowSwitch.qml), since the panels' surface never does. What
// you see is the workspace rail growing (Workspaces.qml). Letting go of ALT (or
// of the modifier you gave the shortcut) switches; arrows and TAB move; Enter
// switches; Escape or a click outside the rail cancels. The rail itself stays out
// of this surface's input, so its rows take clicks.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root

    property string screenName: ""

    visible: ShellState.switcherScreen === screenName
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nikita-switcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Everything but the rail (ShellState.switcherRail, kept by the rail).
    mask: Region {
        item: keys
        Region {
            readonly property rect r: ShellState.switcherRail
            x: r.x
            y: r.y
            width: r.width
            height: r.height
            intersection: Intersection.Subtract
        }
    }

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        // The modifier you held with TAB: ALT by default, whatever Settings →
        // Shortcuts gave it otherwise.
        Keys.onReleased: ev => {
            if ([Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control].indexOf(ev.key) >= 0) {
                WindowSwitch.commit();
                ev.accepted = true;
            }
        }
        Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Escape)
                WindowSwitch.cancel();
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter)
                WindowSwitch.commit();
            else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab)
                WindowSwitch.move(1);
            else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab)
                WindowSwitch.move(-1);
            else
                return;
            ev.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: WindowSwitch.cancel()
        }
    }
}
