// ~/nikkita-shell/dotfiles/quickshell/music/MusicWindow.qml
//
// The local music player's window (services/Music). It rescans ~/Music each time
// it opens (cached: only new files cost).
import QtQuick
import Quickshell
import qs.common
import qs.services

FloatingWindow {
    id: win

    title: "Music"
    // Opaque: a window you read in. Transparency (Settings → Appearance) is for the panels.
    color: Theme.bg
    minimumSize: Qt.size(820, 560)

    Component.onCompleted: {
        const s = Quickshell.screens.find(x => x.name === ShellState.focusedScreen()) ?? Quickshell.screens[0];
        implicitWidth = Math.round(Math.min(1100, s.width * 0.6));
        implicitHeight = Math.round(Math.min(740, s.height * 0.72));
        Music.scan();
    }
    onVisibleChanged: if (!visible) ShellState.musicOpen = false

    // ---- what is shown: the library or a playlist ----
    property string view: ""            // "" = the whole library
    readonly property var list: view === "" ? null : Music.playlist(view)
    readonly property var viewSongs: view === "" ? Music.songs : (list ? list.songs.map(p => Music.byPath[p]).filter(s => s) : [])
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var shown: query === "" ? viewSongs : viewSongs.filter(s => (s.title + " " + s.artist + " " + s.album).toLowerCase().includes(query))
    readonly property real total: shown.reduce((a, s) => a + (s.duration || 0), 0)
    onViewChanged: search.text = ""

    function length(seconds) {
        const m = Math.round(seconds / 60);
        return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min";
    }
    function play(index) {
        Music.play(shown.map(s => s.path), index, view === "" ? "Library" : view);
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (addMenu.path !== "")
                addMenu.path = "";
            else if (search.text !== "")
                search.text = "";
            else
                ShellState.musicOpen = false;
        }

        // ======== left: the library and the playlists ========
        Item {
            id: side
            x: 16
            y: 16
            width: 270
            height: parent.height - 32 - (player.visible ? player.height + 12 : 0)

            Row {
                id: heading
                width: parent.width
                height: 40
                StyledText {
                    width: parent.width - rescan.width
                    height: parent.height
                    text: "Music"
                    font.pixelSize: Theme.textHeading
                    font.weight: Font.Bold
                }
                PillButton {
                    id: rescan
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    flat: true
                    icon: "view-refresh-symbolic"
                    busy: Music.scanning
                    tip: "Read ~/Music again"
                    onClicked: Music.scan()
                }
            }

            Column {
                id: nav
                anchors.top: heading.bottom
                anchors.topMargin: Theme.spaceL
                width: parent.width
                spacing: Theme.spaceXs

                ListRow {
                    width: parent.width
                    height: 48
                    icon: "folder-music-symbolic"
                    title: "All songs"
                    subtitle: Music.songs.length + (Music.songs.length === 1 ? " song" : " songs")
                    active: win.view === ""
                    onClicked: win.view = ""
                }

                Item {
                    width: parent.width
                    height: 40
                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceS
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.spaceS
                        text: "Playlists"
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.weight: Font.DemiBold
                    }
                    PillButton {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.spaceXxs
                        width: 30
                        height: 30
                        flat: true
                        icon: "list-add-symbolic"
                        iconSize: 13
                        tip: "New playlist"
                        onClicked: {
                            creating.visible = true;
                            creating.text = "";
                            creating.input.forceActiveFocus();
                        }
                    }
                }

                InputField {
                    id: creating
                    visible: false
                    width: parent.width
                    icon: "list-add-symbolic"
                    placeholder: "Name, then Enter"
                    onSubmitted: {
                        if (text.trim() !== "") {
                            Music.createPlaylist(text);
                            win.view = text.trim();
                        }
                        visible = false;
                    }
                    onSpecialKey: ev => {
                        if (ev.key === Qt.Key_Escape) {
                            visible = false;
                            ev.accepted = true;
                        }
                    }
                }
            }

            ListView {
                id: playlistView
                anchors.top: nav.bottom
                anchors.topMargin: Theme.spaceXs
                anchors.bottom: openFolder.top
                anchors.bottomMargin: Theme.spaceM
                width: parent.width
                clip: true
                spacing: Theme.spaceXs
                boundsBehavior: Flickable.StopAtBounds
                model: Music.playlists

                delegate: Item {
                    id: pl
                    required property var modelData
                    property bool renaming: false
                    property bool confirming: false
                    width: playlistView.width
                    height: 48

                    ListRow {
                        id: plRow
                        anchors.fill: parent
                        visible: !pl.renaming
                        icon: "view-list-bullet-symbolic"
                        title: pl.modelData.name
                        subtitle: pl.confirming ? "Delete it? The songs stay." : pl.modelData.songs.length + (pl.modelData.songs.length === 1 ? " song" : " songs")
                        active: win.view === pl.modelData.name
                        onClicked: win.view = pl.modelData.name

                        PillButton {
                            visible: !pl.confirming && (plRow.hovering || hovering)
                            width: 28
                            height: 28
                            flat: true
                            icon: "document-edit-symbolic"
                            iconSize: 12
                            tip: "Rename"
                            onClicked: {
                                pl.renaming = true;
                                rename.text = pl.modelData.name;
                                rename.input.selectAll();
                                rename.input.forceActiveFocus();
                            }
                        }
                        PillButton {
                            visible: !pl.confirming && (plRow.hovering || hovering)
                            width: 28
                            height: 28
                            flat: true
                            icon: "user-trash-symbolic"
                            iconSize: 12
                            tip: "Delete this playlist"
                            onClicked: pl.confirming = true
                        }
                        PillButton {
                            visible: pl.confirming
                            height: 28
                            text: "Delete"
                            danger: true
                            restColor: Theme.bad
                            onClicked: {
                                if (win.view === pl.modelData.name)
                                    win.view = "";
                                Music.deletePlaylist(pl.modelData.name);
                                pl.confirming = false;
                            }
                        }
                        PillButton {
                            visible: pl.confirming
                            height: 28
                            text: "Keep"
                            flat: true
                            onClicked: pl.confirming = false
                        }
                    }
                    InputField {
                        id: rename
                        anchors.fill: parent
                        visible: pl.renaming
                        icon: "document-edit-symbolic"
                        onSubmitted: {
                            const to = text.trim();
                            if (to !== "" && to !== pl.modelData.name) {
                                if (win.view === pl.modelData.name)
                                    win.view = to;
                                Music.renamePlaylist(pl.modelData.name, to);
                            }
                            pl.renaming = false;
                        }
                        onSpecialKey: ev => {
                            if (ev.key === Qt.Key_Escape) {
                                pl.renaming = false;
                                ev.accepted = true;
                            }
                        }
                    }
                }

                StyledText {
                    visible: Music.playlists.length === 0
                    width: parent.width
                    padding: Theme.spaceS
                    text: "No playlists yet. The + makes one; the + on a song adds it."
                    color: Theme.dim
                    font.pixelSize: Theme.textLabel
                    wrapMode: Text.Wrap
                }
            }

            PillButton {
                id: openFolder
                anchors.bottom: parent.bottom
                width: parent.width
                height: 36
                flat: true
                icon: "folder-open-symbolic"
                text: "Open ~/Music"
                onClicked: ShellState.openFolder(Music.root)
            }
        }

        // ======== right: the songs ========
        Item {
            id: main
            x: side.x + side.width + 20
            y: 16
            width: parent.width - x - 16
            height: side.height

            Item {
                id: header
                width: parent.width
                height: 64

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - buttons.width - search.width - 24
                    spacing: Theme.spaceXxs
                    StyledText {
                        width: parent.width
                        text: win.view === "" ? "All songs" : win.view
                        font.pixelSize: Theme.textHeading
                        font.weight: Font.Bold
                    }
                    StyledText {
                        width: parent.width
                        text: win.shown.length + (win.shown.length === 1 ? " song" : " songs") + (win.total > 0 ? "  ·  " + win.length(win.total) : "")
                        color: Theme.muted
                    }
                }
                Row {
                    id: buttons
                    anchors.right: search.left
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceS
                    PillButton {
                        height: 38
                        icon: "media-playback-start-symbolic"
                        text: "Play"
                        active: true
                        interactive: win.shown.length > 0
                        onClicked: win.play(0)
                    }
                    PillButton {
                        width: 38
                        height: 38
                        icon: "media-playlist-shuffle-symbolic"
                        interactive: win.shown.length > 0
                        tip: "Play in random order"
                        onClicked: Music.playShuffled(win.shown.map(s => s.path), win.view === "" ? "Library" : win.view)
                    }
                }
                InputField {
                    id: search
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(260, parent.width * 0.32)
                    placeholder: "Search"
                }
            }

            ListView {
                id: songView
                anchors.top: header.bottom
                anchors.topMargin: Theme.spaceM
                anchors.bottom: parent.bottom
                width: parent.width
                clip: true
                spacing: Theme.spaceXxs
                boundsBehavior: Flickable.StopAtBounds
                model: win.shown

                delegate: SongRow {
                    required property var modelData
                    required property int index
                    width: songView.width - 8
                    song: modelData
                    number: index + 1
                    current: Music.active && Music.path === modelData.path
                    inPlaylist: win.view !== "" && win.query === ""
                    first: index === 0
                    last: index === win.shown.length - 1
                    onPlay: win.play(index)
                    onAdd: anchor => addMenu.open(modelData.path, anchor)
                    onRemove: Music.removeFromPlaylist(win.view, index)
                    onMoveUp: Music.moveInPlaylist(win.view, index, index - 1)
                    onMoveDown: Music.moveInPlaylist(win.view, index, index + 1)
                }
            }
            ScrollHint { view: songView }

            Column {
                anchors.centerIn: songView
                visible: win.shown.length === 0 && Music.scanned
                spacing: Theme.spaceM
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "folder-music-symbolic"
                    size: 44
                    color: Theme.dim
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.query !== "" ? "Nothing matches" : win.view !== "" ? "This playlist is empty" : "No music yet"
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.DemiBold
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: win.query === ""
                    text: win.view !== "" ? "In All songs, the + on a song adds it here." : "Put mp3, mp4, flac... files in ~/Music (folders are fine), then refresh."
                    color: Theme.muted
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Music.error !== ""
                    text: Music.error
                    color: Theme.bad
                }
            }
        }

        // ======== bottom: the player, while it has a song ========
        NowPlaying {
            id: player
            visible: Music.active
            x: 16
            y: parent.height - height - 16
            width: parent.width - 32
            height: 72
            compact: true
            radius: Theme.radiusL
        }

        // ======== "add to a playlist" ========
        Item {
            id: addMenu
            property string path: ""
            function open(p, anchor) {
                path = p;
                const at = anchor.mapToItem(addMenu, anchor.width, anchor.height + 6);
                card.x = Math.max(16, Math.min(addMenu.width - card.width - 16, at.x - card.width));
                card.y = Math.min(addMenu.height - card.height - 16, at.y);
                newName.text = "";
            }

            anchors.fill: parent
            visible: path !== ""

            MouseArea {
                anchors.fill: parent
                onClicked: addMenu.path = ""
            }
            Rectangle {
                id: card
                width: 250
                height: menu.height + 20
                radius: Theme.radiusL
                color: Theme.mix(Theme.bg, Theme.fg, 0.08)
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.1)

                Column {
                    id: menu
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: Theme.spaceXs
                    StyledText {
                        leftPadding: Theme.spaceS
                        text: "Add to"
                        color: Theme.muted
                        font.pixelSize: Theme.textLabel
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: Music.playlists
                        ListRow {
                            required property var modelData
                            width: menu.width
                            height: 40
                            icon: "view-list-bullet-symbolic"
                            title: modelData.name
                            subtitle: modelData.songs.includes(addMenu.path) ? "Already there" : ""
                            onClicked: {
                                Music.addToPlaylist(modelData.name, addMenu.path);
                                addMenu.path = "";
                            }
                        }
                    }
                    InputField {
                        id: newName
                        width: menu.width
                        height: 38
                        icon: "list-add-symbolic"
                        placeholder: "New playlist"
                        onSubmitted: {
                            if (text.trim() !== "")
                                Music.createPlaylist(text, [addMenu.path]);
                            addMenu.path = "";
                        }
                    }
                }
            }
        }
    }

    TooltipLayer {}
}
