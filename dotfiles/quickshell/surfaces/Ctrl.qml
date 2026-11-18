// ~/nikita-shell/dotfiles/quickshell/surfaces/Ctrl.qml

import QtQuick
import qs.common
import qs.services

EdgePanel {
    id: ctrl

    name: "ctrl"
    edge: "right"
    placement: "center"
    depth: m.rail + 8
    span: m.dock
    inset: 12

    onOpening: Brightness.refresh()

    Column {
        anchors.fill: parent
        spacing: Theme.spaceS

        readonly property real itemHeight: (height - spacing * 4 - 1 - 2 * 16) / (Brightness.available ? 2 : 1)

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.textSmall
            font.family: Theme.monoFamily
            color: Audio.muted ? Theme.dim : Theme.muted
            text: Audio.ready ? Audio.percent : "--"
        }
        VerticalSlider {
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.itemHeight
            value: Audio.percent
            muted: Audio.muted
            icon: Audio.icon(Audio.percent, Audio.muted)
            tip: (Audio.muted ? "Volume (muted)" : "Volume") + "\nRight click: mute"
            tipSide: "left"
            onMoved: v => Audio.setPercent(v)
            onSecondary: Audio.toggleMute()
        }

        Item { width: 1; height: 1 }

        StyledText {
            visible: Brightness.available
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.textSmall
            font.family: Theme.monoFamily
            color: Theme.muted
            text: Brightness.percent
        }
        VerticalSlider {
            visible: Brightness.available
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.itemHeight
            value: Brightness.percent
            minimum: 1
            icon: "display-brightness-symbolic"
            tip: "Brightness"
            tipSide: "left"
            onMoved: v => Brightness.setPercent(v)
        }
    }
}
