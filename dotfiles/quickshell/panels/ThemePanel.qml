// ~/nikkita-shell/dotfiles/quickshell/panels/ThemePanel.qml
//
// Dark or light, applied by scripts/theme-manager.sh.
import QtQuick
import Quickshell
import qs.common
import qs.services

Item {
    id: themes

    implicitHeight: col.implicitHeight

    readonly property var options: [
        { id: "dark", title: "Dark", base: Theme.darkBase },
        { id: "light", title: "Light", base: Theme.lightBase }
    ]

    function apply(id) {
        Commands.run([Paths.script("theme-manager.sh"), id], "Switching the theme");
    }


    Column {
        id: col
        width: parent.width
        spacing: Theme.spaceM

        Row {
            id: samples
            spacing: Theme.spaceM

            Repeater {
                model: themes.options

                MouseArea {
                    id: op
                    required property var modelData
                    readonly property bool active: (modelData.id === "dark") === Theme.dark

                    width: (col.width - samples.spacing) / 2
                    height: 112
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: themes.apply(modelData.id)

                    // The sample uses ITS theme's colors, not the current ones.
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusM
                        color: op.modelData.base.bg
                        border.width: op.active ? 2 : 1
                        border.color: op.active ? Theme.accent : (op.containsMouse ? Theme.muted : Theme.divider)
                        Behavior on border.color { ColorAnimation { duration: Theme.msFast } }

                        Column {
                            x: 14
                            y: 14
                            spacing: Theme.spaceS
                            Rectangle { width: 40; height: 8; radius: height / 2; color: op.modelData.base.fg }
                            Rectangle { width: 64; height: 6; radius: height / 2; color: op.modelData.base.fg; opacity: 0.45 }
                            Rectangle { width: 50; height: 6; radius: height / 2; color: op.modelData.base.fg; opacity: 0.25 }
                        }

                        StyledText {
                            x: 14
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.spaceM
                            text: op.modelData.title
                            color: op.modelData.base.fg
                            font.weight: Font.DemiBold
                        }

                        Icon {
                            visible: op.active
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Theme.spaceM
                            name: "object-select-symbolic"
                            size: 16
                            color: op.modelData.base.fg
                        }
                    }
                }
            }
        }

        StyledText {
            width: col.width
            wrapMode: Text.WordWrap
            text: "Applies at once to the desktop, kitty and GNOME's apps (files, images, video); older GTK3 apps when they reopen."
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
    }
}
