// ~/nikkita-shell/dotfiles/quickshell/settings/ShortcutsPage.qml
// Every keyboard shortcut, by section, with a filter. Click a shortcut's keys and
// press the new ones (Esc cancels, Backspace turns it off). Below, your own: a
// command for a key. hyprland.lua defines the shortcuts and publishes them;
// services/HyprSettings.qml keeps what you change and applies it.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services
import "../common/Fuzzy.js" as Fuzzy
import "../common/Combo.js" as Combo

Column {
    id: page
    spacing: Theme.spaceXl

    Component.onCompleted: {
        HyprSettings.refresh();
        filter.input.forceActiveFocus();
    }

    // ---- the rows: Hyprland's shortcuts, then yours ----
    readonly property string own: "Your own"
    readonly property var all: HyprSettings.shortcuts.map(s => ({ id: s.id, section: s.section, description: s.description, command: "",
            standard: s.default, keys: HyprSettings.keysOf(s), fixed: s.fixed, custom: false }))
        .concat(Prefs.customShortcuts.map((c, i) => ({ id: "custom:" + i, section: page.own, description: c.description || c.command,
            command: c.description ? c.command : "", standard: "", keys: c.keys, fixed: false, custom: true })))
    readonly property string query: filter.text.trim()
    readonly property var shown: !query ? all
        : all.filter(r => Fuzzy.fields(query, [r.description, Combo.label(r.keys) + " " + r.section + " " + r.command]) !== null)
    // In hyprland.lua's order, yours last.
    readonly property var sections: {
        const out = [];
        for (const r of shown) {
            if (r.custom)
                continue;
            let s = out.find(x => x.title === r.section);
            if (!s)
                out.push(s = { title: r.section, rows: [] });
            s.rows.push(r);
        }
        return out;
    }
    readonly property var customs: shown.filter(r => r.custom)
    readonly property bool anyChanged: Object.keys(Prefs.shortcutKeys).length > 0

    // ---- naming a pressed key: the first layout's table (scripts/keymap.py) ----
    property var keymap: null
    readonly property string layout: String(HyprSettings.value("kb_layout") ?? "").split(",")[0].trim()
    readonly property string variant: String(HyprSettings.value("kb_variant") ?? "").split(",")[0].trim()
    readonly property string layoutOptions: String(HyprSettings.value("kb_options") ?? "")
    onLayoutChanged: if (layout !== "") {
        keymapProc.command = ["python3", Paths.script("keymap.py"), layout, variant, layoutOptions];
        keymapProc.running = true;
    }
    Process {
        id: keymapProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.keymap = JSON.parse(text);
                } catch (e) {
                    // Combo.capture falls back to Qt's name for the key.
                    page.keymap = null;
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0)
                Commands.report("Reading the keyboard's keys", Commands.lastLine(stderr.text) || `keymap.py ended with code ${code}.`);
        }
    }

    // ---- changing a shortcut's keys ----
    property string capturing: ""        // the row waiting for keys
    property string message: ""          // why the last press wasn't taken
    property var clash: null             // { id, keys, other }: those keys are someone's

    function start(id) {
        capturing = id;
        message = "";
        clash = null;
        catcher.forceActiveFocus();
    }
    function stop() {
        capturing = "";
        message = "";
        clash = null;
    }
    // Left waiting (you scrolled away, or went for a coffee), it gives up: Hyprland's
    // shortcuts are off meanwhile.
    Timer {
        id: patience
        interval: 15000
        running: page.capturing !== ""
        onTriggered: page.stop()
    }
    function assign(id, keys) {
        if (id.startsWith("custom:")) {
            const list = Prefs.customShortcuts.slice();
            const i = parseInt(id.slice(7));
            list[i] = Object.assign({}, list[i], { keys: keys });
            HyprSettings.setCustom(list);
        } else {
            HyprSettings.setKeys(id, keys);
        }
    }
    function take(keys) {
        const other = keys === "" ? undefined : all.find(r => r.id !== capturing && Combo.same(r.keys, keys));
        if (other && other.fixed) {
            message = Combo.label(keys) + " belongs to “" + other.description + "”, which can't be changed.";
            clash = null;
        } else if (other) {
            message = "";
            clash = { id: capturing, keys: keys, other: other };
        } else {
            assign(capturing, keys);
            stop();
        }
    }
    function replace() {
        const c = clash;
        assign(c.other.id, "");
        assign(c.id, c.keys);
        stop();
    }

    // While it waits for keys, Hyprland runs none of its shortcuts (ShellState
    // switches it to an empty set): SUPER + Q is then a press to read, not "close
    // this window".
    Binding {
        target: ShellState
        property: "capturingKeys"
        value: page.capturing !== ""
    }
    Component.onDestruction: ShellState.capturingKeys = false
    Item {
        id: catcher
        Keys.onPressed: ev => {
            if (page.capturing === "")
                return;
            ev.accepted = true;
            patience.restart();
            const held = ev.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
            if (held === 0 && ev.key === Qt.Key_Escape) {
                page.stop();
            } else if (held === 0 && (ev.key === Qt.Key_Backspace || ev.key === Qt.Key_Delete)) {
                page.assign(page.capturing, "");
                page.stop();
            } else {
                const r = Combo.capture(ev.modifiers, ev.key, ev.nativeScanCode, page.keymap);
                if (r === null)
                    return;
                if (r.error !== undefined) {
                    page.message = r.error;
                    page.clash = null;
                } else {
                    page.take(r.keys);
                }
            }
        }
    }
    Connections {
        target: filter.input
        function onActiveFocusChanged() {
            if (filter.input.activeFocus)
                page.stop();
        }
    }

    // ---- one shortcut ----
    component ShortcutRow: Column {
        id: row
        required property var modelData
        readonly property bool waiting: page.capturing === modelData.id
        readonly property bool changed: !modelData.custom && modelData.keys !== modelData.standard
        width: parent ? parent.width : 0

        Item {
            width: parent.width
            height: 46

            Rectangle {
                visible: row.Positioner.index > 0
                x: 16
                width: parent.width - 32
                height: 1
                color: Theme.divider
            }
            Column {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - controls.width - Theme.spaceXl
                StyledText {
                    width: parent.width
                    text: row.modelData.description
                    color: row.modelData.keys === "" && !row.waiting ? Theme.muted : Theme.fg
                }
                StyledText {
                    visible: text !== ""
                    width: parent.width
                    text: row.modelData.command
                    color: Theme.dim
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.textCaption
                }
            }
            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS

                PillButton {
                    visible: row.changed
                    icon: "edit-undo-symbolic"
                    tip: "Back to " + (row.modelData.standard === "" ? "off" : Combo.label(row.modelData.standard))
                    onClicked: {
                        if (row.waiting)
                            page.stop();
                        HyprSettings.setKeys(row.modelData.id, undefined);
                    }
                }
                PillButton {
                    visible: row.modelData.custom
                    icon: "user-trash-symbolic"
                    tip: "Remove this shortcut"
                    onClicked: {
                        page.stop();
                        HyprSettings.setCustom(Prefs.customShortcuts.filter((c, i) => "custom:" + i !== row.modelData.id));
                    }
                }
                PillButton {
                    text: row.waiting ? (page.clash !== null ? Combo.label(page.clash.keys) : "Press the keys…")
                        : row.modelData.keys === "" ? (row.modelData.custom ? "Set the keys" : "Off")
                        : Combo.label(row.modelData.keys)
                    active: row.waiting
                    interactive: !row.modelData.fixed
                    tip: row.modelData.fixed ? "Built in: it can't be changed here"
                        : row.waiting ? "Esc cancels\nBackspace turns it off"
                        : "Click, then press the new keys"
                    onClicked: row.waiting ? page.stop() : page.start(row.modelData.id)
                }
            }
        }

        // Why a press wasn't taken, or whose those keys are.
        Item {
            visible: row.waiting && (page.message !== "" || page.clash !== null)
            width: parent.width
            height: 44

            StyledText {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - answer.width - Theme.spaceXl
                text: page.clash !== null ? Combo.label(page.clash.keys) + " is “" + page.clash.other.description + "”. Take it from there?" : page.message
                color: Theme.warn
                font.pixelSize: Theme.textSmall
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                maximumLineCount: 2
            }
            Row {
                id: answer
                visible: page.clash !== null
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS
                PillButton {
                    text: "Cancel"
                    onClicked: page.stop()
                }
                PillButton {
                    text: "Take it"
                    active: true
                    onClicked: page.replace()
                }
            }
        }
    }

    // ================================================================ the page
    HyprProblems {}

    InputField {
        id: filter
        width: parent.width
        height: 44
        placeholder: "Filter shortcuts"
        icon: "input-keyboard-symbolic"
        color: Theme.alpha(Theme.fg, 0.06)
    }

    StyledText {
        visible: page.shown.length === 0 && page.query !== ""
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "No shortcut matches “" + page.query + "”"
        color: Theme.dim
    }
    StyledText {
        visible: HyprSettings.shortcuts.length === 0 && page.query === ""
        width: parent.width
        leftPadding: Theme.spaceS
        text: "Hyprland hasn't listed its shortcuts yet."
        color: Theme.dim
    }

    Repeater {
        model: page.sections

        Section {
            id: group
            required property var modelData
            title: modelData.title
            Repeater {
                model: group.modelData.rows
                ShortcutRow {}
            }
        }
    }

    Section {
        title: page.own
        visible: page.query === "" || page.customs.length > 0
        note: "A command to run when you press its keys: an app's name (kitty, brave) or a whole command line."

        Repeater {
            model: page.customs
            ShortcutRow {}
        }

        Item {
            visible: page.query === ""
            width: parent.width
            height: 56

            Rectangle {
                visible: page.customs.length > 0
                x: 16
                width: parent.width - 32
                height: 1
                color: Theme.divider
            }
            Row {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - Theme.spaceL
                spacing: Theme.spaceS

                InputField {
                    id: newName
                    width: 200
                    height: 36
                    icon: "list-add-symbolic"
                    placeholder: "Name"
                    onSubmitted: newCommand.input.forceActiveFocus()
                }
                InputField {
                    id: newCommand
                    width: parent.width - newName.width - add.width - 2 * parent.spacing
                    height: 36
                    icon: "utilities-terminal-symbolic"
                    placeholder: "Command"
                    onSubmitted: add.go()
                }
                PillButton {
                    id: add
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Add"
                    interactive: newCommand.text.trim() !== ""
                    tip: "Add it, then press its keys"
                    function go() {
                        if (newCommand.text.trim() === "")
                            return;
                        const list = Prefs.customShortcuts.concat([{ keys: "", command: newCommand.text.trim(), description: newName.text.trim() }]);
                        HyprSettings.setCustom(list);
                        newName.text = "";
                        newCommand.text = "";
                        page.start("custom:" + (list.length - 1));
                    }
                    onClicked: go()
                }
            }
        }
    }

    Section {
        visible: page.anyChanged && page.query === ""
        SettingRow {
            id: reset
            property bool sure: false
            icon: "edit-undo-symbolic"
            title: "Back to the default keys"
            subtitle: "Every shortcut above gets its original keys again. Your own stay."
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: reset.sure ? "Yes, all of them" : "Reset"
                danger: true
                onClicked: {
                    if (!reset.sure) {
                        reset.sure = true;
                        forget.restart();
                        return;
                    }
                    reset.sure = false;
                    page.stop();
                    HyprSettings.resetKeys();
                }
            }
            Timer {
                id: forget
                interval: 4000
                onTriggered: reset.sure = false
            }
        }
    }
}
