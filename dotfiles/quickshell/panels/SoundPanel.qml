// ~/nikita-shell/dotfiles/quickshell/panels/SoundPanel.qml
//
// Audio outputs and inputs. PipeWire lists every HDMI output of the GPU, even with
// no monitor, and switching to one fails silently: only pactl knows a port is
// "not available", so it is asked on open and those are hidden.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.common
import qs.services

Item {
    id: sound

    implicitHeight: col.implicitHeight

    property var unavailable: []

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && unavailable.indexOf(n.name) < 0)
    readonly property var outputs: nodes.filter(n => n.isSink)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.name.endsWith(".monitor"))

    PwObjectTracker {
        objects: sound.nodes
    }

    function displayName(n) {
        return n.description || n.nickname || n.name;
    }

    Component.onCompleted: pactl.running = true

    Process {
        id: pactl
        command: ["sh", "-c", "pactl -f json list sinks; echo; pactl -f json list sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                const missing = [];
                for (const line of text.split("\n")) {
                    if (!line.trim())
                        continue;
                    try {
                        for (const d of JSON.parse(line)) {
                            const p = (d.ports || []).find(x => x.name === d.active_port);
                            if (p && p.availability === "not available")
                                missing.push(d.name);
                        }
                    } catch (e) {
                        console.warn("sound: can't read pactl's output:", e);
                    }
                }
                sound.unavailable = missing;
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.spaceS

        Repeater {
            model: [
                { title: "Output", node: Pipewire.defaultAudioSink, icon: Audio.icon(Audio.percent, Audio.muted) },
                { title: "Microphone", node: Pipewire.defaultAudioSource, icon: Audio.micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic" }
            ]
            Row {
                required property var modelData
                visible: modelData.node !== null && modelData.node.audio !== null
                width: col.width
                height: 34
                spacing: Theme.spaceM
                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    icon: parent.modelData.icon
                    active: parent.modelData.node !== null && parent.modelData.node.audio !== null && parent.modelData.node.audio.muted
                    tip: active ? "Unmute" : "Mute"
                    onClicked: parent.modelData.node.audio.muted = !parent.modelData.node.audio.muted
                }
                HorizontalSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 32 - 40 - 2 * parent.spacing
                    value: parent.modelData.node && parent.modelData.node.audio ? Math.round(parent.modelData.node.audio.volume * 100) : 0
                    muted: parent.modelData.node && parent.modelData.node.audio ? parent.modelData.node.audio.muted : false
                    onMoved: v => parent.modelData.node.audio.volume = v / 100
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: parent.modelData.node && parent.modelData.node.audio ? Math.round(parent.modelData.node.audio.volume * 100) + "%" : ""
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.textSmall
                    color: Theme.muted
                }
            }
        }

        StyledText { text: "Outputs"; color: Theme.muted; font.pixelSize: Theme.textSmall; font.weight: Font.Medium; topPadding: Theme.spaceXs }
        Repeater {
            model: sound.outputs
            ListRow {
                required property var modelData
                width: col.width
                icon: "audio-speakers-symbolic"
                title: sound.displayName(modelData)
                active: Pipewire.defaultAudioSink === modelData
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        StyledText { text: "Inputs"; color: Theme.muted; font.pixelSize: Theme.textSmall; font.weight: Font.Medium; topPadding: Theme.spaceXs }
        Repeater {
            model: sound.inputs
            ListRow {
                required property var modelData
                width: col.width
                icon: "audio-input-microphone-symbolic"
                title: sound.displayName(modelData)
                active: Pipewire.defaultAudioSource === modelData
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }
}
