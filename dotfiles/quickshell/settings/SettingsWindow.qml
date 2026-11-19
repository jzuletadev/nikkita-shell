// ~/nikita-shell/dotfiles/quickshell/settings/SettingsWindow.qml
//
// The Settings window (`qs ipc call nikita settings [page]`). Each page is built when
// chosen, so Wi-Fi only scans while its page is shown.
//
// Keys: typing anywhere filters the pages. Up and Down pick a page in the sidebar,
// Enter opens it; Tab (or the arrows, once inside a page) moves between the controls,
// Enter and Space press, Left and Right move a slider. Escape clears the filter, then
// leaves the control, then closes.
//
// It is a floating window sized to the screen, and a menu while floating: the pointer
// and keys stay in it and a click on the bare desktop closes it. A click on another
// window, another window opening or ALT+TAB tiles it instead (`docked`), beside what
// you went to: then it is a window like any other and a narrow one keeps only the
// sidebar's icons.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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
    // Floating it needs room for the sidebar and a page; tiled it takes what it is given.
    minimumSize: docked ? Qt.size(420, 360) : Qt.size(900, 560)

    // Sized once: a binding would resize it whenever focus changed monitor. Most of
    // the screen, so the sidebar's pages and the first page's rows show without scrolling.
    Component.onCompleted: {
        const s = Quickshell.screens.find(x => x.name === ShellState.focusedScreen());
        if (s) {
            implicitWidth = Math.round(Math.max(900, Math.min(1180, s.width * 0.74)));
            implicitHeight = Math.round(Math.max(560, Math.min(900, s.height * 0.86)));
        }
    }

    // A narrow window (tiled beside another) shows the sidebar as icons; a short
    // one shows its rows without the subtitle, so all the pages fit.
    readonly property bool narrow: width < 900
    readonly property bool dense: height < 940

    // Closed from Hyprland (SUPER + Q) too: shell.qml unloads it.
    onVisibleChanged: if (!visible) ShellState.settingsOpen = false

    // ---- where it goes when you go elsewhere ----
    // Like a menu: while it floats the pointer and the keys stay here, and the first
    // click outside decides. On the bare desktop it closes; on another window it tiles
    // itself next to it and lets the click through. A new window opening and ALT+TAB
    // tile it too. Not the pointer just leaving it: with follow_mouse, Hyprland calls
    // the window under the pointer the active one even while this holds the keys
    // (measured), so "the active window changed" can't mean "you left". Not while
    // it waits for something it opened elsewhere: the file chooser, the password
    // dialog, or "Keep these display settings?". The launcher doesn't move it: it
    // opens over it and gives the keys back.
    readonly property bool waiting: ShellState.settingsWaiting || ShellState.authAsking || Monitors.asking
    property bool docked: false
    function dock() {
        if (docked || waiting)
            return;
        docked = true;
        Hyprland.dispatch('hl.dsp.window.float({ action = "unset", window = "title:^Settings$" })');
    }
    function lostFocus() {
        if (!waiting && !docked)
            probe.running = true;
    }
    // What is under the pointer: a window (tile beside it) or nothing (close).
    Process {
        id: probe
        command: [Paths.script("pointer-target.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (ShellState.launcherScreen !== "" || ShellState.switcherScreen !== "")
                    return;
                // "self": the pointer is over Settings, so the grab was lost by itself
                // (windows coming back); take it again.
                if (text.trim() === "self")
                    grab.rearm();
                else if (text.trim() !== "")
                    win.dock();
                else if (!win.waiting)
                    ShellState.settingsOpen = false;
            }
        }
    }
    HyprlandFocusGrab {
        id: grab
        windows: [win]
        property bool off: false
        active: win.visible && !win.waiting && !win.docked && ShellState.launcherScreen === "" && !off
        onCleared: win.lostFocus()
        function rearm() {
            off = true;
            Qt.callLater(() => off = false);
        }
    }
    Connections {
        target: Hyprland
        // "address,workspace,class,title": Settings opening is one too.
        function onRawEvent(ev) {
            if (ev.name !== "openwindow")
                return;
            const f = ev.data.split(",");
            if (!(f[2] === "org.quickshell" && f.slice(3).join(",") === win.title))
                win.dock();
        }
    }
    Connections {
        target: ShellState
        function onSwitcherScreenChanged() {
            if (ShellState.switcherScreen !== "")
                win.dock();
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
    // The keyboard's pick in the sidebar: shown while filtering or after Up/Down.
    property int cursor: 0
    property bool navigating: false
    readonly property bool showCursor: query !== "" || navigating
    onQueryChanged: cursor = 0

    function open(id) {
        ShellState.settingsPage = id;
        search.text = "";
        navigating = false;
        root.forceActiveFocus();
    }
    function moveCursor(to) {
        if (shown.length === 0)
            return;
        if (!showCursor)
            cursor = Math.max(0, shown.indexOf(current));
        navigating = true;
        cursor = Math.max(0, Math.min(shown.length - 1, to));
    }
    // Keeps the page the focus moved to in sight.
    function reveal(item) {
        let inPage = false;
        for (let p = item; p; p = p.parent)
            inPage = inPage || p === loader;
        if (!inPage)
            return;
        const top = item.mapToItem(scroller.contentItem, 0, 0).y;
        const bottom = top + item.height;
        if (top < scroller.contentY + Theme.spaceL)
            scroller.contentY = Math.max(0, top - Theme.spaceL);
        else if (bottom > scroller.contentY + scroller.height - Theme.spaceL)
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height, bottom - scroller.height + Theme.spaceL);
    }
    // The sidebar's sliding fill follows the chosen row; it is placed by hand because
    // the rows live inside groups inside a column.
    property Item markTarget: null
    function placeMark() {
        const t = markTarget;
        if (!t || !navScroll)
            return;
        const p = t.mapToItem(navScroll.contentItem, 0, 0);
        navMark.x = p.x;
        navMark.y = p.y;
        navMark.width = t.width;
        navMark.height = t.height;
        if (!navMark.settled)
            Qt.callLater(() => navMark.settled = true);
    }
    onMarkTargetChanged: Qt.callLater(placeMark)
    onNarrowChanged: Qt.callLater(placeMark)
    onDenseChanged: Qt.callLater(placeMark)
    function revealNav(item) {
        const top = item.mapToItem(navScroll.contentItem, 0, 0).y;
        if (top < navScroll.contentY)
            navScroll.contentY = Math.max(0, top - Theme.spaceS);
        else if (top + item.height > navScroll.contentY + navScroll.height)
            navScroll.contentY = Math.min(navScroll.contentHeight - navScroll.height, top + item.height - navScroll.height + Theme.spaceS);
    }
    // The item with the keyboard, as `var` so its members aren't type-checked (a text field has a cursor).
    readonly property var focused: root.Window.activeFocusItem
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const f = win.focused;
            if (f && f !== root)
                win.reveal(f);
        }
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true

        // What reaches here wasn't taken by the control that has the focus.
        Keys.onPressed: ev => {
            const f = win.focused;
            const inControl = f !== null && f !== root;
            const typing = inControl && f.cursorPosition !== undefined;
            const key = ev.key;
            if (key === Qt.Key_Escape) {
                if (search.text !== "")
                    search.text = "";
                else if (inControl)
                    root.forceActiveFocus();
                else if (win.navigating)
                    win.navigating = false;
                else
                    ShellState.settingsOpen = false;
                ev.accepted = true;
            } else if (!inControl && (key === Qt.Key_Down || key === Qt.Key_Up || key === Qt.Key_Home || key === Qt.Key_End)) {
                win.moveCursor(key === Qt.Key_Down ? win.cursor + 1 : key === Qt.Key_Up ? win.cursor - 1 : key === Qt.Key_Home ? 0 : win.shown.length - 1);
                ev.accepted = true;
            } else if (!inControl && win.navigating && (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Right)) {
                win.open(win.shown[Math.min(win.cursor, win.shown.length - 1)].id);
                ev.accepted = true;
            } else if (inControl && !typing && (key === Qt.Key_Down || key === Qt.Key_Right || key === Qt.Key_Up || key === Qt.Key_Left)) {
                // The arrows walk the controls of a page, too: lists and grids.
                const next = f.nextItemInFocusChain(key === Qt.Key_Down || key === Qt.Key_Right);
                if (next)
                    next.forceActiveFocus();
                ev.accepted = true;
            } else if (!win.narrow && ev.text.length === 1 && ev.text > " " && ev.text !== "\u007f" && !(ev.modifiers & Qt.ControlModifier)) {
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
            width: win.narrow ? 62 : 300

            InputField {
                id: search
                visible: !win.narrow
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
                anchors.top: win.narrow ? parent.top : search.bottom
                anchors.topMargin: win.narrow ? 0 : Theme.spaceM
                anchors.bottom: parent.bottom
                width: parent.width
                contentHeight: nav.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // The chosen page's fill, sliding between rows (and groups) when it changes.
                Rectangle {
                    id: navMark
                    property bool settled: false
                    visible: win.markTarget !== null
                    z: 1
                    radius: Theme.radiusM
                    color: Theme.alpha(Theme.fg, 0.12)
                    Behavior on x { enabled: navMark.settled; NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter } }
                    Behavior on y { enabled: navMark.settled; NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter } }
                    Behavior on width { enabled: navMark.settled; NumberAnimation { duration: Theme.msNormal } }
                    Behavior on height { enabled: navMark.settled; NumberAnimation { duration: Theme.msNormal } }
                }

                Column {
                    id: nav
                    width: parent.width
                    spacing: Theme.spaceS
                    onHeightChanged: win.placeMark()

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
                                        id: navItem
                                        required property var modelData
                                        page: modelData
                                        iconOnly: win.narrow
                                        dense: win.dense
                                        selected: modelData.id === win.current.id
                                        cursor: win.showCursor && win.shown[win.cursor]?.id === modelData.id
                                        onCursorChanged: if (cursor) win.revealNav(navItem)
                                        onSelectedChanged: if (selected) win.markTarget = navItem
                                        Component.onCompleted: if (selected) win.markTarget = navItem
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
            anchors.leftMargin: win.narrow ? Theme.spaceL : Theme.spaceXl
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
