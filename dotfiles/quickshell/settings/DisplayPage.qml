// ~/nikita-shell/dotfiles/quickshell/settings/DisplayPage.qml
// Screen brightness, night light, and the monitors: where each one sits, its mode,
// scale and rotation (services/Monitors.qml applies them and asks before keeping).
import QtQuick
import qs.common
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    Component.onCompleted: {
        Brightness.refresh();
        Monitors.load();
    }

    Section {
        title: "Brightness"
        visible: Brightness.available
        SettingRow {
            icon: "display-brightness-symbolic"
            title: "Screen brightness"
            subtitle: "The brightness keys do the same."
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: Brightness.percent
                onMoved: v => Brightness.setPercent(v)
            }
            StyledText {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Brightness.percent + "%"
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
    }

    // ---- night light (services/NightLight.qml) ----
    Section {
        title: "Night light"
        note: "Warmer colors through hyprsunset. Quick actions has the same switch."
        SettingRow {
            icon: "night-light-symbolic"
            title: "Night light"
            subtitle: NightLight.enabled ? NightLight.status : "Warmer colors, easier on the eyes in the evening."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Prefs.nightLight
                onToggled: Prefs.set("nightLight", !Prefs.nightLight)
            }
        }
        SettingRow {
            icon: "preferences-system-time-symbolic"
            title: "Only at night"
            subtitle: Prefs.nightScheduled ? "From " + NightLight.clock(Prefs.nightFrom) + " to " + NightLight.clock(Prefs.nightTo) : "All the time while it's on."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Prefs.nightScheduled
                onToggled: Prefs.set("nightScheduled", !Prefs.nightScheduled)
            }
        }
        SettingRow {
            visible: Prefs.nightScheduled
            title: "Starts"
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: !Prefs.isDefault("nightFrom")
                defaultText: NightLight.clock(Prefs.defaults.nightFrom)
                onClicked: Prefs.reset("nightFrom")
            }
            TimeStepper {
                anchors.verticalCenter: parent.verticalCenter
                value: Prefs.nightFrom
                onPicked: v => Prefs.set("nightFrom", v)
            }
        }
        SettingRow {
            visible: Prefs.nightScheduled
            title: "Ends"
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: !Prefs.isDefault("nightTo")
                defaultText: NightLight.clock(Prefs.defaults.nightTo)
                onClicked: Prefs.reset("nightTo")
            }
            TimeStepper {
                anchors.verticalCenter: parent.verticalCenter
                value: Prefs.nightTo
                onPicked: v => Prefs.set("nightTo", v)
            }
        }
        SettingRow {
            title: "Warmth"
            subtitle: "Further right is warmer."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: !Prefs.isDefault("nightTemperature")
                defaultText: Prefs.defaults.nightTemperature + " K"
                onClicked: Prefs.reset("nightTemperature")
            }
            // 0-100 on the slider: 6000 K (barely warm) to 2500 K (candle).
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: Math.round((6000 - Prefs.nightTemperature) / 35)
                onMoved: v => Prefs.set("nightTemperature", Math.round((6000 - v * 35) / 100) * 100)
            }
            StyledText {
                width: 56
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Prefs.nightTemperature + " K"
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
    }

    // ---- monitors ----
    property int selected: 0
    readonly property var mon: Monitors.draft[Math.min(selected, Monitors.draft.length - 1)] ?? null

    // Hyprland only takes scales that leave whole pixels.
    function scales(m) {
        const v = [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.4, 2.5, 3].filter(s => {
            const w = m.width / s, h = m.height / s;
            return Math.abs(w - Math.round(w)) < 0.01 && Math.abs(h - Math.round(h)) < 0.01;
        }).map(s => Math.round(s * 1000) / 1000);
        if (v.indexOf(m.scale) < 0)
            v.push(m.scale);
        return v.sort((a, b) => a - b).map(s => ({ label: Math.round(s * 100) + " %", value: s }));
    }
    // Only what the monitor says it can show; the largest is its own (native) size.
    function resolutions(m) {
        const seen = {};
        for (const md of m.modes)
            seen[md.width + "x" + md.height] = [md.width, md.height];
        return Object.values(seen).sort((a, b) => b[0] * b[1] - a[0] * a[1])
            .map((r, i) => ({ label: r[0] + " × " + r[1], value: r, detail: i === 0 ? "Native: the sharpest" : "" }));
    }
    // The rates of this resolution, cut to two: the standard one (closest to 60 Hz)
    // and the highest; the one in use too, if it is neither.
    function allRates(m, w, h) {
        return m.modes.filter(md => md.width === w && md.height === h).map(md => md.refresh)
            .filter((r, i, all) => all.indexOf(r) === i).sort((a, b) => b - a);
    }
    function standardRate(all) {
        return all.slice().sort((a, b) => Math.abs(a - 60) - Math.abs(b - 60))[0];
    }
    function rates(m) {
        const all = allRates(m, m.width, m.height);
        if (all.length === 0)
            return [];
        const top = all[0], standard = standardRate(all);
        const out = [{ label: Math.round(top) + " Hz", value: top, detail: top === standard ? "Standard, and the highest this monitor has" : "The highest this monitor has: smoother" }];
        if (standard !== top)
            out.push({ label: Math.round(standard) + " Hz", value: standard, detail: "Standard" });
        if (all.indexOf(m.refresh) >= 0 && m.refresh !== top && m.refresh !== standard)
            out.push({ label: Math.round(m.refresh) + " Hz", value: m.refresh, detail: "In use now" });
        return out;
    }

    // A change of size pushes along the monitors to its right and below, so
    // they stay side by side.
    function resize(i, change) {
        const d = Monitors.clone(Monitors.draft);
        const me = d[i], before = Monitors.logical(me);
        change(me);
        const after = Monitors.logical(me);
        for (const [j, o] of d.entries()) {
            if (j === i)
                continue;
            if (o.x >= me.x + before.w - 1)
                o.x += after.w - before.w;
            if (o.y >= me.y + before.h - 1)
                o.y += after.h - before.h;
        }
        Monitors.draft = d;
    }

    // Dropped at (x, y), in layout pixels: the nearest place against another
    // monitor's edge, its sides aligned when close.
    function drop(i, x, y) {
        const d = Monitors.clone(Monitors.draft);
        const me = d[i], s = Monitors.logical(me);
        const others = d.filter((o, j) => j !== i && o.enabled);
        const align = (v, start, len, mine) => {
            for (const p of [start, start + len - mine, start + (len - mine) / 2])
                if (Math.abs(p - v) < Math.max(40, len / 10))
                    return p;
            return Math.max(start - mine + 1, Math.min(start + len - 1, v));
        };
        const overlaps = (cx, cy) => others.some(o => {
            const os = Monitors.logical(o);
            return cx < o.x + os.w && cx + s.w > o.x && cy < o.y + os.h && cy + s.h > o.y;
        });
        let best = null;
        for (const o of others) {
            const os = Monitors.logical(o);
            for (const c of [{ x: o.x + os.w, y: align(y, o.y, os.h, s.h) }, { x: o.x - s.w, y: align(y, o.y, os.h, s.h) },
                             { x: align(x, o.x, os.w, s.w), y: o.y + os.h }, { x: align(x, o.x, os.w, s.w), y: o.y - s.h }]) {
                const dist = Math.hypot(c.x - x, c.y - y);
                if (!overlaps(c.x, c.y) && (best === null || dist < best.d))
                    best = { x: c.x, y: c.y, d: dist };
            }
        }
        if (best === null) {
            Monitors.draft = Monitors.clone(Monitors.draft);   // back where it was
            return;
        }
        me.x = Math.round(best.x);
        me.y = Math.round(best.y);
        // The top-left monitor at 0x0.
        const on = d.filter(m => m.enabled);
        const mx = Math.min(...on.map(m => m.x)), my = Math.min(...on.map(m => m.y));
        for (const m of on) {
            m.x -= mx;
            m.y -= my;
        }
        Monitors.draft = d;
    }

    // Where workspaces past the monitors' own are made (services/Monitors.qml).
    Section {
        id: workspacesSection
        visible: Monitors.current.filter(m => m.enabled).length > 1
        title: "Workspaces"
        note: "Each monitor starts with a workspace of its own; workspace 1 is on the main display. This is about the ones you open after that, with SUPER and a number."
        SettingRow {
            id: newRow
            readonly property bool onMain: Monitors.newWorkspaces === "main"
            icon: "list-add-symbolic"
            title: onMain ? "New workspaces open on the main display" : "New workspaces open on the monitor you're on"
            subtitle: onMain ? "Whichever monitor you are on. Turn it off to open them where you are." : "Turn it on to open them on the main display."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: newRow.onMain
                onToggled: Monitors.setNewWorkspaces(newRow.onMain ? "current" : "main")
            }
        }
    }

    Section {
        title: "Monitors"
        note: Monitors.saved
            ? "Your layout is saved in ~/.local/state/nikita-shell/monitors.lua; \"Automatic\" forgets it."
            : "Drag a monitor to place it. Changes apply at once and go back by themselves unless you keep them."

        // The layout, to scale; the selected monitor below.
        Item {
            id: map
            width: parent.width
            height: 200
            readonly property var shown: Monitors.draft.map((m, i) => ({ m: m, i: i })).filter(e => e.m.enabled)
            readonly property var box: {
                if (shown.length === 0)
                    return { x: 0, y: 0, w: 1, h: 1 };
                const r = shown.map(e => [e.m.x, e.m.y, e.m.x + Monitors.logical(e.m).w, e.m.y + Monitors.logical(e.m).h]);
                const x = Math.min(...r.map(v => v[0])), y = Math.min(...r.map(v => v[1]));
                return { x: x, y: y, w: Math.max(...r.map(v => v[2])) - x, h: Math.max(...r.map(v => v[3])) - y };
            }
            readonly property real k: Math.min((width - 64) / box.w, (height - 48) / box.h)
            readonly property real ox: (width - box.w * k) / 2
            readonly property real oy: (height - box.h * k) / 2

            Repeater {
                model: map.shown

                Rectangle {
                    id: screenBox
                    required property var modelData
                    readonly property var size: Monitors.logical(modelData.m)
                    readonly property bool chosen: page.selected === modelData.i
                    x: map.ox + (modelData.m.x - map.box.x) * map.k
                    y: map.oy + (modelData.m.y - map.box.y) * map.k
                    width: size.w * map.k - 2
                    height: size.h * map.k - 2
                    radius: Theme.radiusS
                    color: chosen ? Theme.accentSoft : boxArea.containsMouse ? Theme.hoverFill : Theme.control
                    border.width: 1
                    border.color: chosen ? Theme.accent : Theme.divider
                    z: boxArea.drag.active ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screenBox.modelData.m.name
                            color: screenBox.chosen ? Theme.accent : Theme.fg
                            font.pixelSize: Theme.textSmall
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            visible: map.shown.length > 1 && Monitors.identity(screenBox.modelData.m) === Monitors.main
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Main · 1"
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                        }
                    }
                    MouseArea {
                        id: boxArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: map.shown.length > 1 ? Qt.SizeAllCursor : Qt.PointingHandCursor
                        drag.target: map.shown.length > 1 && !Monitors.asking ? screenBox : null
                        onPressed: page.selected = screenBox.modelData.i
                        onReleased: if (drag.active || screenBox.x !== map.ox + (screenBox.modelData.m.x - map.box.x) * map.k)
                            page.drop(screenBox.modelData.i, (screenBox.x - map.ox) / map.k + map.box.x, (screenBox.y - map.oy) / map.k + map.box.y)
                    }
                }
            }
        }

        // Monitors that are off aren't on the map: pick them here.
        Flow {
            visible: Monitors.draft.length > 1
            x: 18
            width: parent.width - 36
            spacing: Theme.spaceS
            bottomPadding: Theme.spaceS
            Repeater {
                model: Monitors.draft
                PillButton {
                    required property var modelData
                    required property int index
                    text: modelData.name + (modelData.enabled ? "" : " (off)")
                    active: page.selected === index
                    onClicked: page.selected = index
                }
            }
        }

        SettingRow {
            visible: page.mon !== null
            icon: "video-display-symbolic"
            title: page.mon ? page.mon.name : ""
            subtitle: page.mon ? page.mon.description : ""
            StyledText {
                visible: page.mon !== null && page.mon.enabled && Monitors.draft.filter(m => m.enabled).length === 1
                anchors.verticalCenter: parent.verticalCenter
                text: "The only one on"
                color: Theme.dim
                font.pixelSize: Theme.textSmall
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                visible: !(page.mon !== null && page.mon.enabled && Monitors.draft.filter(m => m.enabled).length === 1)
                checked: page.mon !== null && page.mon.enabled
                onToggled: Monitors.set(page.selected, "enabled", !page.mon.enabled)
            }
        }
        // Workspace 1 and the start of the session (services/Monitors.qml): applied at
        // once, not with the layout below.
        SettingRow {
            id: mainRow
            readonly property bool isMain: page.mon !== null && Monitors.identity(page.mon) === Monitors.main
            visible: page.mon !== null && page.mon.enabled && Monitors.current.filter(m => m.enabled).length > 1
            icon: "starred-symbolic"
            title: isMain ? "This is the main display" : "Make this the main display"
            subtitle: isMain
                ? "Workspace 1 (SUPER + 1) is here and the session starts here. To change it, turn it on for another one."
                : "Workspace 1 (SUPER + 1) and the start of the session move here."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: mainRow.isMain
                onToggled: if (!mainRow.isMain) Monitors.setMain(Monitors.identity(page.mon))
            }
        }
        DropdownRow {
            visible: page.mon !== null && page.mon.enabled
            icon: "view-fullscreen-symbolic"
            title: "Resolution"
            options: page.mon ? page.resolutions(page.mon) : []
            current: page.mon ? [page.mon.width, page.mon.height] : null
            onPicked: v => page.resize(page.selected, m => {
                // The rate in use if this size has it, else the highest.
                const rates = page.allRates(m, v[0], v[1]);
                m.width = v[0];
                m.height = v[1];
                if (rates.indexOf(m.refresh) < 0)
                    m.refresh = rates[0];
                if (page.scales(m).every(s => s.value !== m.scale || Math.abs(m.width / m.scale - Math.round(m.width / m.scale)) > 0.01))
                    m.scale = 1;
            })
        }
        DropdownRow {
            visible: page.mon !== null && page.mon.enabled
            icon: "view-refresh-symbolic"
            title: "Refresh rate"
            options: page.mon ? page.rates(page.mon) : []
            current: page.mon ? page.mon.refresh : null
            onPicked: v => Monitors.set(page.selected, "refresh", v)
        }
        DropdownRow {
            visible: page.mon !== null && page.mon.enabled
            icon: "zoom-in-symbolic"
            title: "Scale"
            subtitle: "Larger text and windows; 100 % shows the most."
            options: page.mon ? page.scales(page.mon) : []
            current: page.mon ? page.mon.scale : null
            onPicked: v => page.resize(page.selected, m => m.scale = v)
        }
        DropdownRow {
            visible: page.mon !== null && page.mon.enabled
            icon: "object-rotate-right-symbolic"
            title: "Rotation"
            options: [{ label: "Normal", value: 0 }, { label: "90°", value: 1, detail: "Portrait" }, { label: "180°", value: 2, detail: "Upside down" }, { label: "270°", value: 3, detail: "Portrait, the other way" }]
            current: page.mon ? page.mon.transform : null
            onPicked: v => page.resize(page.selected, m => m.transform = v)
        }

        // Apply, or the question after applying.
        Item {
            width: parent.width
            height: 56

            Row {
                visible: !Monitors.asking
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS
                PillButton {
                    visible: Monitors.saved
                    text: "Automatic"
                    tip: "Forget the saved layout: every monitor in its preferred mode"
                    onClicked: Monitors.automatic()
                }
                PillButton {
                    text: "Undo changes"
                    interactive: Monitors.changed
                    onClicked: Monitors.undo()
                }
                PillButton {
                    text: "Apply"
                    interactive: Monitors.changed
                    onClicked: Monitors.apply()
                }
            }
            Row {
                visible: Monitors.asking
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: Theme.spaceL
                spacing: Theme.spaceS
                StyledText {
                    width: parent.width - back.width - keepIt.width - 2 * parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Keep these display settings? Going back in ${Monitors.countdown} s.`
                    color: Theme.warn
                }
                PillButton {
                    id: back
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Go back"
                    onClicked: Monitors.revert()
                }
                PillButton {
                    id: keepIt
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Keep"
                    active: true
                    onClicked: Monitors.keep()
                }
            }
        }
    }
}
