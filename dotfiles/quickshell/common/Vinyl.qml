// ~/nikita-shell/dotfiles/quickshell/common/Vinyl.qml
// A record for NowPlaying, with the cover as its label. It turns while `spinning`
// and stops where it is.
import QtQuick
import QtQuick.Effects
import qs.common

Item {
    id: v

    property string art: ""
    property bool spinning: false
    property int size: 96

    implicitWidth: size
    implicitHeight: size

    Item {
        id: disc
        anchors.fill: parent

        // A turn every 9 s; paused, it keeps its angle.
        FrameAnimation {
            running: v.visible && v.spinning
            onTriggered: disc.rotation = (disc.rotation + frameTime * 40) % 360
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#111111"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
        }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: v.size * (0.92 - index * 0.08)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.035 + index * 0.012)
            }
        }

        Item {
            id: label
            anchors.centerIn: parent
            width: Math.round(v.size * 0.56)
            height: width

            Image {
                id: cover
                anchors.fill: parent
                visible: false
                source: v.art
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(label.width * 2, label.height * 2)
                asynchronous: true
            }
            Rectangle {
                id: labelMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                visible: cover.status === Image.Ready
                source: cover
                maskEnabled: true
                maskSource: labelMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            Rectangle {
                anchors.fill: parent
                visible: cover.status !== Image.Ready
                radius: width / 2
                color: "#2a2a2a"
                Icon {
                    anchors.centerIn: parent
                    name: "audio-x-generic-symbolic"
                    size: Math.round(label.width * 0.36)
                    color: "#8a8a8a"
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(4, Math.round(v.size * 0.06))
            height: width
            radius: width / 2
            color: "#0b0b0b"
        }
    }

    // The light stays still while the record turns.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.12) }
        }
    }
}
