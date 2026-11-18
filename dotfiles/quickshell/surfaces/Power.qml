// ~/nikita-shell/dotfiles/quickshell/surfaces/Power.qml

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.common
import qs.services

EdgePanel {
    id: power

    name: "power"
    edge: "top"
    placement: "start"
    span: m.corner
    depth: m.cornerHeight
    pinned: pending !== ""

    property string pending: ""        // the dangerous action waiting for "yes"
    onClosed: pending = ""

    // Whether hibernating can work (enough swap, a resume device): logind knows.
    // Asked once, the first time the panel opens.
    property bool canHibernate: false
    onOpening: {
        Updates.checkIfStale();
        if (!hibernateCheck.asked)
            askHibernate();
    }
    function askHibernate() {
        hibernateCheck.asked = true;
        hibernateCheck.running = true;
    }
    Process {
        id: hibernateCheck
        property bool asked: false
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: power.canHibernate = text.trim() === 's "yes"'
        }
    }

    // `lock`: the command waits until the screen is locked. `--no-ask-password`
    // there, since a password dialog can't show over the lock. The dangerous ones ask
    // "yes" first; polkit may still ask for a password (another user logged in).
    readonly property var safeActions: [
        { title: "Lock", icon: "system-lock-screen-symbolic", lock: true, argv: [], danger: false },
        { title: "Sleep", icon: "weather-clear-night-symbolic", lock: true, argv: ["systemctl", "--no-ask-password", "suspend"], danger: false },
        { title: "Hibernate", icon: "media-playback-pause-symbolic", lock: true, argv: ["systemctl", "--no-ask-password", "hibernate"], danger: false }
    ].filter(a => a.title !== "Hibernate" || canHibernate)
    readonly property var dangerActions: [
        { title: "Log out", icon: "system-log-out-symbolic", lock: false, argv: ["hyprctl", "dispatch", "hl.dsp.exit()"], danger: true },
        { title: "Restart", icon: "system-reboot-symbolic", lock: false, argv: ["systemctl", "reboot"], danger: true },
        { title: "Shut down", icon: "system-shutdown-symbolic", lock: false, argv: ["systemctl", "poweroff"], danger: true }
    ]

    function run(a) {
        pending = "";
        power.close();
        if (a.lock && a.argv.length > 0)
            ShellState.lockThen(a.argv, a.title);
        else if (a.lock)
            ShellState.lock();
        else
            Commands.run(a.argv, a.title);
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spaceM

        Item {
            width: parent.width
            height: 40

            Row {
                spacing: Theme.spaceM

                Rectangle {
                    width: 40
                    height: 40
                    radius: width / 2
                    color: Battery.charging ? Theme.accentSoft : Theme.card
                    Icon {
                        anchors.centerIn: parent
                        size: 20
                        name: Battery.icon
                        color: Battery.level
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    StyledText {
                        text: Battery.present ? Battery.pct + " %" : "Power"
                        font.pixelSize: Theme.textHeading
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: Battery.detail
                        color: Theme.muted
                        font.pixelSize: Theme.textSmall
                    }
                }
            }

            // Package updates, when there are some (services/Updates.qml).
            PillButton {
                visible: Updates.count > 0
                anchors.right: awakeButton.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                height: 36
                icon: "software-update-available-symbolic"
                text: String(Updates.count)
                tip: Updates.summary + "\n" + Updates.repo.concat(Updates.aur).slice(0, 6).map(u => u.name).join(", ")
                    + (Updates.count > 6 ? "…" : "") + "\nClick: update in a terminal"
                onClicked: {
                    power.close();
                    Updates.install();
                }
            }
            // Keep awake (the idle inhibitor lives in ScreenSurface).
            PillButton {
                id: awakeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                glyph: ShellState.keepAwake ? Glyphs.keepAwake : Glyphs.keepAwakeOff
                iconSize: 16
                active: ShellState.keepAwake
                tip: "Keep awake\nNothing dims, locks or sleeps while it's on"
                onClicked: ShellState.keepAwake = !ShellState.keepAwake
            }
        }

        // The actions, safe ones over dangerous ones, or the confirmation for the
        // one waiting for "yes".
        Item {
            width: parent.width
            height: 2 * 46 + rows.spacing

            Column {
                id: rows
                anchors.fill: parent
                spacing: Theme.spaceS
                opacity: power.pending === "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.msFast } }

                Repeater {
                    model: [power.safeActions, power.dangerActions]

                    Row {
                        id: actionRow
                        required property var modelData
                        width: rows.width
                        spacing: Theme.spaceS

                        Repeater {
                            model: actionRow.modelData

                            PillButton {
                                required property var modelData
                                width: (actionRow.width - (actionRow.modelData.length - 1) * actionRow.spacing) / actionRow.modelData.length
                                height: 46
                                radius: Theme.radiusM
                                icon: modelData.icon
                                text: modelData.title
                                danger: modelData.danger
                                onClicked: modelData.danger ? power.pending = modelData.title : power.run(modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusL
                color: Theme.mix(Theme.bg, Theme.bad, 0.16)
                opacity: power.pending !== "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.msFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spaceM
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: power.pending + "?"
                        font.pixelSize: Theme.textTitle
                        font.weight: Font.DemiBold
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spaceS
                        PillButton {
                            text: "Cancel"
                            onClicked: power.pending = ""
                        }
                        PillButton {
                            text: "Yes, " + power.pending.toLowerCase()
                            restColor: Theme.bad
                            danger: true
                            onClicked: power.run(power.dangerActions.find(a => a.title === power.pending))
                        }
                    }
                }
            }
        }

        Row {
            id: modes
            width: parent.width
            spacing: Theme.spaceS

            Repeater {
                model: PowerModes.list

                PillButton {
                    required property var modelData
                    width: (modes.width - (PowerModes.list.length - 1) * modes.spacing) / PowerModes.list.length
                    height: 30
                    icon: modelData.icon
                    text: modelData.title
                    iconSize: 13
                    active: PowerProfiles.profile === modelData.profile
                    onClicked: PowerProfiles.profile = modelData.profile
                }
            }
        }
        StyledText {
            visible: PowerModes.limited !== ""
            text: "Limited: " + PowerModes.limited
            color: Theme.warn
            font.pixelSize: Theme.textCaption
        }
    }
}
