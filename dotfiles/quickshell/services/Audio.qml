// ~/nikkita-shell/dotfiles/quickshell/services/Audio.qml
//
// Volume of the default output, from PipeWire. Raising it does NOT unmute (two
// separate actions), and it caps at 100 % (above, it distorts).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: audio

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property int percent: Math.round(volume * 100)
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    // Without this PipeWire doesn't send volume changes for these nodes.
    PwObjectTracker {
        objects: [audio.sink, audio.source]
    }

    function setPercent(p) {
        if (!ready)
            return;
        sink.audio.volume = Math.max(0, Math.min(100, Math.round(p))) / 100;
    }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    // up | down | mute | N (0-100). Steps land on multiples of 5.
    function adjust(arg) {
        if (arg === "up")
            setPercent(Math.floor(percent / 5) * 5 + 5);
        else if (arg === "down")
            setPercent(Math.ceil(percent / 5) * 5 - 5);
        else if (arg === "mute")
            toggleMute();
        else if (!isNaN(parseInt(arg)))
            setPercent(parseInt(arg));
    }

    function icon(p, m) {
        if (m || p === 0)
            return "audio-volume-muted-symbolic";
        if (p < 34)
            return "audio-volume-low-symbolic";
        if (p < 67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }
}
