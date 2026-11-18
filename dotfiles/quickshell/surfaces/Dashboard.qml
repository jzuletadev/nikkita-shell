// ~/nikita-shell/dotfiles/quickshell/surfaces/Dashboard.qml

import QtQuick
import Quickshell
import qs.common
import qs.services

EdgePanel {
    id: dash

    name: "dashboard"
    edge: "top"
    placement: "center"
    span: m.centerWidth
    depth: 340
    inset: 16

    property int tab: 0
    // With nothing playing, the music card narrows to a way in to your library and
    // the clock and the calendar take the room.
    readonly property bool playing: Media.hasTrack
    readonly property real cardsWidth: page.width - 2 * Theme.spaceL
    readonly property bool watchingPerf: isOpen && tab === 1
    onWatchingPerfChanged: SystemStats.watch(watchingPerf)
    // On config reload the dashboard is destroyed while watching: let go.
    Component.onDestruction: if (watchingPerf) SystemStats.watch(false)

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: dash.isOpen
    }

    // ---- tabs ----
    Row {
        id: tabs
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceS
        PillButton {
            text: "Dashboard"
            icon: "view-grid-symbolic"
            height: 28
            active: dash.tab === 0
            onClicked: dash.tab = 0
        }
        PillButton {
            text: "Performance"
            icon: "power-profile-performance-symbolic"
            height: 28
            active: dash.tab === 1
            onClicked: dash.tab = 1
        }
    }

    Item {
        id: page
        anchors.top: tabs.bottom
        anchors.topMargin: Theme.spaceL
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Row {
            id: start
            anchors.fill: parent
            opacity: dash.tab === 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.msNormal } }
            spacing: Theme.spaceL

            // --- the clock ---
            Rectangle {
                width: dash.cardsWidth * (dash.playing ? 0.26 : 0.30)
                height: page.height
                Behavior on width { NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth } }
                radius: Theme.radiusL
                color: Theme.card

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spaceM
                    BigClock {
                        anchors.horizontalCenter: parent.horizontalCenter
                        date: clock.date
                        size: 86
                    }
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spaceXxs
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(clock.date, "dddd").toUpperCase()
                            color: Theme.accent
                            font.pixelSize: Theme.textLabel
                            font.weight: Font.Bold
                            font.letterSpacing: 2
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(clock.date, "d MMMM yyyy")
                            color: Theme.muted
                            font.pixelSize: Theme.textLabel
                        }
                    }
                }
            }

            // --- the calendar ---
            Rectangle {
                width: dash.cardsWidth * (dash.playing ? 0.36 : 0.48)
                height: page.height
                Behavior on width { NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth } }
            id: cal
            radius: Theme.radiusL
            color: Theme.card

            // Months from now; Date handles the year rollover.
            property int monthOffset: 0
            readonly property date today: clock.date
            readonly property int monthIndex: today.getFullYear() * 12 + today.getMonth() + monthOffset
            readonly property int year: Math.floor(monthIndex / 12)
            readonly property int month: ((monthIndex % 12) + 12) % 12
            readonly property var days: {
                const first = new Date(year, month, 1);
                const start = (first.getDay() + 6) % 7;       // Monday first
                const v = [];
                for (let i = 0; i < 42; i++) {
                    const d = new Date(year, month, 1 - start + i);
                    v.push({ day: d.getDate(), inMonth: d.getMonth() === month,
                        isToday: d.toDateString() === today.toDateString() });
                }
                // If the last row is entirely next month, drop it.
                return v.slice(0, v[35].inMonth ? 42 : 35);
            }

            Connections {
                target: dash
                function onClosed() { cal.monthOffset = 0; }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceM
                spacing: Theme.spaceXs

                Item {
                    width: parent.width
                    height: 24
                    PillButton {
                        anchors.left: parent.left
                        height: 24
                        flat: true
                        icon: "go-previous-symbolic"
                        iconSize: 12
                        onClicked: cal.monthOffset--
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: Qt.formatDate(new Date(cal.year, cal.month, 1), "MMMM yyyy")
                        font.weight: Font.DemiBold
                        font.capitalization: Font.Capitalize
                        color: cal.monthOffset === 0 ? Theme.fg : Theme.accent
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cal.monthOffset = 0
                        }
                    }
                    PillButton {
                        anchors.right: parent.right
                        height: 24
                        flat: true
                        icon: "go-next-symbolic"
                        iconSize: 12
                        onClicked: cal.monthOffset++
                    }
                }

                Grid {
                    id: dayGrid
                    width: parent.width
                    columns: 7
                    readonly property real cell: width / 7
                    readonly property real itemHeight: (parent.height - 28 - 4 - 18) / (cal.days.length / 7)

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        StyledText {
                            required property string modelData
                            width: dayGrid.cell
                            height: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.dim
                            font.pixelSize: Theme.textCaption
                            font.weight: Font.DemiBold
                        }
                    }
                    Repeater {
                        model: cal.days
                        Item {
                            required property var modelData
                            width: dayGrid.cell
                            height: dayGrid.itemHeight
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 2
                                height: width
                                radius: width / 2
                                color: parent.modelData.isToday ? Theme.accent : "transparent"
                            }
                            StyledText {
                                anchors.centerIn: parent
                                text: parent.modelData.day
                                font.pixelSize: Theme.textSmall
                                font.weight: parent.modelData.isToday ? Font.Bold : Font.Normal
                                color: parent.modelData.isToday ? Theme.accentText : parent.modelData.inMonth ? Theme.fg : Theme.dim
                                opacity: parent.modelData.inMonth ? 1 : 0.6
                            }
                        }
                    }
                }
            }
            }

            // --- what's playing ---
            NowPlaying {
                width: dash.cardsWidth * (dash.playing ? 0.38 : 0.22)
                height: page.height
                Behavior on width { NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth } }
                live: dash.isOpen
            }
        }
        Performance {
            id: perf
            anchors.fill: parent
            opacity: dash.tab === 1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.msNormal } }
        }
    }
}
