// ~/nikita-shell/dotfiles/quickshell/surfaces/Tray.qml

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.common
import qs.services

EdgePanel {
    id: tray

    name: "tray"
    edge: "bottom"
    placement: "center"
    depth: 58
    span: Math.max(m.trayWidth, row.implicitWidth + 2 * inset + 2 * m.notch)
    inset: 12
    // With a menu open the pointer is on the menu, not here: don't close.
    pinned: menu.visible

    Behavior on span {
        NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth }
    }

    // Services: when the tray opens, then every 10 s while it stays open.
    onOpening: Background.refresh()
    Timer {
        running: tray.isOpen
        interval: 10000
        repeat: true
        onTriggered: Background.refresh()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: Recorder.active && tray.isOpen
    }

    // A QsMenuAnchor isn't an Item and can't find its window itself.
    readonly property var hostWindow: QsWindow.window

    QsMenuAnchor {
        id: menu
        anchor.window: tray.hostWindow
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Rectangle {
            visible: Recorder.active
            height: 34
            width: rec.implicitWidth + 24
            radius: height / 2
            color: recArea.containsMouse ? Theme.bad : Theme.mix(Theme.bg, Theme.bad, 0.2)
            Behavior on color { ColorAnimation { duration: Theme.msFast } }

            Row {
                id: rec
                anchors.centerIn: parent
                spacing: Theme.spaceS
                Rectangle {
                    width: 9
                    height: 9
                    radius: width / 2
                    color: recArea.containsMouse ? Theme.badInk : Theme.bad
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: Recorder.active && tray.isOpen
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 700 }
                        NumberAnimation { to: 1; duration: 700 }
                    }
                }
                StyledText {
                    text: {
                        const s = Math.max(0, Math.floor((clock.date.getTime() - Recorder.startedAt) / 1000));
                        return "REC " + Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
                    }
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.textLabel
                    color: recArea.containsMouse ? Theme.badInk : Theme.bad
                }
            }
            MouseArea {
                id: recArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Recorder.stop()
                Tip { text: "Stop recording" }
            }
        }

        // Who uses the microphone, the camera or the screen (services/Privacy.qml).
        Repeater {
            model: [
                { what: "Microphone", icon: "microphone-sensitivity-high-symbolic", apps: Privacy.mic, page: "sound" },
                { what: "Camera", icon: "camera-web-symbolic", apps: Privacy.camera, page: "" },
                { what: "Screen", icon: "screen-shared-symbolic", apps: Privacy.screen, page: "" }
            ].filter(u => u.apps.length > 0)

            Rectangle {
                id: use
                required property var modelData
                height: 34
                width: useRow.implicitWidth + 24
                radius: height / 2
                color: useArea.containsMouse && modelData.page !== "" ? Theme.warn : Theme.mix(Theme.bg, Theme.warn, 0.2)
                Behavior on color { ColorAnimation { duration: Theme.msFast } }
                readonly property color ink: useArea.containsMouse && modelData.page !== "" ? Theme.bg : Theme.warn

                Row {
                    id: useRow
                    anchors.centerIn: parent
                    spacing: Theme.spaceS
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: use.modelData.icon
                        size: 14
                        color: use.ink
                    }
                    StyledText {
                        text: use.modelData.apps.join(", ")
                        font.pixelSize: Theme.textLabel
                        color: use.ink
                    }
                }
                MouseArea {
                    id: useArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: use.modelData.page !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (use.modelData.page !== "") {
                        tray.close();
                        ShellState.openSettings(use.modelData.page);
                    }
                    Tip {
                        text: use.modelData.what + " in use: " + use.modelData.apps.join(", ")
                            + (use.modelData.page !== "" ? "\nClick: sound settings" : "\nThe app that uses it can stop it")
                    }
                }
            }
        }

        // Apps with windows: a click goes to the next one.
        Repeater {
            model: Background.apps

            MouseArea {
                id: app
                required property var modelData
                readonly property bool allMinimized: modelData.minimized === modelData.windows.length
                width: 34
                height: 34
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: Tooltips.cancel(app)
                onClicked: ev => ev.button === Qt.RightButton ? Background.restore(modelData) : Background.show(modelData)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusM
                    color: app.containsMouse ? Theme.mix(Theme.bg, Theme.fg, 0.3) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.msFast } }
                }
                AppIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    size: 20
                    name: app.modelData.icon
                    opacity: app.allMinimized ? 0.5 : 1
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spaceXxs
                    spacing: Theme.spaceXxs
                    Repeater {
                        model: Math.min(3, app.modelData.windows.length)
                        Rectangle {
                            width: 4
                            height: 4
                            radius: width / 2
                            color: app.modelData.active ? Theme.fg : Theme.dim
                        }
                    }
                }
                Tip {
                    text: app.modelData.name + "\n" + Background.describe(app.modelData)
                        + (app.modelData.minimized > 0 ? " · right click: bring them here" : "")
                }
            }
        }
        Rectangle {
            visible: Background.apps.length > 0 && (SystemTray.items.values.length > 0 || Background.running.length > 0)
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            color: Theme.divider
        }

        Repeater {
            model: SystemTray.items

            MouseArea {
                id: item
                required property SystemTrayItem modelData
                width: 34
                height: 34
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                function openMenu() {
                    if (!modelData.hasMenu)
                        return;
                    menu.menu = modelData.menu;
                    menu.anchor.item = item;
                    menu.open();
                }
                onClicked: ev => {
                    if (ev.button === Qt.RightButton || (ev.button === Qt.LeftButton && modelData.onlyMenu))
                        openMenu();
                    else if (ev.button === Qt.MiddleButton)
                        modelData.secondaryActivate();
                    else
                        modelData.activate();
                }
                onWheel: ev => modelData.scroll(ev.angleDelta.y / 120, false)
                onPressed: Tooltips.cancel(item)

                Tip {
                    text: {
                        const d = item.modelData;
                        const name = d.tooltipTitle || d.title || d.id;
                        const more = (d.tooltipDescription || "").replace(/<[^>]*>/g, "").trim();
                        const how = d.hasMenu && !d.onlyMenu ? "Right click: menu" : "";
                        return [name, more || how].filter(x => x).join("\n");
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusM
                    // Not inverted: a white tray icon would vanish on white.
                    color: item.containsMouse ? Theme.mix(Theme.bg, Theme.fg, 0.3) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.msFast } }
                }
                AppIcon {
                    anchors.centerIn: parent
                    size: 20
                    name: item.modelData.icon
                    opacity: item.modelData.status === Status.Passive ? 0.6 : 1
                }
                Rectangle {
                    visible: item.modelData.status === Status.NeedsAttention
                    width: 6
                    height: 6
                    radius: width / 2
                    color: Theme.accent
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spaceXs
                }
            }
        }

        // Known services while they run: a click opens a terminal on it.
        Repeater {
            model: Background.running

            MouseArea {
                id: service
                required property var modelData
                width: 34
                height: 34
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: Tooltips.cancel(service)
                onClicked: {
                    tray.close();
                    Background.open(modelData);
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusM
                    color: service.containsMouse ? Theme.mix(Theme.bg, Theme.fg, 0.3) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.msFast } }
                }
                Glyph {
                    anchors.centerIn: parent
                    code: service.modelData.glyph
                    size: 18
                }
                Tip {
                    text: service.modelData.name + " is running\n"
                        + (service.modelData.id === "docker" && Background.dockerNote !== "" ? Background.dockerNote + " · " : "")
                        + "click: open in a terminal"
                }
            }
        }

        StyledText {
            visible: SystemTray.items.values.length === 0 && Background.apps.length === 0 && Background.running.length === 0 && !Recorder.active
            text: "Nothing running"
            color: Theme.dim
            font.pixelSize: Theme.textSmall
            height: 34
        }
    }
}
