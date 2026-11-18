// ~/nikita-shell/dotfiles/quickshell/common/Equalizer.qml
// Four bars that dance while something plays: a sign, not a meter.
import QtQuick
import qs.common

Row {
    id: eq

    property bool playing: false
    property color color: Theme.fg
    property int barHeight: 14

    height: barHeight
    spacing: Theme.spaceXxs

    Repeater {
        model: [430, 560, 380, 500]

        Rectangle {
            id: bar
            required property int modelData
            required property int index
            property real level: 0.25

            anchors.bottom: parent.bottom
            width: 3
            height: Math.round(eq.barHeight * (eq.playing ? level : 0.25))
            radius: width / 2
            color: eq.color

            SequentialAnimation on level {
                running: eq.playing && eq.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.55 + 0.11 * bar.index; duration: bar.modelData; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.25; duration: bar.modelData * 0.8; easing.type: Easing.InOutSine }
            }
            Behavior on height {
                enabled: !eq.playing
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }
}
