// ~/nikkita-shell/dotfiles/quickshell/panels/WallpaperPanel.qml
//
// The gallery of ~/Pictures/wallpapers; a click runs `wallpaper.sh set`. Thumbnails
// load small (sourceSize): at natural size they eat memory.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

Item {
    id: wallpapers

    implicitHeight: Math.min(grid.contentHeight, 420) + (empty.visible ? empty.height : 0)

    readonly property string dir: Paths.wallpapers
    property string current: ""

    function apply(file) {
        // wallpaper.sh reports its own failures.
        Commands.run([Paths.script("wallpaper.sh"), "set", file], null);
        current = file;
    }

    Component.onCompleted: reader.running = true

    Process {
        id: reader
        command: ["readlink", "-f", Paths.wallpaper]
        stdout: StdioCollector {
            onStreamFinished: wallpapers.current = text.trim()
        }
    }

    FolderListModel {
        id: files
        folder: "file://" + wallpapers.dir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    GridView {
        id: grid
        width: parent.width
        height: Math.min(contentHeight, 420)
        clip: true
        cellWidth: width / 4
        cellHeight: cellWidth * 0.68
        boundsBehavior: Flickable.StopAtBounds
        model: files

        delegate: Item {
            id: cell
            required property string filePath
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool isCurrent: filePath === wallpapers.current

            Rectangle {
                id: frame
                anchors.fill: parent
                anchors.margins: Theme.spaceXs
                radius: Theme.radiusM
                color: Theme.card
                border.width: cell.isCurrent ? 2 : 0
                border.color: Theme.accent
                scale: zone.containsMouse ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: Theme.msFast } }
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceXxs
                    source: "file://" + cell.filePath
                    sourceSize.width: 192
                    sourceSize.height: 128
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }
            MouseArea {
                id: zone
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: wallpapers.apply(cell.filePath)
            }
        }
    }

    StyledText {
        id: empty
        visible: files.status === FolderListModel.Ready && files.count === 0
        text: "No images in ~/Pictures/wallpapers"
        color: Theme.dim
        height: 30
    }
}
