// ~/nikita-shell/dotfiles/quickshell/surfaces/Launcher.qml

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services
import qs.settings
import "../common/Fuzzy.js" as Fuzzy
import "../common/Calc.js" as Calc

PanelWindow {
    id: root

    required property Sizes m
    property string screenName: ""
    readonly property bool isOpen: ShellState.launcherScreen === screenName

    // Mapped from the moment it opens until its closing animation ends.
    property bool shown: false
    visible: shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nikita-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // From Sizes.qml.
    readonly property real boxWidth: m.searchWidth
    readonly property real fieldTop: m.searchTop
    readonly property int fieldHeight: 52

    // ---- the animation, in three numbers ----
    property real veil: 0           // the screen behind dimming a little
    property real pop: 0            // the magnifier's circle appearing
    property real stretch: 0        // the circle becoming the field

    // An app taking off: a few hexagons leave its row, like the rocket's exhaust.
    property real trail: 0
    property bool launching: false
    property point trailFrom: Qt.point(0, 0)
    readonly property var exhaust: [
        { at: 0, size: 12, dx: 26, dy: 20 },
        { at: 0.1, size: 9, dx: 48, dy: 30 },
        { at: 0.18, size: 7, dx: 36, dy: 50 },
        { at: 0.26, size: 6, dx: 70, dy: 52 },
        { at: 0.34, size: 4, dx: 58, dy: 74 }
    ]

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "veil"; to: 1; duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth }
        NumberAnimation { target: root; property: "pop"; to: 1; duration: Theme.ms(300); easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        SequentialAnimation {
            PauseAnimation { duration: Theme.ms(140) }
            NumberAnimation { target: root; property: "stretch"; to: 1; duration: Theme.ms(480); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
    }
    ParallelAnimation {
        id: closeAnim
        // Only an app makes the closing wait for it.
        NumberAnimation { target: root; property: "trail"; from: 0; to: 1; duration: root.launching ? Theme.ms(420) : 0; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "veil"; to: 0; duration: Theme.ms(260); easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "stretch"; to: 0; duration: Theme.ms(170); easing.type: Easing.InCubic }
        SequentialAnimation {
            PauseAnimation { duration: Theme.ms(90) }
            NumberAnimation { target: root; property: "pop"; to: 0; duration: Theme.ms(150); easing.type: Easing.InBack }
        }
        onFinished: {
            if (!root.isOpen) {
                root.shown = false;
                if (root.afterClose !== null) {
                    const run = root.afterClose;
                    root.afterClose = null;
                    run();
                }
            }
        }
    }

    function open() {
        closeAnim.stop();
        afterClose = null;
        launching = false;
        lastPointer = null;
        searchField.text = "";
        selected = 0;
        shown = true;
        searchField.input.forceActiveFocus();
        openAnim.start();
    }
    function close() {
        openAnim.stop();
        closeAnim.start();
    }
    onIsOpenChanged: isOpen ? open() : close()
    Component.onCompleted: if (isOpen) open()

    Connections {
        target: ShellState
        function onQuery(text) {
            if (root.isOpen) {
                searchField.text = text;
                searchField.input.cursorPosition = text.length;
            }
        }
    }

    // ---- the search ----
    // Apps, Settings pages and actions (services/Actions.qml), as one kind of row.
    // A name match always beats a description match, and weak matches stay out
    // (Fuzzy.rank); among similar matches, what you use most comes first (Frecency).
    // With nothing typed it lists what you use most, unselected, so Enter opens
    // nothing by accident. A sum shows its result first (Calc.js); ":" searches emoji
    // instead. Both copy on Enter.
    property int selected: 0
    readonly property bool browsing: searchField.text.trim() === ""
    function step(by) {
        const n = results.length;
        if (n > 0)
            selected = selected < 0 ? (by > 0 ? 0 : n - 1) : (selected + by + n) % n;
    }
    onSelectedChanged: {
        if (selected < 0)
            return;
        list.positionViewAtIndex(selected, ListView.Contain);
        // Clear of the fade at the bottom, while there is more below.
        const row = list.itemAtIndex(selected);
        if (row && row.y + row.height > list.contentY + list.height - 32)
            list.contentY = Math.min(row.y + row.height + 32 - list.height, list.originY + list.contentHeight - list.height);
    }
    // One highlight: the pointer moves it, as the arrows do. Only real motion counts,
    // or a list appearing under a pointer at rest would pick a row.
    property var lastPointer: null
    function pointed(index, p) {
        if (lastPointer !== null && (p.x !== lastPointer.x || p.y !== lastPointer.y))
            selected = index;
        lastPointer = p;
    }
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    readonly property var items: {
        const v = apps.map(a => ({ kind: "app", id: "app:" + a.id, name: a.name, subtitle: a.comment || a.genericName || "",
                                   search: [a.genericName, a.comment, a.keywords].join(" "), appIcon: a.icon, entry: a }));
        for (const p of SettingsPages.list)
            v.push({ kind: "settings", id: "settings:" + p.id, name: p.title, subtitle: p.subtitle,
                     search: "settings " + p.subtitle + " " + p.keys, icon: p.icon, page: p.id });
        for (const a of Actions.list)
            v.push({ kind: "action", id: "action:" + a.id, name: a.title, subtitle: a.subtitle,
                     search: a.subtitle + " " + a.keys, icon: a.icon ?? "", glyph: a.glyph ?? 0, action: a });
        return v;
    }
    readonly property bool emojiMode: searchField.text.trim().startsWith(":")
    // ";" searches the clipboard history (the panels never take the keys, so this is its keyboard).
    readonly property bool clipMode: searchField.text.trim().startsWith(";")
    onEmojiModeChanged: if (emojiMode) Emoji.load()
    readonly property var results: {
        if (!root.shown)
            return [];
        const q = searchField.text.trim();
        if (!q)
            return items.map(it => [Frecency.boost(it.id), it])
                .filter(x => x[0] > 0)
                .sort((x, y) => y[0] - x[0])
                .slice(0, 6)
                .map(x => x[1]);
        if (emojiMode) {
            const e = q.slice(1).trim();
            return Emoji.list.map(x => [e ? Fuzzy.score(e, x[1]) : 0, x])
                .filter(x => x[0] !== null)
                .map(x => [x[0] + Frecency.boost("emoji:" + x[1][0]), x[1]])
                .sort((x, y) => y[0] - x[0])
                .slice(0, 40)
                .map(x => ({ kind: "emoji", id: "emoji:" + x[1][0], name: x[1][1].charAt(0).toUpperCase() + x[1][1].slice(1),
                             subtitle: "Enter copies it", value: x[1][0] }));
        }
        if (clipMode) {
            const c = q.slice(1).trim();
            // Nothing typed after the ";": the history as it is, the pinned first.
            return ClipHistory.shown.map((t, i) => [c ? Fuzzy.score(c, t) : -i, t])
                .filter(x => x[0] !== null)
                .sort((x, y) => y[0] - x[0])
                .slice(0, 40)
                .map(x => ({ kind: "clip", id: "clip:" + x[1], name: x[1].replace(/\s+/g, " ").trim().slice(0, 90),
                             subtitle: (ClipHistory.pinned.indexOf(x[1]) >= 0 ? "Pinned · " : "") + "Enter copies it",
                             icon: ClipHistory.pinned.indexOf(x[1]) >= 0 ? "view-pin-symbolic" : "edit-paste-symbolic", value: x[1] }));
        }
        const sum = Calc.evaluate(q);
        const found = Fuzzy.rank(q, items, id => Frecency.boost(id)).slice(0, 40);
        if (sum === null)
            return found;
        const value = Calc.format(sum);
        return [{ kind: "calc", id: "calc", name: "= " + value, subtitle: q.replace(/^=\s*/, "") + " · Enter copies the result",
                  icon: "accessories-calculator-symbolic", value: value }].concat(found);
    }
    // The first results after an empty field cascade in; later ones (typing) just
    // appear, or every key would replay the cascade.
    property bool cascade: false
    property int lastCount: 0
    onResultsChanged: {
        selected = browsing ? -1 : 0;
        list.positionViewAtBeginning();
        if (lastCount === 0 && results.length > 0) {
            cascade = true;
            cascadeEnd.restart();
        }
        lastCount = results.length;
    }
    Timer {
        id: cascadeEnd
        interval: 400
        onTriggered: root.cascade = false
    }

    // Apps and pages open at once; an action waits until the launcher is gone, so a
    // recording or a screenshot doesn't catch it.
    property var afterClose: null
    function launch(it) {
        if (!it)
            return;
        if (it.kind === "action" && it.action.typed) {
            searchField.text = it.action.typed;
            searchField.input.cursorPosition = searchField.text.length;
            return;
        }
        if (it.kind !== "calc" && it.kind !== "clip")
            Frecency.used(it.id);
        if (it.kind === "calc" || it.kind === "emoji" || it.kind === "clip") {
            ShellState.closeLauncher();
            Commands.run(["wl-copy", "--", it.value], "Copying " + ({ calc: "the result", emoji: "the emoji", clip: "it" })[it.kind]);
            return;
        }
        if (it.kind === "action")
            afterClose = it.action.run;
        if (it.kind === "app") {
            const row = list.itemAtIndex(results.indexOf(it));
            trailFrom = row ? row.mapToItem(null, 25, 24) : Qt.point(width / 2, searchBox.y + fieldHeight);
            launching = true;
        }
        ShellState.closeLauncher();
        if (it.kind === "settings")
            ShellState.openSettings(it.page);
        else if (it.kind === "app" && it.entry.runInTerminal)
            Commands.launch(["kitty", "-e"].concat(it.entry.command), "Opening " + it.name);
        else if (it.kind === "app")
            Commands.launchEntry(it.entry, "Opening " + it.name);
    }

    // ---- what is behind: live, a little dimmer ----
    // Under the layer rule's ignore_alpha (hyprland.lua), so Hyprland leaves it
    // sharp and blurs only behind the field and the results, as behind a panel.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, (Theme.dark ? 0.30 : 0.18) * root.veil)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeLauncher()
    }

    Repeater {
        model: root.launching ? root.exhaust : []

        HexShape {
            required property var modelData
            readonly property real t: Math.max(0, Math.min(1, (root.trail - modelData.at) / (1 - modelData.at)))
            z: 1
            width: modelData.size
            height: Math.round(width / Theme.hexRatio)
            x: root.trailFrom.x - modelData.dx * t - width / 2
            y: root.trailFrom.y + modelData.dy * t - height / 2
            scale: 1 - 0.45 * t
            opacity: t > 0 ? 1 - t : 0
            fill: Theme.fg
        }
    }

    // Anchored at the top so the field doesn't move as results grow.
    Column {
        id: searchBox
        width: root.boxWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.fieldTop + (1 - Math.min(1, root.stretch)) * 26
        spacing: Theme.spaceS

        Item {
            width: parent.width
            height: root.fieldHeight

            // A click on the field's padding is a click on the field, not outside.
            MouseArea {
                anchors.fill: searchField
                onClicked: searchField.input.forceActiveFocus()
            }
            InputField {
                id: searchField
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.fieldHeight + (parent.width - root.fieldHeight) * root.stretch
                height: root.fieldHeight
                scale: root.pop
                opacity: Math.min(1, root.pop * 1.5)
                placeholder: "Search apps, settings and actions"
                color: Theme.panel
                iconX: 14 + (1 - Math.min(1, root.stretch)) * ((root.fieldHeight - 15) / 2 - 14)
                contentOpacity: Math.max(0, Math.min(1, (root.stretch - 0.55) / 0.45))
                onSubmitted: root.launch(root.results[root.selected])
                onSpecialKey: ev => {
                    if (ev.key === Qt.Key_Escape) {
                        ShellState.closeLauncher();
                        ev.accepted = true;
                    } else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab) {
                        root.step(1);
                        ev.accepted = true;
                    } else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) {
                        root.step(-1);
                        ev.accepted = true;
                    } else if (ev.key === Qt.Key_PageDown || ev.key === Qt.Key_PageUp) {
                        // A page at a time, stopping at the ends instead of wrapping.
                        const n = root.results.length;
                        if (n > 0)
                            root.selected = Math.max(0, Math.min(n - 1, Math.max(0, root.selected) + (ev.key === Qt.Key_PageDown ? 6 : -6)));
                        ev.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: list.height + 12
            radius: Theme.radiusL
            color: Theme.panel
            border.width: 1
            border.color: Theme.panelRim
            visible: searchField.text !== "" || root.results.length > 0
            opacity: Math.min(1, root.stretch)
            clip: true

            Behavior on height { NumberAnimation { duration: Theme.msFast; easing.type: Easing.OutCubic } }

            // Clicks on the list are the list's, not the "outside" that closes.
            MouseArea { anchors.fill: parent }

            // Seven rows show; the rest scroll, by wheel or by keyboard.
            ListView {
                id: list
                readonly property int rows: Math.min(count, 7)
                readonly property int headerHeight: root.browsing && count > 0 ? 24 : 0
                x: 6
                y: 6
                width: parent.width - 12
                height: count === 0 ? 40 : headerHeight + rows * 48 + (rows - 1) * spacing
                spacing: Theme.spaceXxs
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Keeps the rows that stay from one key to the next.
                model: ScriptModel {
                    values: root.results
                }
                header: Item {
                    width: list.width
                    height: list.headerHeight
                    StyledText {
                        x: Theme.spaceM
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.height > 0
                        text: "Frequent"
                        color: Theme.dim
                        font.pixelSize: Theme.textCaption
                        font.weight: Font.Medium
                    }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: Theme.msFast; easing.type: Easing.OutCubic }
                }

                delegate: Rectangle {
                    id: res
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 48
                    radius: Theme.radiusM
                    color: root.selected === index ? Theme.accentSoft : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.msFast } }

                    property real shift: root.cascade ? 1 : 0
                    opacity: 1 - shift
                    transform: Translate { y: 10 * res.shift }
                    Component.onCompleted: if (root.cascade) enter.start()
                    SequentialAnimation {
                        id: enter
                        PauseAnimation { duration: res.index * 35 }
                        NumberAnimation { target: res; property: "shift"; to: 0; duration: Theme.ms(220); easing.type: Easing.OutCubic }
                    }

                    AppIcon {
                        visible: res.modelData.kind === "app"
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: res.modelData.appIcon ?? ""
                        initial: res.modelData.name
                        size: 30
                    }
                    // Pages and actions: their symbolic icon in a bubble, like Settings' sidebar.
                    Rectangle {
                        visible: res.modelData.kind !== "app"
                        x: 10
                        width: 30
                        height: 30
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.card
                        Icon {
                            visible: (res.modelData.glyph ?? 0) === 0 && res.modelData.kind !== "emoji"
                            anchors.centerIn: parent
                            name: res.modelData.icon ?? ""
                            size: 16
                            color: Theme.fg
                        }
                        Glyph {
                            visible: (res.modelData.glyph ?? 0) > 0
                            anchors.centerIn: parent
                            code: res.modelData.glyph ?? 0
                            size: 18
                            color: Theme.fg
                        }
                        StyledText {
                            visible: res.modelData.kind === "emoji"
                            anchors.centerIn: parent
                            text: res.modelData.value ?? ""
                            font.pixelSize: 20
                        }
                    }
                    Column {
                        x: 52
                        width: parent.width - x - (kindLabel.visible ? kindLabel.width + Theme.spaceM : 0) - Theme.spaceM
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText {
                            width: parent.width
                            text: res.modelData.name
                            font.weight: Font.DemiBold
                            color: root.selected === res.index ? Theme.accent : Theme.fg
                        }
                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: res.modelData.subtitle
                            color: Theme.muted
                            font.pixelSize: Theme.textSmall
                        }
                    }
                    StyledText {
                        id: kindLabel
                        visible: res.modelData.kind !== "app"
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceM
                        anchors.verticalCenter: parent.verticalCenter
                        text: ({ settings: "Settings", action: "Action", calc: "Calculator", emoji: "Emoji", clip: "Clipboard" })[res.modelData.kind] ?? ""
                        color: Theme.dim
                        font.pixelSize: Theme.textCaption
                    }
                    MouseArea {
                        id: resultArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launch(res.modelData)
                        onPositionChanged: ev => root.pointed(res.index, mapToItem(null, ev.x, ev.y))
                    }
                }
            }
            EdgeFade { view: list }
            ScrollHint { view: list }

            StyledText {
                visible: root.results.length === 0
                x: 6
                y: 6
                width: list.width
                height: 40
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.emojiMode && Emoji.loading ? "Loading emoji" : root.clipMode ? "Nothing in the clipboard history" : "Nothing matches"
                color: Theme.dim
            }
        }
    }
}
