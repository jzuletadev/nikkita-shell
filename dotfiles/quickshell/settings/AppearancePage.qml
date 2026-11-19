// ~/nikita-shell/dotfiles/quickshell/settings/AppearancePage.qml
// In the order you'd set them up: the wallpaper (the one in use, then the gallery);
// your picture; the theme; the panels' transparency; the effects.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.common
import qs.panels
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    Section {
        title: "Wallpaper"
        note: "Your images in ~/Pictures/wallpapers. The lock and login screens follow the one you pick."
        padding: Theme.spaceL

        // The one in use, with its name, and the gallery right under it.
        Row {
            width: parent.width
            spacing: Theme.spaceL

            Item {
                id: frame
                width: Math.min(288, parent.width * 0.45)
                height: Math.round(width * 9 / 16)

                Image {
                    id: shot
                    anchors.fill: parent
                    visible: false
                    source: gallery.current !== "" ? "file://" + gallery.current : ""
                    sourceSize: Qt.size(576, 324)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                Rectangle {
                    id: mask
                    anchors.fill: parent
                    radius: Theme.radiusM
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusM
                    visible: shot.status !== Image.Ready
                    color: Theme.alpha(Theme.fg, 0.05)
                }
                MultiEffect {
                    anchors.fill: parent
                    visible: shot.status === Image.Ready
                    source: shot
                    maskEnabled: true
                    maskSource: mask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }
            Column {
                anchors.verticalCenter: frame.verticalCenter
                width: parent.width - frame.width - parent.spacing
                spacing: Theme.spaceS

                StyledText {
                    text: "In use"
                    color: Theme.muted
                    font.pixelSize: Theme.textSmall
                }
                StyledText {
                    width: parent.width
                    text: gallery.current !== "" ? gallery.current.split("/").pop() : "None yet"
                    font.pixelSize: Theme.textTitle
                    font.weight: Font.DemiBold
                }
                PillButton {
                    text: "Open the folder"
                    icon: "folder-open-symbolic"
                    onClicked: ShellState.openFolder(gallery.dir)
                }
            }
        }
        WallpaperPanel {
            id: gallery
            width: parent.width
        }
    }

    Section {
        title: "Profile picture"
        note: "Cropped to a square from the center of the image."

        Item {
            id: picture

            property string error: ""

            function run(what) {
                error = "";
                faceTool.command = [Paths.script("face.py"), what];
                faceTool.running = true;
            }

            width: parent.width
            height: 92

            Avatar {
                id: avatar
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(height * Theme.hexRatio)
                height: 64
                path: Paths.face(Quickshell.env("USER"))
                name: Quickshell.env("USER")
            }
            Column {
                anchors.left: avatar.right
                anchors.leftMargin: Theme.spaceL
                anchors.right: buttons.left
                anchors.rightMargin: Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceXs
                StyledText {
                    text: avatar.hasFace ? "Your picture" : "No picture yet"
                }
                StyledText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: picture.error !== "" ? picture.error
                        : avatar.hasFace ? "On the lock and login screens."
                        : "The lock and login screens show your initial until you choose one."
                    color: picture.error !== "" ? Theme.bad : Theme.muted
                    font.pixelSize: Theme.textSmall
                }
            }
            Row {
                id: buttons
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS
                PillButton {
                    visible: avatar.hasFace
                    icon: "user-trash-symbolic"
                    tip: "Remove the picture"
                    danger: true
                    interactive: !faceTool.running
                    onClicked: picture.run("remove")
                }
                PillButton {
                    icon: "folder-pictures-symbolic"
                    text: avatar.hasFace ? "Change…" : "Choose…"
                    busy: faceTool.running
                    onClicked: picture.run("choose")
                }
            }

            // Exit 1 is "cancelled"; 2 brings the reason on stderr.
            Process {
                id: faceTool
                // The file chooser is another window: Settings stays open meanwhile.
                onRunningChanged: ShellState.settingsWaiting = running
                Component.onDestruction: ShellState.settingsWaiting = false
                stderr: StdioCollector {
                    onStreamFinished: if (text.trim() !== "") picture.error = text.trim()
                }
                onExited: avatar.reload()
            }
        }
    }

    Section {
        title: "Theme"
        padding: Theme.spaceL
        ThemePanel { width: parent.width }
    }

    Section {
        title: "Effects"
        note: "Reduce animations also stops the windows' and workspaces' own."
        SettingRow {
            icon: "video-display-symbolic"
            title: "Show the desktop when the wallpaper changes"
            subtitle: "The windows step aside for a moment, so you see the new picture arrive."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Prefs.peekWallpaper
                onToggled: Prefs.set("peekWallpaper", !checked)
            }
        }
        SettingRow {
            icon: "preferences-system-symbolic"
            title: "Reduce animations"
            subtitle: "Panels, windows and lists appear at once, with no movement."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Prefs.reduceMotion
                onToggled: HyprSettings.setReduceMotion(!checked)
            }
        }
    }

    Section {
        title: "Transparency"
        note: "Below 60 % the blur behind the panels would stop working, so that is the floor."
        SettingRow {
            icon: "preferences-color-symbolic"
            title: "Opacity"
            subtitle: "Of the panels and this window: lower lets more of the wallpaper through."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: !Prefs.isDefault("panelOpacity")
                defaultText: Math.round(Prefs.defaults.panelOpacity * 100) + " %"
                onClicked: Prefs.reset("panelOpacity")
            }
            HorizontalSlider {
                width: 200
                anchors.verticalCenter: parent.verticalCenter
                value: Math.round((Prefs.panelOpacity - 0.6) / 0.4 * 100)
                onMoved: v => Prefs.set("panelOpacity", Math.round(60 + 40 * v / 100) / 100)
            }
            StyledText {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round(Prefs.panelOpacity * 100) + " %"
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
    }
}
