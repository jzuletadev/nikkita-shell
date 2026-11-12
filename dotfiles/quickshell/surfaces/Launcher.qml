// ~/nikkita-shell/dotfiles/quickshell/surfaces/Launcher.qml

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
    WlrLayershell.namespace: "nikkita-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // From Sizes.qml.
    readonly property real boxWidth: m.searchWidth
    readonly property real fieldTop: m.searchTop
    readonly property int fieldHeight: 52

    // ---- the animation, in three numbers ----
    property real veil: 0           // the screen behind dimming a little
    property real pop: 0            // the magnifier's circle appearing
    property real stretch: 0        // the circle becoming the field

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "veil"; to: 1; duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth }
        NumberAnimation { target: root; property: "pop"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        SequentialAnimation {
            PauseAnimation { duration: 140 }
            NumberAnimation { target: root; property: "stretch"; to: 1; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "veil"; to: 0; duration: 260; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "stretch"; to: 0; duration: 170; easing.type: Easing.InCubic }
        SequentialAnimation {
            PauseAnimation { duration: 90 }
            NumberAnimation { target: root; property: "pop"; to: 0; duration: 150; easing.type: Easing.InBack }
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
    // A name match always beats a description match (Fuzzy.js); among similar
    // matches, what you use most comes first (Frecency). A sum shows its result
    // first (Calc.js); ":" searches emoji instead. Both copy on Enter.
    property int selected: 0
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
    onEmojiModeChanged: if (emojiMode) Emoji.load()
    readonly property var results: {
        const q = searchField.text.trim();
        if (!q)
            return [];
        if (emojiMode) {
            const e = q.slice(1).trim();
            return Emoji.list.map(x => [e ? Fuzzy.score(e, x[1]) : 0, x])
                .filter(x => x[0] !== null)
                .map(x => [x[0] + Frecency.boost("emoji:" + x[1][0]), x[1]])
                .sort((x, y) => y[0] - x[0])
                .slice(0, 7)
                .map(x => ({ kind: "emoji", id: "emoji:" + x[1][0], name: x[1][1].charAt(0).toUpperCase() + x[1][1].slice(1),
                             subtitle: "Enter copies it", value: x[1][0] }));
        }
        const sum = Calc.evaluate(q);
        const found = items.map(it => [Fuzzy.fields(q, [it.name, it.search]), it])
            .filter(x => x[0] !== null)
            .map(x => [x[0] + Frecency.boost(x[1].id), x[1]])
            .sort((x, y) => (y[0] - x[0]) || x[1].name.localeCompare(y[1].name))
            .slice(0, sum === null ? 7 : 6)
            .map(x => x[1]);
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
        selected = 0;
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
        if (it.kind !== "calc")
            Frecency.used(it.id);
        if (it.kind === "calc" || it.kind === "emoji") {
            ShellState.closeLauncher();
            Commands.run(["wl-copy", "--", it.value], "Copying " + (it.kind === "calc" ? "the result" : "the emoji"));
            return;
        }
        if (it.kind === "action")
            afterClose = it.action.run;
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
                        root.selected = Math.min(root.results.length - 1, root.selected + 1);
                        ev.accepted = true;
                    } else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) {
                        root.selected = Math.max(0, root.selected - 1);
                        ev.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: list.implicitHeight + 12
            radius: Theme.radiusL
            color: Theme.panel
            visible: searchField.text !== ""
            opacity: Math.min(1, root.stretch)
            clip: true

            Behavior on height { NumberAnimation { duration: Theme.msFast; easing.type: Easing.OutCubic } }

            // Clicks on the list are the list's, not the "outside" that closes.
            MouseArea { anchors.fill: parent }

            Column {
                id: list
                x: 6
                y: 6
                width: parent.width - 12
                spacing: Theme.spaceXxs

                Repeater {
                    model: root.results
                    Rectangle {
                        id: res
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 48
                        radius: Theme.radiusM
                        color: root.selected === index ? Theme.accentSoft : resultArea.containsMouse ? Theme.card : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.msFast } }

                        property real shift: root.cascade ? 1 : 0
                        opacity: 1 - shift
                        transform: Translate { y: 10 * res.shift }
                        Component.onCompleted: if (root.cascade) enter.start()
                        SequentialAnimation {
                            id: enter
                            PauseAnimation { duration: res.index * 35 }
                            NumberAnimation { target: res; property: "shift"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                        }

                        AppIcon {
                            visible: res.modelData.kind === "app"
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            name: res.modelData.appIcon ?? ""
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
                            text: ({ settings: "Settings", action: "Action", calc: "Calculator", emoji: "Emoji" })[res.modelData.kind] ?? ""
                            color: Theme.dim
                            font.pixelSize: Theme.textCaption
                        }
                        MouseArea {
                            id: resultArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launch(res.modelData)
                        }
                    }
                }
                StyledText {
                    visible: root.results.length === 0
                    width: list.width
                    height: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: root.emojiMode && Emoji.loading ? "Loading emoji" : "Nothing matches"
                    color: Theme.dim
                }
            }
        }
    }
}
