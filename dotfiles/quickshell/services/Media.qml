// ~/nikita-shell/dotfiles/quickshell/services/Media.qml
//
// What's playing: the local player (services/Music) and the MPRIS ones. Shown: the
// one playing, else the first, unless `cycle` picked another. playerctld is left
// out (it mirrors another player). Seek, shuffle and repeat go through here: the
// local player takes calls where MPRIS takes property writes.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: media

    readonly property var players: {
        const all = Mpris.players.values;
        const real = all.filter(p => !p.dbusName.includes("playerctld"));
        return (Music.active ? [Music.player] : []).concat(real.length > 0 ? real : all);
    }
    property var picked: null
    readonly property var player: picked !== null && players.includes(picked) ? picked : (players.find(p => p.isPlaying) ?? players[0] ?? null)
    // Something to show: a track, or at least a player playing.
    readonly property bool hasTrack: player !== null && ((player.trackTitle || "") !== "" || player.isPlaying)

    function cycle() {
        if (players.length < 2)
            return;
        picked = players[(players.indexOf(player) + 1) % players.length];
    }

    function seek(p, seconds) {
        if (!p)
            return;
        if (p.isLocal)
            Music.seek(seconds);
        else
            p.position = seconds;
    }
    function setShuffle(p, on) {
        if (!p)
            return;
        if (p.isLocal)
            Music.setShuffle(on);
        else
            p.shuffle = on;
    }
    function setLoop(p, state) {
        if (!p)
            return;
        if (p.isLocal)
            Music.setLoop(state);
        else
            p.loopState = state;
    }
    // The media keys, on the player shown.
    function control(what) {
        const p = player;
        if (!p)
            return;
        if (what === "next" && p.canGoNext)
            p.next();
        else if (what === "previous" && p.canGoPrevious)
            p.previous();
        else if (what === "play-pause" && p.canTogglePlaying)
            p.togglePlaying();
    }

    // 83 -> "1:23"; over an hour, "1:02:03".
    function time(s) {
        if (!s || s < 0 || !isFinite(s))
            return "0:00";
        s = Math.floor(s);
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    // The player's app icon, from its desktop entry ("" if it has none).
    function icon(p) {
        if (!p || !p.desktopEntry)
            return "";
        const e = DesktopEntries.byId(p.desktopEntry) ?? DesktopEntries.byId(p.desktopEntry.toLowerCase());
        return e ? e.icon : "";
    }
}
