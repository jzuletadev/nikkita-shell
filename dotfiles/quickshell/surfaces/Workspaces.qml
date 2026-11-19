// ~/nikita-shell/dotfiles/quickshell/surfaces/Workspaces.qml
//
// The workspace rail, on the left edge. With ALT+TAB it grows: the windows, the
// most recent first, unfold beside the workspaces (services/WindowSwitch.qml), and
// the rail's mark jumps to the workspace of the window you are about to pick.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services

EdgePanel {
    id: rail

    name: "workspaces"
    edge: "left"
    placement: "center"
    depth: m.rail + listWidth * wide
    span: Math.max(column.implicitHeight, wide > 0 ? windowList.height : 0) + 2 * inset
    inset: 12
    pinned: holding
    shadowed: wide === 0

    Behavior on span {
        NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth }
    }

    readonly property var monitor: Hyprland.monitors.values.find(mo => mo.name === rail.screenName) ?? null
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor && w.monitor.name === rail.screenName)
        .sort((a, b) => a.id - b.id)

    // "You are here" (the workspace keys, through ShellState): the rail peeks, and
    // when the workspace on screen didn't change (it was already there, only the
    // focus moved), its mark bounces again, so you still see where you are.
    property int bounceTick: 0
    Connections {
        target: ShellState
        function onLocateRequested(where) {
            if (where !== rail.screenName || !Prefs.railPeek)
                return;
            rail.peek(1400);
            if (rail.shownId === rail.activeId)
                rail.bounceTick++;
        }
    }

    // Follows activeId, but waits while the rail comes in, so the change is seen.
    property int shownId: -1
    onActiveIdChanged: {
        if (shownId <= 0 || activeId <= 0) {   // starting up: nothing to show
            shownId = activeId;
            return;
        }
        if (Prefs.railPeek)
            rail.peek(1400);
        if (progress > 0.95)
            shownId = activeId;
        else
            showTimer.restart();
    }
    Timer {
        id: showTimer
        interval: 180
        onTriggered: rail.shownId = rail.activeId
    }

    // ---- ALT+TAB: the rail grows ----
    readonly property bool switchHere: WindowSwitch.shown && ShellState.switcherScreen === screenName
    property bool holding: false      // open until it has shrunk back
    property real wide: 0             // 0 the rail, 1 the rail and the windows
    property real rowsIn: 0           // the rows' cascade, 0 to 1 in time
    readonly property int listWidth: Math.round(m.corner * 0.95)
    readonly property int rowHeight: 44
    readonly property int rows: Math.min(9, WindowSwitch.windows.length)
    // Each row starts 30 ms after the one above and takes 220 ms.
    readonly property int cascadeMs: 220 + 30 * Math.max(0, rows - 1)
    function rowIn(i) {
        const p = Math.max(0, Math.min(1, (rowsIn * cascadeMs - i * 30) / 220));
        return 1 - Math.pow(1 - p, 3);
    }
    onSwitchHereChanged: {
        if (switchHere) {
            holding = true;
            shrink.stop();
            extend.start();
        } else if (holding) {
            extend.stop();
            shrink.start();
        }
    }
    // The rail comes in as always, then stretches with a little spring.
    SequentialAnimation {
        id: extend
        PauseAnimation { duration: Theme.ms(110) }
        ParallelAnimation {
            NumberAnimation { target: rail; property: "wide"; to: 1; duration: Theme.ms(420); easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            NumberAnimation { target: rail; property: "rowsIn"; to: 1; duration: rail.cascadeMs }
        }
    }
    ParallelAnimation {
        id: shrink
        NumberAnimation { target: rail; property: "rowsIn"; to: 0; duration: Theme.ms(90) }
        NumberAnimation { target: rail; property: "wide"; to: 0; duration: Theme.ms(240); easing.type: Easing.InCubic }
        onFinished: {
            rail.holding = false;
            WindowSwitch.settle();
        }
    }
    // Where the grown rail is, so the switcher's keyboard surface lets its clicks through.
    Binding {
        target: ShellState
        property: "switcherRail"
        when: rail.holding && ShellState.switcherScreen === rail.screenName
        value: Qt.rect(0, rail.longPos, Math.max(1, rail.extent), rail.span)
    }

    function goTo(dest) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${dest} })`);
    }

    // `+1` creates the next workspace if it doesn't exist.
    WheelHandler {
        enabled: !rail.holding
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: ev => rail.goTo(ev.angleDelta.y < 0 ? '"+1"' : '"-1"')
    }

    // Centered in the rail's own width and height, so it stays put as the panel grows.
    Column {
        id: column
        x: (rail.m.rail - width) / 2 - rail.inset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceM

        MouseArea {
            id: logo
            width: 22
            height: 22
            anchors.horizontalCenter: parent.horizontalCenter
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.toggleSettings("about")
            Tip { text: "About this computer"; side: "right" }

            Logo {
                anchors.centerIn: parent
                size: 22
                scale: logo.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: Theme.msFast } }
            }
        }

        Rectangle {
            width: 18
            height: 1
            color: Theme.divider
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Column {
            spacing: Theme.spaceS
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: rail.workspaces

                MouseArea {
                    id: cell
                    required property var modelData
                    // While switching, the workspace of the window you would pick.
                    readonly property bool isActive: modelData.id === (rail.holding && WindowSwitch.chosenWorkspace > 0 ? WindowSwitch.chosenWorkspace : rail.shownId)
                    readonly property bool hasWindows: modelData.toplevels.values.length > 0
                    // 0 = the small hexagon, 1 = the big one (it overshoots: the bounce).
                    property real morph: isActive ? 1 : 0
                    Behavior on morph {
                        NumberAnimation {
                            duration: cell.isActive ? 520 : Theme.msNormal
                            easing.type: cell.isActive ? Easing.OutBack : Easing.InOutQuad
                            easing.overshoot: 2.6
                        }
                    }

                    // The extra bounce of "you are here", once the rail is in.
                    property real pop: 1
                    readonly property int tick: rail.bounceTick
                    onTickChanged: if (isActive) popAnim.restart()
                    SequentialAnimation {
                        id: popAnim
                        PropertyAction { target: cell; property: "pop"; value: 0.35 }
                        PauseAnimation { duration: Theme.ms(120) }
                        NumberAnimation { target: cell; property: "pop"; to: 1; duration: Theme.ms(520); easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                    }

                    width: 20
                    height: 17
                    anchors.horizontalCenter: parent.horizontalCenter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rail.goTo(modelData.id)

                    // Solid if it has windows, hollow if it is empty.
                    HexShape {
                        anchors.centerIn: parent
                        height: 10
                        width: Math.round(height * Theme.hexRatio)
                        scale: Math.max(0, 1 - cell.morph) * (cell.containsMouse ? 1.3 : 1)
                        fill: cell.hasWindows ? Theme.muted : "transparent"
                        stroke: cell.hasWindows ? "transparent" : Theme.faint
                        strokeWidth: cell.hasWindows ? 0 : 1.2
                    }

                    // Where you are: filled, as everything chosen.
                    HexShape {
                        anchors.centerIn: parent
                        height: 16
                        width: Math.round(height * Theme.hexRatio)
                        fill: Theme.accent
                        visible: cell.morph > 0.01
                        scale: cell.morph * cell.pop
                        rotation: (1 - cell.morph * cell.pop) * -60
                        opacity: Math.min(1, cell.morph * 2)
                    }
                }
            }
        }
    }

    // ---- the windows, beside the workspaces ----
    Rectangle {
        x: rail.m.rail - rail.inset - Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: windowList.height
        color: Theme.divider
        opacity: Math.min(1, rail.wide * 2)
        visible: rail.wide > 0.01
    }
    ListView {
        id: windowList
        x: rail.m.rail - rail.inset + Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        width: rail.listWidth - rail.inset - 2 * Theme.spaceXs
        height: rail.rows * rail.rowHeight + Math.max(0, rail.rows - 1) * spacing
        visible: rail.wide > 0.01
        spacing: Theme.spaceXxs
        interactive: false
        model: WindowSwitch.windows
        currentIndex: WindowSwitch.selected
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        // The choice slides from row to row.
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Theme.msFast
        highlightMoveVelocity: -1
        highlight: Rectangle {
            radius: Theme.radiusM
            color: Theme.accentSoft
            opacity: rail.rowIn(Math.min(WindowSwitch.selected, 8))
        }

        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            readonly property bool isChosen: WindowSwitch.selected === index
            readonly property real enter: rail.rowIn(Math.min(index, 8))
            width: ListView.view.width
            height: rail.rowHeight
            opacity: enter
            // In from the rail's side.
            transform: Translate { x: -14 * (1 - entry.enter) }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusM
                color: winArea.containsMouse && !entry.isChosen ? Theme.card : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.msFast } }
            }
            AppIcon {
                x: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                name: entry.modelData.icon
                size: 26
            }
            Column {
                x: 44
                width: parent.width - x - Theme.spaceS - (where.visible ? where.width + Theme.spaceS : 0)
                anchors.verticalCenter: parent.verticalCenter
                StyledText {
                    width: parent.width
                    text: entry.modelData.title
                    font.weight: Font.DemiBold
                    color: entry.isChosen ? Theme.accent : Theme.fg
                }
                StyledText {
                    width: parent.width
                    visible: text !== "" && text !== entry.modelData.title
                    text: entry.modelData.app
                    color: Theme.muted
                    font.pixelSize: Theme.textSmall
                }
            }
            StyledText {
                id: where
                visible: text !== ""
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.where
                color: Theme.dim
                font.pixelSize: Theme.textCaption
            }
            MouseArea {
                id: winArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WindowSwitch.pick(entry.index)
            }
        }
    }
}
