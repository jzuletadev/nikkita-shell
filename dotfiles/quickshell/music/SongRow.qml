// ~/nikita-shell/dotfiles/quickshell/music/SongRow.qml
// One song in the Music window. A click plays it and the rest of its list.
import QtQuick
import QtQuick.Effects
import qs.common
import qs.services

Rectangle {
    id: row

    required property var song
    required property int number
    property bool current: false        // the song mpv has
    property bool inPlaylist: false
    property bool first: false
    property bool last: false

    signal play
    signal add(Item anchor)
    signal remove
    signal moveUp
    signal moveDown

    height: 56
    radius: Theme.radiusM
    color: current ? Theme.accentSoft : area.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.msFast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.play()
    }

    Item {
        id: lead
        x: 8
        width: 32
        height: parent.height
        StyledText {
            anchors.centerIn: parent
            visible: !row.current
            text: row.number
            color: Theme.dim
            font.family: Theme.monoFamily
            font.pixelSize: Theme.textSmall
        }
        Equalizer {
            anchors.centerIn: parent
            visible: row.current
            playing: Music.active && !Music.paused
            barHeight: 14
        }
    }

    Item {
        id: cover
        x: lead.x + lead.width + 6
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusS
            color: Theme.alpha(Theme.fg, 0.08)
            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "audio-x-generic-symbolic"
                size: 16
                color: Theme.dim
            }
        }
        Image {
            id: art
            anchors.fill: parent
            visible: false
            source: row.song.cover ? "file://" + row.song.cover : ""
            sourceSize: Qt.size(80, 80)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            id: artMask
            anchors.fill: parent
            radius: Theme.radiusS
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: art.status === Image.Ready
            source: art
            maskEnabled: true
            maskSource: artMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Column {
        x: cover.x + cover.width + 12
        width: Math.max(80, album.x - x - 16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXxs
        StyledText {
            width: parent.width
            text: row.song.title
            font.weight: Font.DemiBold
            color: row.current ? Theme.accent : Theme.fg
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            text: row.song.artist
            color: Theme.muted
            font.pixelSize: Theme.textLabel
        }
    }

    StyledText {
        id: album
        x: row.width * 0.56
        width: actions.x - x - 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.song.album
        color: Theme.dim
        font.pixelSize: Theme.textLabel
    }

    // Its length, or its actions under the pointer.
    StyledText {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        visible: !area.containsMouse && !actionsHovered
        text: Media.time(row.song.duration)
        color: Theme.dim
        font.family: Theme.monoFamily
        font.pixelSize: Theme.textSmall
    }
    readonly property bool actionsHovered: up.hovering || down.hovering || addButton.hovering || removeButton.hovering
    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXxs
        opacity: area.containsMouse || row.actionsHovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.msFast } }

        PillButton {
            id: up
            visible: row.inPlaylist
            width: 30
            height: 30
            flat: true
            icon: "go-up-symbolic"
            iconSize: 13
            interactive: !row.first
            tip: "Move up"
            onClicked: row.moveUp()
        }
        PillButton {
            id: down
            visible: row.inPlaylist
            width: 30
            height: 30
            flat: true
            icon: "go-down-symbolic"
            iconSize: 13
            interactive: !row.last
            tip: "Move down"
            onClicked: row.moveDown()
        }
        PillButton {
            id: addButton
            width: 30
            height: 30
            flat: true
            icon: "list-add-symbolic"
            iconSize: 13
            tip: "Add to a playlist"
            onClicked: row.add(addButton)
        }
        PillButton {
            id: removeButton
            visible: row.inPlaylist
            width: 30
            height: 30
            flat: true
            icon: "list-remove-symbolic"
            iconSize: 13
            tip: "Take it out of this playlist"
            onClicked: row.remove()
        }
    }
}
