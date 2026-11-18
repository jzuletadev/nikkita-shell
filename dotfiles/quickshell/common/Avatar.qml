// ~/nikita-shell/dotfiles/quickshell/common/Avatar.qml
//
// Your picture in a hexagon, or your initial when there is none: the lock and login
// screens, and Settings. It follows the file when it changes; `reload()` for one that
// didn't exist yet (FileView only watches a file that was there when read).
import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.common

Item {
    id: avatar

    property string path: ""
    property string name: ""           // the initial, when there is no picture
    readonly property int frame: Math.max(3, Math.round(width * 0.047))
    property bool hasFace: false

    function reload() {
        file.reload();
    }

    FileView {
        id: file
        path: avatar.path
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            avatar.hasFace = true;
            // Same path, new content: set it again so the image is read again.
            faceImage.source = "";
            faceImage.source = "file://" + avatar.path;
        }
        onLoadFailed: {
            avatar.hasFace = false;
            faceImage.source = "";
        }
    }

    HexShape {
        anchors.fill: parent
        fill: Theme.mix(Theme.bg, Theme.fg, 0.07)
        stroke: Theme.rim
        strokeWidth: 1.5
    }
    HexShape {
        anchors.fill: parent
        anchors.margins: avatar.frame
        fill: Theme.mix(Theme.bg, Theme.fg, 0.16)

        StyledText {
            anchors.centerIn: parent
            visible: !face.visible
            text: (avatar.name || "?").charAt(0).toUpperCase()
            font.pixelSize: Math.round(avatar.height * 0.36)
            font.weight: Font.DemiBold
            color: Theme.muted
        }
    }
    Image {
        id: faceImage
        anchors.fill: parent
        visible: false
        sourceSize: Qt.size(avatar.width * 2, avatar.height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    HexShape {
        id: faceMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        fill: "white"
    }
    MultiEffect {
        id: face
        anchors.fill: parent
        anchors.margins: avatar.frame
        visible: avatar.hasFace && faceImage.status === Image.Ready
        source: faceImage
        maskEnabled: true
        maskSource: faceMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
