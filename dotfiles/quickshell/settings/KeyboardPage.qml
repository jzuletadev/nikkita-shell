// ~/nikita-shell/dotfiles/quickshell/settings/KeyboardPage.qml
// The keyboard: its layouts (add, remove, pick), how keys repeat, and its backlight
// where there is one. Hyprland owns these: services/HyprSettings.qml applies them.
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
        KeyboardState.refresh();
        KeyboardLight.refresh();
        catalog.running = true;
    }
    // The layouts in use change with a reload: read them again after one.
    Connections {
        target: HyprSettings
        function onOptionsChanged() {
            KeyboardState.refresh();
        }
    }

    // ---- layouts: "us,es" with variants ",": kept side by side ----
    readonly property var layouts: {
        const l = String(HyprSettings.value("kb_layout") ?? "").split(",").map(x => x.trim()).filter(x => x !== "");
        const v = String(HyprSettings.value("kb_variant") ?? "").split(",").map(x => x.trim());
        return l.map((code, i) => ({ layout: code, variant: v[i] || "" }));
    }
    function save(list) {
        HyprSettings.setInput("kb_layout", list.map(x => x.layout).join(","));
        HyprSettings.setInput("kb_variant", list.map(x => x.variant).join(","));
    }
    // Here, not in the row that was clicked: adding empties the search, and the
    // row is gone before its own handler could finish.
    function add(l) {
        adder.text = "";
        save(layouts.concat([{ layout: l.layout, variant: l.variant }]));
    }
    function nameOf(l) {
        const k = known.find(x => x.layout === l.layout && x.variant === l.variant);
        return k ? k.name : l.layout.toUpperCase() + (l.variant ? " (" + l.variant + ")" : "");
    }

    // Every layout XKB has (scripts/xkb-layouts.py), for adding one.
    property var known: []
    Process {
        id: catalog
        command: ["python3", Paths.script("xkb-layouts.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.known = JSON.parse(text);
                } catch (e) {
                    console.warn("keyboard: can't read xkb-layouts.py:", e);
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0)
                Commands.report("Listing the keyboard layouts", Commands.lastLine(stderr.text) || `xkb-layouts.py ended with code ${code}.`);
        }
    }
    readonly property var found: {
        const q = adder.text.trim();
        if (!q)
            return [];
        // A language's own layout before its variants ("latin": Latin American, not
        // a variant of Russian in Latin letters); then the shorter name.
        return known.filter(k => !layouts.some(l => l.layout === k.layout && l.variant === k.variant))
            .map(k => [Fuzzy.fields(q, [k.name, k.layout + " " + k.variant]), k])
            .filter(x => x[0] !== null)
            .map(x => [x[0] + (x[1].variant === "" ? 30 : 0), x[1]])
            .sort((a, b) => (b[0] - a[0]) || (a[1].name.length - b[1].name.length) || a[1].name.localeCompare(b[1].name))
            .slice(0, 6)
            .map(x => x[1]);
    }
    readonly property string nextKeys: {
        const s = HyprSettings.shortcuts.find(x => x.id === "layout-next");
        return s ? Combo.label(HyprSettings.keysOf(s)) : "";
    }

    HyprProblems {}

    Section {
        title: "Layouts"
        SettingRow {
            visible: HyprSettings.changed("kb_layout") || HyprSettings.changed("kb_variant")
            icon: "edit-undo-symbolic"
            title: "Back to the default layouts"
            subtitle: "The ones in dotfiles/hypr/hyprland.lua."
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset"
                onClicked: HyprSettings.resetInputs(["kb_layout", "kb_variant"])
            }
        }
        note: page.layouts.length > 1 && page.nextKeys !== "" ? page.nextKeys + " goes to the next one. The first is the one shortcuts are read in." : ""

        Repeater {
            model: page.layouts

            SettingRow {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === KeyboardState.layoutIndex
                icon: "input-keyboard-symbolic"
                title: page.nameOf(modelData)
                subtitle: modelData.layout + (modelData.variant ? " · " + modelData.variant : "") + (current && page.layouts.length > 1 ? " · in use now" : "")
                PillButton {
                    visible: page.layouts.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.current ? "In use" : "Use"
                    active: row.current
                    onClicked: KeyboardState.setLayout(row.index)
                }
                PillButton {
                    visible: page.layouts.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "user-trash-symbolic"
                    tip: "Remove this layout"
                    onClicked: page.save(page.layouts.filter((l, i) => i !== row.index))
                }
            }
        }

        SettingRow {
            icon: "list-add-symbolic"
            title: "Add a layout"
            subtitle: page.known.length === 0 ? "Loading the list." : "By language or country: Spanish, Latin American, German, Dvorak…"
            InputField {
                id: adder
                width: 260
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                placeholder: "Search layouts"
                onSubmitted: if (page.found.length > 0) page.add(page.found[0])
            }
        }
        Repeater {
            model: page.found

            SettingRow {
                id: hit
                required property var modelData
                clickable: true
                divider: false
                title: modelData.name
                subtitle: modelData.layout + (modelData.variant ? " · " + modelData.variant : "")
                onClicked: page.add(modelData)
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Add"
                    color: hit.hovering ? Theme.fg : Theme.dim
                    font.pixelSize: Theme.textSmall
                }
            }
        }
        StyledText {
            visible: adder.text.trim() !== "" && page.found.length === 0 && page.known.length > 0
            x: 18
            height: 40
            verticalAlignment: Text.AlignVCenter
            text: "No layout matches"
            color: Theme.dim
        }
    }

    // ---- typing ----
    Section {
        title: "Typing"
        SettingRow {
            icon: "preferences-system-time-symbolic"
            title: "Repeat delay"
            subtitle: "How long a key is held before it starts repeating."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("repeat_delay")
                onClicked: HyprSettings.setInput("repeat_delay", undefined)
            }
            // 0-100 on the slider: 150 to 1000 ms.
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: Math.round(((HyprSettings.value("repeat_delay") ?? 600) - 150) / 8.5)
                onMoved: v => HyprSettings.setInput("repeat_delay", Math.round((150 + v * 8.5) / 10) * 10)
            }
            StyledText {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: (HyprSettings.value("repeat_delay") ?? "--") + " ms"
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
        SettingRow {
            title: "Repeat speed"
            subtitle: "How many times a second a held key repeats."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("repeat_rate")
                onClicked: HyprSettings.setInput("repeat_rate", undefined)
            }
            // 0-100 on the slider: 5 to 80 a second.
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: Math.round(((HyprSettings.value("repeat_rate") ?? 25) - 5) / 0.75)
                onMoved: v => HyprSettings.setInput("repeat_rate", Math.round(5 + v * 0.75))
            }
            StyledText {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: (HyprSettings.value("repeat_rate") ?? "--") + " / s"
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
        SettingRow {
            title: "Try it"
            subtitle: "Hold a key here."
            InputField {
                width: 260
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                icon: "input-keyboard-symbolic"
                placeholder: "Type here"
            }
        }
        SettingRow {
            title: "Num Lock on"
            subtitle: "From the moment you log in."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("numlock_by_default")
                onClicked: HyprSettings.setInput("numlock_by_default", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: HyprSettings.value("numlock_by_default") === true
                onToggled: HyprSettings.setInput("numlock_by_default", !(HyprSettings.value("numlock_by_default") === true))
            }
        }
    }

    // ---- backlight, where the keyboard has one ----
    Section {
        title: "Backlight"
        visible: KeyboardLight.available
        note: "The laptop's own key for it changes it too; this page reads it again when it opens."
        SettingRow {
            icon: "keyboard-brightness-symbolic"
            title: "Keyboard light"
            subtitle: KeyboardLight.level === 0 ? "Off" : KeyboardLight.max <= 1 ? "On" : "Level " + KeyboardLight.level + " of " + KeyboardLight.max
            // A few levels: one pill each. Many: a slider.
            Repeater {
                model: KeyboardLight.max <= 5 ? KeyboardLight.max + 1 : 0
                PillButton {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    text: index === 0 ? "Off" : KeyboardLight.max === 1 ? "On" : String(index)
                    active: KeyboardLight.level === index
                    onClicked: KeyboardLight.set(index)
                }
            }
            HorizontalSlider {
                visible: KeyboardLight.max > 5
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: KeyboardLight.max > 0 ? Math.round(100 * KeyboardLight.level / KeyboardLight.max) : 0
                onMoved: v => KeyboardLight.set(v * KeyboardLight.max / 100)
            }
        }
    }

    Section {
        SettingRow {
            icon: "preferences-desktop-keyboard-shortcuts-symbolic"
            title: "Keyboard shortcuts"
            subtitle: "See and change the keys for every action"
            clickable: true
            onClicked: ShellState.openSettings("shortcuts")
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "go-next-symbolic"
                size: 14
                color: Theme.dim
            }
        }
    }
}
