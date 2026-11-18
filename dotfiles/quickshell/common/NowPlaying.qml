// ~/nikita-shell/dotfiles/quickshell/common/NowPlaying.qml
//
// What's playing (services/Media), as a card over the blurred cover.
// `compact` (the lock screen): one row. `live`: on screen; only then does the
// position tick.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.common
import qs.services

Item {
    id: np

    property bool compact: false
    property bool live: true
    property int radius: Theme.radiusL

    readonly property var p: Media.player
    readonly property bool has: Media.hasTrack
    readonly property bool playing: p?.isPlaying ?? false
    readonly property string art: has ? (p?.trackArtUrl ?? "") : ""
    readonly property bool hasLength: has && !!p?.lengthSupported && (p?.length ?? 0) > 0
    readonly property string title: has ? (p?.trackTitle || p?.identity || "") : "Nothing playing"
    readonly property string artist: has ? (p?.trackArtist || p?.identity || "") : "Music from any app shows up here"

    // MPRIS doesn't push the position: ask for it once a second while playing.
    Timer {
        running: np.live && np.playing
        interval: 1000
        repeat: true
        onTriggered: np.p?.positionChanged()
    }

    // ---- the background: the cover, blurred and dimmed ----
    Rectangle {
        anchors.fill: parent
        radius: np.radius
        color: Theme.card
    }
    Image {
        id: bgArt
        anchors.fill: parent
        visible: false
        source: np.art
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(256, 256)
        asynchronous: true
    }
    Rectangle {
        id: bgMask
        anchors.fill: parent
        radius: np.radius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: bgArt
        opacity: bgArt.status === Image.Ready && np.has ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.msSlow } }
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: Theme.dark ? -0.42 : 0.5
        saturation: 0.1
        maskEnabled: true
        maskSource: bgMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    // ======== nothing playing (dashboard) ========
    // The dashboard narrows this card and gives the room to the clock and the
    // calendar: a way in to your music instead of an empty player.
    Column {
        visible: !np.compact && !np.has
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.spaceL
        spacing: Theme.spaceS

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "audio-x-generic-symbolic"
            size: 26
            color: Theme.dim
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing playing"
            color: Theme.muted
            font.weight: Font.DemiBold
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: "Music from any app shows up here"
            color: Theme.dim
            font.pixelSize: Theme.textSmall
        }
        Item {
            width: 1
            height: Theme.spaceXs
        }
        PillButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Your music"
            icon: "folder-music-symbolic"
            iconSize: 13
            tip: "~/Music and its playlists"
            onClicked: ShellState.openMusic()
        }
    }

    // ======== the card (dashboard) ========
    Item {
        visible: !np.compact && np.has
        anchors.fill: parent
        anchors.margins: Theme.spaceL

        // -- where it comes from --
        Item {
            id: source
            width: parent.width
            height: 20

            Row {
                id: sourceRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: name !== ""
                    name: Media.icon(np.p)
                    size: 16
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: np.p ? np.p?.identity : ""
                    color: Theme.muted
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.Medium
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Media.players.length > 1
                    name: "pan-down-symbolic"
                    size: 10
                    color: Theme.dim
                }
            }
            MouseArea {
                width: sourceRow.width
                height: parent.height
                enabled: Media.players.length > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.cycle()
                Tip { text: "Switch player\n" + Media.players.length + " are open" }
            }
            Equalizer {
                anchors.right: library.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                visible: np.has
                playing: np.playing
                barHeight: 12
            }
            PillButton {
                id: library
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                flat: true
                icon: "folder-music-symbolic"
                iconSize: 13
                tip: "Your music\n~/Music and its playlists"
                onClicked: ShellState.openMusic()
            }
        }

        // -- the record and the song --
        Row {
            anchors.top: source.bottom
            anchors.topMargin: Theme.spaceS
            anchors.bottom: bottomArea.top
            anchors.bottomMargin: Theme.spaceS
            width: parent.width
            spacing: Theme.spaceL

            Vinyl {
                id: disc
                anchors.verticalCenter: parent.verticalCenter
                size: Math.min(108, parent.height)
                art: np.art
                spinning: np.playing
                opacity: np.has ? 1 : 0.5
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - disc.width - parent.spacing
                spacing: Theme.spaceXs

                StyledText {
                    width: parent.width
                    text: np.title
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.Bold
                    color: np.has ? Theme.fg : Theme.dim
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    MouseArea {
                        anchors.fill: parent
                        enabled: !!(np.has && np.p?.canRaise)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: np.p?.raise()
                        Tip { text: np.p ? "Show " + np.p?.identity : "" }
                    }
                }
                StyledText {
                    width: parent.width
                    text: np.artist
                    color: Theme.muted
                    font.pixelSize: np.has ? Theme.textBody : Theme.textSmall
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                StyledText {
                    width: parent.width
                    visible: np.has && (np.p?.trackAlbum || "") !== ""
                    text: np.p?.trackAlbum ?? ""
                    color: Theme.dim
                    font.pixelSize: Theme.textSmall
                }
            }
        }

        // -- where it is, and the buttons --
        Column {
            id: bottomArea
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Theme.spaceXs
            visible: np.has

            Item {
                width: parent.width
                height: 16
                visible: np.hasLength

                StyledText {
                    id: posText
                    width: 38
                    anchors.verticalCenter: parent.verticalCenter
                    text: np.hasLength ? Media.time(seekArea.dragging ? seekArea.frac * np.p?.length : np.p?.position) : ""
                    color: Theme.muted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.textCaption
                }
                StyledText {
                    id: lenText
                    width: 38
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: np.hasLength ? Media.time(np.p?.length) : ""
                    color: Theme.muted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.textCaption
                }
                Item {
                    id: track
                    anchors.left: posText.right
                    anchors.right: lenText.left
                    anchors.leftMargin: Theme.spaceXs
                    anchors.rightMargin: Theme.spaceXs
                    height: parent.height

                    readonly property real frac: seekArea.dragging ? seekArea.frac : (np.hasLength ? Math.max(0, Math.min(1, np.p?.position / np.p?.length)) : 0)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: height / 2
                        color: Theme.alpha(Theme.fg, 0.18)
                        Rectangle {
                            height: parent.height
                            radius: height / 2
                            color: Theme.fg
                            width: parent.width * track.frac
                            Behavior on width {
                                enabled: !seekArea.dragging
                                NumberAnimation { duration: 900 }
                            }
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: seekArea.containsMouse || seekArea.dragging ? 13 : 9
                        height: width
                        radius: width / 2
                        color: Theme.fg
                        x: track.width * track.frac - width / 2
                        Behavior on width { NumberAnimation { duration: Theme.msFast } }
                        Behavior on x {
                            enabled: !seekArea.dragging
                            NumberAnimation { duration: 900 }
                        }
                    }
                    // Click or drag to seek; it applies when you let go.
                    MouseArea {
                        id: seekArea
                        property bool dragging: false
                        property real frac: 0
                        function at(x) {
                            return Math.max(0, Math.min(1, x / width));
                        }
                        anchors.fill: parent
                        anchors.topMargin: -4
                        anchors.bottomMargin: -4
                        enabled: !!(np.has && np.p?.canSeek)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: ev => {
                            dragging = true;
                            frac = at(ev.x);
                        }
                        onPositionChanged: ev => {
                            if (dragging)
                                frac = at(ev.x);
                        }
                        onReleased: {
                            Media.seek(np.p, frac * np.p.length);
                            dragging = false;
                        }
                        onCanceled: dragging = false
                    }
                }
            }

            Item {
                width: parent.width
                height: 44

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spaceS

                    PillButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!(np.has && np.p?.shuffleSupported)
                        width: 32
                        height: 32
                        flat: !(np.has && np.p?.shuffle)
                        active: !!(np.has && np.p?.shuffle)
                        icon: "media-playlist-shuffle-symbolic"
                        iconSize: 14
                        tip: np.has && np.p?.shuffle ? "Shuffle: on" : "Shuffle: off"
                        onClicked: Media.setShuffle(np.p, !np.p.shuffle)
                    }
                    PillButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        flat: true
                        icon: "media-skip-backward-symbolic"
                        interactive: !!(np.has && np.p?.canGoPrevious)
                        onClicked: np.p?.previous()
                    }
                    PillButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 46
                        active: true
                        icon: np.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                        iconSize: 18
                        interactive: !!(np.has && np.p?.canTogglePlaying)
                        onClicked: np.p?.togglePlaying()
                    }
                    PillButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        flat: true
                        icon: "media-skip-forward-symbolic"
                        interactive: !!(np.has && np.p?.canGoNext)
                        onClicked: np.p?.next()
                    }
                    PillButton {
                        readonly property int loop: np.has ? (np.p?.loopState ?? MprisLoopState.None) : MprisLoopState.None
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!(np.has && np.p?.loopSupported)
                        width: 32
                        height: 32
                        flat: loop === MprisLoopState.None
                        active: loop !== MprisLoopState.None
                        icon: loop === MprisLoopState.Track ? "media-playlist-repeat-song-symbolic" : "media-playlist-repeat-symbolic"
                        iconSize: 14
                        tip: loop === MprisLoopState.Track ? "Repeat: this song" : loop === MprisLoopState.Playlist ? "Repeat: all" : "Repeat: off"
                        onClicked: Media.setLoop(np.p, loop === MprisLoopState.None ? MprisLoopState.Playlist : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
                    }
                }
            }
        }
    }

    // ======== one row (lock screen) ========
    Item {
        visible: np.compact
        anchors.fill: parent
        anchors.margins: Theme.spaceS

        Vinyl {
            id: miniDisc
            anchors.verticalCenter: parent.verticalCenter
            size: parent.height
            art: np.art
            spinning: np.playing
        }
        Column {
            x: miniDisc.width + 12
            width: miniControls.x - x - 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXxs
            StyledText {
                width: parent.width
                text: np.title
                font.weight: Font.DemiBold
            }
            StyledText {
                width: parent.width
                text: np.artist
                color: Theme.muted
                font.pixelSize: Theme.textSmall
            }
        }
        Row {
            id: miniControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXxs
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                flat: true
                icon: "media-skip-backward-symbolic"
                iconSize: 13
                interactive: !!(np.has && np.p?.canGoPrevious)
                onClicked: np.p?.previous()
            }
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                active: true
                icon: np.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                iconSize: 14
                interactive: !!(np.has && np.p?.canTogglePlaying)
                onClicked: np.p?.togglePlaying()
            }
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                flat: true
                icon: "media-skip-forward-symbolic"
                iconSize: 13
                interactive: !!(np.has && np.p?.canGoNext)
                onClicked: np.p?.next()
            }
        }
    }
}
