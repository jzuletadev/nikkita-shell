// ~/nikita-shell/dotfiles/quickshell/common/ToggleSwitch.qml
// An on/off switch with a sliding knob.
import QtQuick
import qs.common

Rectangle {
    id: sw

    property bool checked: false
    signal toggled

    activeFocusOnTab: true
    Keys.onPressed: ev => {
        if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || ev.key === Qt.Key_Space) {
            sw.toggled();
            ev.accepted = true;
        }
    }
    FocusRing { inner: sw.radius }

    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2
    // The state rule (Theme): the pointer lightens it and draws a ring while off,
    // and dims it while on. It never looks like the other state.
    color: checked ? (area.containsMouse ? Theme.activeHover : Theme.accent)
                   : (area.containsMouse ? Theme.hoverFill : Theme.cardHover)
    Behavior on color { ColorAnimation { duration: Theme.msFast } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.hoverRing
        opacity: area.containsMouse && !sw.checked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.msFast } }
    }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: sw.checked ? sw.width - width - 3 : 3
        color: sw.checked ? Theme.accentText : Theme.muted
        Behavior on x { NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter } }
        Behavior on color { ColorAnimation { duration: Theme.msFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
