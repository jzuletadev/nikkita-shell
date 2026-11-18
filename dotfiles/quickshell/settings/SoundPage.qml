// ~/nikita-shell/dotfiles/quickshell/settings/SoundPage.qml
// Outputs and inputs (panels/SoundPanel), and the volume of each app playing.
import QtQuick
import Quickshell.Services.Pipewire
import qs.common
import qs.panels
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    // Apps playing: PipeWire calls their streams "Stream/Output/Audio".
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio && n.properties["media.class"] === "Stream/Output/Audio")

    PwObjectTracker {
        objects: page.streams
    }

    Section {
        title: "Devices"
        padding: Theme.spaceL
        SoundPanel { width: parent.width }
    }

    Section {
        title: "Apps"
        Repeater {
            model: page.streams

            SettingRow {
                id: app
                required property var modelData
                readonly property var props: modelData.properties
                appIcon: props["application.icon-name"] || "audio-x-generic"
                title: props["application.name"] || modelData.description || modelData.name
                subtitle: props["media.name"] || ""

                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    flat: !app.modelData.audio.muted
                    active: app.modelData.audio.muted
                    tip: app.modelData.audio.muted ? "Unmute" : "Mute"
                    icon: Audio.icon(Math.round(app.modelData.audio.volume * 100), app.modelData.audio.muted)
                    iconSize: 14
                    onClicked: app.modelData.audio.muted = !app.modelData.audio.muted
                }
                HorizontalSlider {
                    width: 180
                    anchors.verticalCenter: parent.verticalCenter
                    value: Math.round(app.modelData.audio.volume * 100)
                    muted: app.modelData.audio.muted
                    onMoved: v => app.modelData.audio.volume = v / 100
                }
                StyledText {
                    width: 40
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(app.modelData.audio.volume * 100) + "%"
                    color: Theme.muted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.textSmall
                }
            }
        }
        StyledText {
            visible: page.streams.length === 0
            width: parent.width
            padding: Theme.spaceL
            text: "No app is playing sound right now."
            color: Theme.dim
        }
    }
}
