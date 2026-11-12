// ~/nikkita-shell/dotfiles/quickshell/common/VerticalSlider.qml
//
// The dock's volume and brightness bar. The wheel moves it in steps of 5; the right
// button emits `secondary` (mute).
import QtQuick
import qs.common

Item {
    id: slider

    property int value: 0                 // 0-100
    property bool muted: false
    property string icon: ""
    property int minimum: 0
    property string tip: ""             // Tip.qml
    property string tipSide: ""
    signal moved(int v)
    signal secondary

    implicitWidth: 24

    // The drawn value is animated; the incoming one is not.
    property real drawn: value
    Behavior on drawn {
        enabled: !zone.pressed
        NumberAnimation { duration: Theme.msNormal; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: width / 2
        color: Theme.card

        Rectangle {
            id: fillBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(width, parent.height * slider.drawn / 100)
            radius: width / 2
            color: slider.muted ? Theme.dim : Theme.accent
            Behavior on color { ColorAnimation { duration: Theme.msNormal } }
        }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spaceXs
            name: slider.icon
            size: 14
            color: slider.muted ? Theme.fg : Theme.accentText
        }
    }

    MouseArea {
        id: zone
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function valueAt(y) {
            return Math.max(slider.minimum, Math.min(100, Math.round((1 - y / height) * 100)));
        }
        onPressed: ev => {
            Tooltips.cancel(zone);
            if (ev.button === Qt.RightButton) {
                slider.secondary();
                return;
            }
            slider.moved(valueAt(ev.y));
        }
        onPositionChanged: ev => {
            if (pressed && (ev.buttons & Qt.LeftButton))
                slider.moved(valueAt(ev.y));
        }
        onWheel: ev => {
            Tooltips.cancel(zone);
            const step = ev.angleDelta.y > 0 ? 5 : -5;
            slider.moved(Math.max(slider.minimum, Math.min(100, slider.value + step)));
        }

        Tip {
            text: slider.tip
            side: slider.tipSide
        }
    }
}
