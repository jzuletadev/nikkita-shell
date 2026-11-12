// ~/nikkita-shell/dotfiles/quickshell/settings/SettingsWindow.qml
//
// The Settings window (`qs ipc call nikkita settings [page]`). Each page is built when
// chosen, so Wi-Fi only scans while its page is shown.
//
// Keys: typing anywhere filters the pages (Up/Down pick, Enter opens); Escape
// clears the filter, then leaves a text field, then closes.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services
import "../common/Fuzzy.js" as Fuzzy

FloatingWindow {
    id: win

    title: "Settings"
    // Opaque: a window you read in. Transparency (Settings → Appearance) is for the panels.
    color: Theme.bg
    implicitWidth: 1120
    implicitHeight: 720
    minimumSize: Qt.size(860, 560)

    // Sized once: a binding would resize it whenever focus changed monitor.
    Component.onCompleted: {
        const s = Quickshell.screens.find(x => x.name === ShellState.focusedScreen());
        if (s) {
            implicitWidth = Math.round(Math.max(860, Math.min(1120, s.width * 0.62)));
            implicitHeight = Math.round(Math.max(560, Math.min(740, s.height * 0.72)));
        }
    }

    // Closed from Hyprland (SUPER + Q) too: shell.qml unloads it.
    onVisibleChanged: if (!visible) ShellState.settingsOpen = false

    // ---- it closes when you go elsewhere ----
    // Like a menu: while it is open the pointer and the keys stay here, and the
    // first click outside closes it; so do the launcher, ALT+TAB and a new window
    // opening. Not the pointer just leaving it: with follow_mouse, Hyprland calls
    // the window under the pointer the active one even while this holds the keys
    // (measured), so "the active window changed" can't mean "you left". Not while
    // it waits for something it opened elsewhere: the file chooser, the password
    // dialog, or "Keep these display settings?".
    readonly property bool waiting: ShellState.settingsWaiting || ShellState.authAsking || Monitors.asking
    function lostFocus() {
        if (!waiting)
            ShellState.settingsOpen = false;
    }
    HyprlandFocusGrab {
        windows: [win]
        active: win.visible && !win.waiting
        onCleared: win.lostFocus()
    }
    Connections {
        target: Hyprland
        // "address,workspace,class,title": Settings opening is one too.
        function onRawEvent(ev) {
            if (ev.name !== "openwindow")
                return;
            const f = ev.data.split(",");
            if (!(f[2] === "org.quickshell" && f.slice(3).join(",") === win.title))
                win.lostFocus();
        }
    }
    Connections {
        target: ShellState
        function onLauncherScreenChanged() {
            if (ShellState.launcherScreen !== "")
                win.lostFocus();
        }
        function onSwitcherScreenChanged() {
            if (ShellState.switcherScreen !== "")
                win.lostFocus();
        }
    }

    readonly property var pages: SettingsPages.list
    readonly property var current: pages.find(p => p.id === ShellState.settingsPage) ?? pages[0]

    // ---- the filter ----
    readonly property string query: search.text.trim()
    readonly property var shown: {
        if (!query)
            return pages;
        return pages.map(p => [Fuzzy.fields(query, [p.title, p.subtitle + " " + p.keys]), p])
            .filter(x => x[0] !== null)
            .sort((a, b) => b[0] - a[0])
            .map(x => x[1]);
    }
    // While filtering, the results are one group; otherwise, the pages' groups.
    readonly property var groups: {
        if (query)
            return shown.length > 0 ? [shown] : [];
        const g = [];
        for (const p of pages)
            (g[p.group] = g[p.group] || []).push(p);
        return g.filter(x => x);
    }
    property int cursor: 0
    onQueryChanged: cursor = 0

    function open(id) {
        ShellState.settingsPage = id;
        search.text = "";
        root.forceActiveFocus();
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true

        Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Escape) {
                if (search.text !== "")
                    search.text = "";
                else if (root.Window.activeFocusItem !== root && root.Window.activeFocusItem !== null)
                    root.forceActiveFocus();
                else
                    ShellState.settingsOpen = false;
                ev.accepted = true;
            } else if (ev.text.length === 1 && ev.text > " " && ev.text !== "\u007f" && !(ev.modifiers & Qt.ControlModifier)) {
                search.input.forceActiveFocus();
                search.text += ev.text;
                ev.accepted = true;
            }
        }

        // ================================================================ sidebar
        Item {
            id: side
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spaceL
            width: 300

            InputField {
                id: search
                width: parent.width
                height: 44
                placeholder: "Search settings"
                color: Theme.alpha(Theme.fg, 0.06)
                onSubmitted: if (win.shown.length > 0) win.open(win.shown[Math.min(win.cursor, win.shown.length - 1)].id)
                onSpecialKey: ev => {
                    if (ev.key === Qt.Key_Down) {
                        win.cursor = Math.min(win.shown.length - 1, win.cursor + 1);
                        ev.accepted = true;
                    } else if (ev.key === Qt.Key_Up) {
                        win.cursor = Math.max(0, win.cursor - 1);
                        ev.accepted = true;
                    }
                }
            }

            Flickable {
                id: navScroll
                anchors.top: search.bottom
                anchors.topMargin: Theme.spaceM
                anchors.bottom: parent.bottom
                width: parent.width
                contentHeight: nav.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: nav
                    width: parent.width
                    spacing: Theme.spaceS

                    Repeater {
                        model: win.groups

                        Rectangle {
                            id: group
                            required property var modelData
                            width: nav.width
                            height: items.implicitHeight + 8
                            radius: Theme.radiusL
                            color: Theme.alpha(Theme.fg, 0.035)

                            Column {
                                id: items
                                x: 4
                                y: 4
                                width: parent.width - 8
                                Repeater {
                                    model: group.modelData
                                    NavItem {
                                        required property var modelData
                                        page: modelData
                                        selected: modelData.id === win.current.id
                                        cursor: win.query !== "" && win.shown.indexOf(modelData) === win.cursor
                                        onClicked: win.open(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: win.groups.length === 0
                        width: nav.width
                        text: "Nothing matches “" + win.query + "”"
                        color: Theme.dim
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: Theme.spaceXl
                    }
                }
            }
            ScrollHint { view: navScroll }
        }

        // ================================================================== page
        Item {
            id: main
            anchors.left: side.right
            anchors.leftMargin: Theme.spaceXl
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            StyledText {
                id: heading
                y: 24
                x: 4
                text: win.current.title
                font.pixelSize: Theme.textDisplay
                font.weight: Font.DemiBold
            }

            PillButton {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Theme.spaceL
                height: 34
                flat: true
                icon: "window-close-symbolic"
                iconSize: 15
                tip: "Close\nEsc"
                onClicked: ShellState.settingsOpen = false
            }

            Flickable {
                id: scroller
                anchors.top: heading.bottom
                anchors.topMargin: Theme.spaceXl
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceM
                contentHeight: loader.height + 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: loader
                    width: scroller.width
                    source: Qt.resolvedUrl(win.current.id.charAt(0).toUpperCase() + win.current.id.slice(1) + "Page.qml")
                    opacity: 0
                    transform: Translate { id: shift }
                    onLoaded: {
                        scroller.contentY = 0;
                        enter.restart();
                    }
                }

                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: loader; property: "opacity"; from: 0; to: 1; duration: Theme.msNormal }
                    NumberAnimation { target: shift; property: "y"; from: 18; to: 0; duration: Theme.msSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter }
                }
            }
            ScrollHint { view: scroller }
        }
    }

    TooltipLayer {}
}
