// ~/nikkita-shell/dotfiles/quickshell/services/Music.qml
//
// The local music player. Library and playlists (.m3u8 in ~/Music/Playlists) come
// from scripts/music-library.py; playback is an audio-only mpv driven through its
// JSON IPC socket, quit when the queue ends. `player` has MPRIS's properties, so
// services/Media treats it like any other player.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.common

Singleton {
    id: music

    property string root: Paths.music
    readonly property string script: Paths.script("music-library.py")
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string socketPath: runtime + "/nikkita-music.sock"
    readonly property string queuePath: runtime + "/nikkita-music-queue.m3u"

    // ======== the library ========
    property var songs: []
    property var playlists: []          // [{ name, file, songs: [path, ...] }]
    property bool scanned: false
    property bool scanning: false
    property string error: ""
    readonly property var byPath: {
        const m = {};
        for (const s of songs)
            m[s.path] = s;
        return m;
    }

    function scan() {
        if (scanning)
            return;
        scanning = true;
        scanProc.running = true;
    }
    Process {
        id: scanProc
        command: ["python3", music.script, "scan", music.root]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.error) {
                        music.error = d.error;
                    } else {
                        music.songs = d.songs;
                        music.playlists = d.playlists;
                        music.error = "";
                    }
                } catch (e) {
                    music.error = "Couldn't read the library.";
                }
                music.scanning = false;
                music.scanned = true;
            }
        }
    }

    // ---- playlists: every change rewrites the file, then the library is read again ----
    function playlist(name) {
        return playlists.find(p => p.name === name) ?? null;
    }
    function createPlaylist(name, paths) {
        edit(["save", name.trim()].concat(paths || []));
    }
    function addToPlaylist(name, path) {
        const p = playlist(name);
        if (!p || p.songs.includes(path))
            return;
        edit(["save", name].concat(p.songs, [path]));
    }
    function removeFromPlaylist(name, index) {
        const p = playlist(name);
        if (!p)
            return;
        const rest = p.songs.slice();
        rest.splice(index, 1);
        edit(["save", name].concat(rest));
    }
    function moveInPlaylist(name, from, to) {
        const p = playlist(name);
        if (!p || to < 0 || to >= p.songs.length)
            return;
        const order = p.songs.slice();
        order.splice(to, 0, order.splice(from, 1)[0]);
        edit(["save", name].concat(order));
    }
    function deletePlaylist(name) {
        edit(["delete", name]);
    }
    function renamePlaylist(from, to) {
        if (to.trim() !== "" && to.trim() !== from)
            edit(["rename", from, to.trim()]);
    }

    property var edits: []              // waiting their turn
    function edit(args) {
        edits = edits.concat([args]);
        if (!editProc.running)
            nextEdit();
    }
    function nextEdit() {
        if (edits.length === 0) {
            scan();
            return;
        }
        const args = edits[0];
        edits = edits.slice(1);
        editProc.command = ["python3", script, args[0], root].concat(args.slice(1));
        editProc.running = true;
    }
    Process {
        id: editProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.error)
                        music.error = d.error;
                } catch (e) {
                    music.error = "Couldn't change the playlist.";
                }
                music.nextEdit();
            }
        }
    }

    // ======== playback (mpv) ========
    property bool connected: false
    property bool paused: true
    property string path: ""
    property real duration: 0
    property real position: 0
    property int queuePos: -1
    property int queueCount: 0
    property bool shuffle: false
    property int loopState: MprisLoopState.None
    property var meta: ({})
    property bool hadSong: false
    property string queueName: ""       // what is playing: "Library" or a playlist's name

    readonly property bool active: mpv.running && connected && path !== ""
    readonly property var current: byPath[path] ?? null

    // Plays `paths` from `index` on. A temporary playlist file and mpv's
    // `playlist-start`: no flash of the first song before jumping.
    function play(paths, index, name) {
        if (!paths || paths.length === 0)
            return;
        queueName = name || "";
        queueFile.setText(paths.join("\n") + "\n");
        pending = [["set_property", "playlist-start", Math.max(0, index || 0)],
            ["loadlist", queuePath, "replace"],
            ["set_property", "pause", false],
            ["set_property", "loop-playlist", loopState === MprisLoopState.Playlist ? "inf" : "no"],
            ["set_property", "loop-file", loopState === MprisLoopState.Track ? "inf" : "no"]];
        shuffle = false;
        position = 0;
        if (connected)
            flush();
        else
            start();
    }
    function playShuffled(paths, name) {
        const order = paths.slice();
        for (let i = order.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [order[i], order[j]] = [order[j], order[i]];
        }
        play(order, 0, name);
    }
    function toggle() {
        send(["cycle", "pause"]);
    }
    function next() {
        send(["playlist-next"]);
    }
    function previous() {
        // Like any player: past 3 s, back to the start of this song.
        if (position > 3 || queuePos === 0)
            seek(0);
        else
            send(["playlist-prev"]);
    }
    function seek(seconds) {
        position = seconds;
        send(["seek", seconds, "absolute"]);
    }
    function setShuffle(on) {
        shuffle = on;
        send([on ? "playlist-shuffle" : "playlist-unshuffle"]);
    }
    function setLoop(state) {
        loopState = state;
        send(["set_property", "loop-playlist", state === MprisLoopState.Playlist ? "inf" : "no"]);
        send(["set_property", "loop-file", state === MprisLoopState.Track ? "inf" : "no"]);
    }
    function stop() {
        send(["quit"]);
    }

    FileView {
        id: queueFile
        path: music.queuePath
        blockWrites: true
        printErrors: false
    }

    Process {
        id: mpv
        command: ["mpv", "--idle=yes", "--no-video", "--no-terminal", "--no-config", "--load-scripts=no",
            "--audio-display=no", "--input-ipc-server=" + music.socketPath]
        onRunningChanged: {
            if (!running) {
                music.connected = false;
                sock.connected = false;
                music.path = "";
                music.paused = true;
                music.hadSong = false;
            }
        }
    }
    function start() {
        if (!mpv.running)
            mpv.running = true;
        tries.count = 0;
        tries.start();
    }
    // The socket appears a moment after mpv starts: knock until it opens.
    Timer {
        id: tries
        property int count: 0
        interval: 100
        repeat: true
        onTriggered: {
            if (music.connected) {
                stop();
            } else if (++count > 50) {
                stop();
                music.error = "mpv didn't start.";
            } else {
                sock.connected = true;
            }
        }
    }

    property var pending: []
    function send(cmd) {
        if (!connected)
            return;
        sock.write(JSON.stringify({ "command": cmd }) + "\n");
        sock.flush();
    }
    function flush() {
        for (const cmd of pending)
            send(cmd);
        pending = [];
    }

    Socket {
        id: sock
        path: music.socketPath
        onConnectedChanged: {
            music.connected = connected;
            if (!connected)
                return;
            const watch = ["pause", "path", "duration", "playlist-pos", "playlist-count", "idle-active", "loop-playlist", "loop-file", "metadata"];
            watch.forEach((name, i) => sock.write(JSON.stringify({ "command": ["observe_property", i + 1, name] }) + "\n"));
            sock.flush();
            music.flush();
        }
        parser: SplitParser {
            onRead: line => music.onEvent(line)
        }
    }

    function onEvent(line) {
        let e;
        try {
            e = JSON.parse(line);
        } catch (x) {
            return;
        }
        if (e.request_id === 7 && e.error === "success") {
            position = e.data ?? 0;
            return;
        }
        if (e.event !== "property-change")
            return;
        switch (e.name) {
        case "pause":
            paused = e.data === true;
            break;
        case "path":
            path = e.data ?? "";
            position = 0;
            if (path !== "")
                hadSong = true;
            break;
        case "duration":
            duration = e.data ?? 0;
            break;
        case "playlist-pos":
            queuePos = e.data ?? -1;
            break;
        case "playlist-count":
            queueCount = e.data ?? 0;
            break;
        case "metadata":
            meta = e.data ?? {};
            break;
        case "idle-active":
            // The queue ended: mpv goes, and with it the card.
            if (e.data === true && hadSong)
                stop();
            break;
        }
    }

    // Where it is: asked once a second while playing (watching time-pos would
    // send dozens of events a second).
    Timer {
        running: music.active && !music.paused
        interval: 1000
        repeat: true
        onTriggered: {
            sock.write(JSON.stringify({ "command": ["get_property", "time-pos"], "request_id": 7 }) + "\n");
            sock.flush();
        }
    }

    // ======== as an MPRIS player, for services/Media and NowPlaying ========
    readonly property QtObject player: QtObject {
        readonly property bool isLocal: true
        readonly property string identity: "Music"
        readonly property string dbusName: "nikkita-music"
        readonly property string desktopEntry: ""
        readonly property string trackTitle: music.current ? music.current.title : (music.meta.title || music.path.split("/").pop())
        readonly property string trackArtist: music.current ? music.current.artist : (music.meta.artist || "")
        readonly property string trackAlbum: music.current ? music.current.album : (music.meta.album || "")
        readonly property string trackArtUrl: music.current && music.current.cover ? "file://" + music.current.cover : ""
        readonly property bool isPlaying: music.active && !music.paused
        readonly property bool canControl: music.active
        readonly property bool canTogglePlaying: music.active
        readonly property bool canGoNext: music.active && (music.queuePos < music.queueCount - 1 || music.loopState === MprisLoopState.Playlist)
        readonly property bool canGoPrevious: music.active
        readonly property bool canSeek: music.active
        readonly property bool canRaise: true
        readonly property real position: music.position
        readonly property real length: music.duration
        readonly property bool positionSupported: true
        readonly property bool lengthSupported: true
        readonly property bool shuffle: music.shuffle
        readonly property bool shuffleSupported: true
        readonly property int loopState: music.loopState
        readonly property bool loopSupported: true
        function togglePlaying() {
            music.toggle();
        }
        function next() {
            music.next();
        }
        function previous() {
            music.previous();
        }
        function raise() {
            ShellState.openMusic();
        }
    }
}
