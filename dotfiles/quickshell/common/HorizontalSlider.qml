// ~/nikita-shell/dotfiles/quickshell/common/HorizontalSlider.qml
// A horizontal 0-100 bar you drag or click. No mouse wheel: these sit in pages that
// scroll, and a wheel passing over one would change it by accident.
import QtQuick
import qs.common

Item {
    id: d

    property int value: 0
    property bool muted: false
    signal moved(int v)

    implicitHeight: 20

    // The keyboard: Left and Right move it by 5, Home and End go to the ends.
    // Up and Down are left to the page, to move on to the next control.
    activeFocusOnTab: true
    Keys.onPressed: ev => {
        const step = ev.key === Qt.Key_Left ? -5 : ev.key === Qt.Key_Right ? 5 : 0;
        if (step !== 0)
            d.moved(Math.max(0, Math.min(100, d.value + step)));
        else if (ev.key === Qt.Key_Home)
            d.moved(0);
        else if (ev.key === Qt.Key_End)
            d.moved(100);
        else
            return;
        ev.accepted = true;
    }
    FocusRing { radius: Theme.radiusS }

    property real drawn: value
    Behavior on drawn {
        enabled: !zone.pressed
        NumberAnimation { duration: Theme.msFast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: height / 2
        color: Theme.cardHover
        Rectangle {
            height: parent.height
            radius: height / 2
            width: parent.width * d.drawn / 100
            color: d.muted ? Theme.faint : Theme.accent
        }
    }
    Rectangle {
        width: 16
        height: 16
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width - width) * d.drawn / 100
        color: d.muted ? Theme.muted : Theme.accent
        border.width: 3
        border.color: Theme.panel
        scale: zone.pressed ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Theme.msFast } }
    }
    MouseArea {
        id: zone
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function valueAt(x) {
            return Math.max(0, Math.min(100, Math.round(100 * x / width)));
        }
        onPressed: ev => d.moved(valueAt(ev.x))
        onPositionChanged: ev => {
            if (pressed)
                d.moved(valueAt(ev.x));
        }
    }
}
