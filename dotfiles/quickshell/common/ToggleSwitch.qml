// ~/nikkita-shell/dotfiles/quickshell/common/ToggleSwitch.qml
// An on/off switch with a sliding knob.
import QtQuick
import qs.common

Rectangle {
    id: sw

    property bool checked: false
    signal toggled

    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2
    color: checked ? Theme.accent : Theme.cardHover
    Behavior on color { ColorAnimation { duration: Theme.msFast } }

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
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
