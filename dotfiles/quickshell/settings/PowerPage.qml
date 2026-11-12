// ~/nikkita-shell/dotfiles/quickshell/settings/PowerPage.qml
// Battery and its charge limit (where the laptop has one), power mode, keep awake,
// and the idle steps (read from hypridle.conf).
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
import qs.common
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    Component.onCompleted: ChargeLimit.refresh()

    // ---- idle, from hypridle.conf ----
    property var idle: []
    FileView {
        path: Paths.config + "/hypr/hypridle.conf"
        printErrors: false
        onLoaded: {
            const what = { dim: "dims the screen", lock: "locks", "dpms-off": "turns the screen off", suspend: "sleeps" };
            const v = [];
            for (const block of text().split(/\blistener\b/).slice(1)) {
                const t = /\btimeout\s*=\s*(\d+)/.exec(block);
                const a = /on-timeout\s*=.*idle\.sh\s+([\w-]+)/.exec(block);
                if (t && a && what[a[1]])
                    v.push({ min: Math.round(parseInt(t[1]) / 60), what: what[a[1]] });
            }
            page.idle = v.sort((x, y) => x.min - y.min);
        }
    }

    // ---- battery ----
    Section {
        title: "Battery"
        visible: Battery.present
        padding: Theme.spaceL

        Item {
            width: parent.width
            height: 64
            StyledText {
                id: big
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.pct + "%"
                font.pixelSize: Theme.textHero
                font.weight: Font.DemiBold
                color: Battery.level
            }
            Column {
                anchors.left: big.right
                anchors.leftMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceXs
                StyledText {
                    text: Battery.detail
                    font.pixelSize: Theme.textLarge
                    font.weight: Font.Medium
                }
                StyledText {
                    text: Battery.present ? [
                        Math.abs(Battery.device.changeRate) > 0.05 ? Math.abs(Battery.device.changeRate).toFixed(1) + " W" : "",
                        Battery.device.healthSupported ? "health " + Math.round(Battery.device.healthPercentage) + "%" : "",
                        Battery.device.energyCapacity > 0 ? Battery.device.energy.toFixed(1) + " / " + Battery.device.energyCapacity.toFixed(1) + " Wh" : ""
                    ].filter(x => x).join("  ·  ") : ""
                    color: Theme.muted
                    font.pixelSize: Theme.textSmall
                }
            }
            Glyph {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                code: Battery.charging ? 0xF0084 : 0xF0079
                size: 34
                color: Battery.level
            }
        }

        Rectangle {
            width: parent.width
            height: 10
            radius: height / 2
            color: Theme.alpha(Theme.fg, 0.08)
            Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * Battery.pct / 100
                color: Battery.level
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ---- charge limit, on laptops whose battery has one (scripts/charge-limit.sh) ----
    Section {
        title: "Charging"
        visible: Battery.present && ChargeLimit.supported
        note: "A battery kept below full lasts more years: worth it on a laptop that is mostly plugged in. Changing it asks for your password; it stays after a restart."
        SettingRow {
            icon: "battery-level-80-charging-symbolic"
            title: "Stop charging at"
            subtitle: ChargeLimit.limit >= 100 ? "It charges to full." : "It stops at " + ChargeLimit.limit + " %."
            Repeater {
                model: [100, 90, 80, 60]
                PillButton {
                    required property int modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData === 100 ? "Full" : modelData + " %"
                    active: ChargeLimit.limit === modelData && ChargeLimit.changing < 0
                    busy: ChargeLimit.changing === modelData
                    interactive: ChargeLimit.changing < 0
                    onClicked: ChargeLimit.set(modelData)
                }
            }
        }
    }

    // ---- power mode ----
    Section {
        title: "Power mode"
        note: PowerModes.limited !== "" ? "Limited right now: " + PowerModes.limited : "Also in the top-left corner."
        padding: Theme.spaceM

        Row {
            id: modes
            width: parent.width
            spacing: Theme.spaceM
            readonly property var options: PowerModes.list

            Repeater {
                model: modes.options

                Rectangle {
                    id: mode
                    required property var modelData
                    readonly property bool on: PowerProfiles.profile === modelData.profile
                    width: (modes.width - modes.spacing * (modes.options.length - 1)) / modes.options.length
                    height: 92
                    radius: Theme.radiusM
                    color: on ? (modeArea.containsMouse ? Theme.activeHover : Theme.accent) : modeArea.containsMouse ? Theme.hoverFill : Theme.alpha(Theme.fg, 0.04)
                    Behavior on color { ColorAnimation { duration: Theme.msFast } }

                    // The hover ring (Theme's state rule).
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.hoverRing
                        opacity: modeArea.containsMouse && !mode.on ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.msFast } }
                    }

                    Column {
                        x: Theme.spaceL
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 2 * Theme.spaceL
                        spacing: Theme.spaceXs
                        Icon {
                            name: mode.modelData.icon
                            size: 20
                            color: mode.on ? Theme.accentText : Theme.fg
                        }
                        StyledText {
                            width: parent.width
                            text: mode.modelData.title
                            font.weight: Font.DemiBold
                            color: mode.on ? Theme.accentText : Theme.fg
                        }
                        StyledText {
                            width: parent.width
                            text: mode.modelData.subtitle
                            font.pixelSize: Theme.textSmall
                            color: mode.on ? Theme.alpha(Theme.accentText, 0.7) : Theme.muted
                        }
                    }
                    MouseArea {
                        id: modeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = mode.modelData.profile
                    }
                }
            }
        }
    }

    // ---- idle ----
    Section {
        title: "When you step away"
        note: "Set in dotfiles/hypr/hypridle.conf; scripts/idle.sh does each step."
        SettingRow {
            glyph: ShellState.keepAwake ? Glyphs.keepAwake : Glyphs.keepAwakeOff
            title: "Keep the screen awake"
            subtitle: "Nothing dims, locks or sleeps while this is on. Also the cup in the Power corner (top left)."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: ShellState.keepAwake
                onToggled: ShellState.keepAwake = !ShellState.keepAwake
            }
        }
        SettingRow {
            icon: "preferences-desktop-screensaver-symbolic"
            title: "On battery"
            subtitle: page.idle.length === 0 ? "No idle steps found."
                : page.idle.map((x, i) => (i === 0 ? "After " : "after ") + x.min + " min it " + x.what).join(", ") + "."
        }
        SettingRow {
            icon: "ac-adapter-symbolic"
            title: "Plugged in"
            subtitle: "Nothing: the screen stays on until you lock it (SUPER + L)."
        }
    }
}
