// ~/nikita-shell/dotfiles/quickshell/settings/DatetimePage.qml
//
// Date, time and time zone through timedatectl. Every change asks for the admin
// password (surfaces/AuthDialog.qml, the polkit agent).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    // ---- what timedatectl says ----
    property var td: ({})
    readonly property bool ntp: td.NTP === "yes"
    readonly property bool synced: td.NTPSynchronized === "yes"
    readonly property bool localRtc: td.LocalRTC === "yes"
    readonly property string zone: td.Timezone || ""

    function refresh() {
        show.running = true;
    }
    Process {
        id: show
        command: ["timedatectl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        o[line.slice(0, i)] = line.slice(i + 1);
                }
                // The zone may have changed: the JS engine caches it.
                Date.timeZoneUpdated();
                page.now = new Date();
                page.td = o;
            }
        }
    }
    Component.onCompleted: {
        refresh();
        resetDraft();
    }

    // ---- changing something: one at a time ----
    property string busy: ""            // what is being changed: ntp, zone, time, rtc
    property string error: ""

    function run(what, args) {
        if (busy !== "")
            return;
        error = "";
        busy = what;
        runner.command = ["sh", "-c", 'out=$(timedatectl "$@" 2>&1); echo "$?"; printf "%s" "$out"', "sh"].concat(args);
        runner.running = true;
    }
    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                const code = parseInt(nl < 0 ? text : text.slice(0, nl));
                const out = nl < 0 ? "" : text.slice(nl + 1);
                if (code !== 0)
                    page.error = page.explain(out);
                page.busy = "";
                page.refresh();
            }
        }
    }
    function explain(t) {
        if (/not authorized|access denied|authentication|dismissed|cancel/i.test(t))
            return "Not changed: the administrator password wasn't given.";
        if (/automatic time synchronization is enabled/i.test(t))
            return "Not changed: turn off automatic time first.";
        return "Not changed: " + (t.trim().split("\n")[0] || "timedatectl failed");
    }

    // ---- now ----
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: page.now = new Date()
    }
    function offset() {
        const m = -page.now.getTimezoneOffset();
        const a = Math.abs(m);
        return "UTC" + (m < 0 ? "−" : "+") + String(Math.floor(a / 60)).padStart(2, "0") + ":" + String(a % 60).padStart(2, "0");
    }

    // ======== the hero: what time it is, and where ========
    Rectangle {
        width: parent.width
        height: 150
        radius: Theme.radiusXl
        color: Theme.alpha(Theme.fg, 0.045)

        Column {
            anchors.centerIn: parent
            spacing: Theme.spaceXs
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Prefs.clock24h ? Qt.formatTime(page.now, "HH:mm:ss") : Qt.formatTime(page.now, "h:mm:ss AP")
                font.pixelSize: Theme.textHero
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(page.now, "dddd, d MMMM yyyy")
                color: Theme.muted
                font.pixelSize: Theme.textLarge
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (page.zone || "…").replace(/_/g, " ") + "  ·  " + page.offset()
                color: Theme.dim
            }
        }
    }

    StyledText {
        visible: page.error !== ""
        width: parent.width
        text: page.error
        color: Theme.bad
        wrapMode: Text.Wrap
    }

    // ======== automatic ========
    Section {
        title: "Automatic"
        SettingRow {
            icon: "preferences-system-time-symbolic"
            title: "Set the time automatically"
            subtitle: !page.ntp ? "Off: set it by hand, below." : page.synced ? "From the internet (NTP), synchronized." : "From the internet (NTP), not synchronized yet."
            Spinner {
                visible: page.busy === "ntp"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.muted
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.ntp
                onToggled: page.run("ntp", ["set-ntp", page.ntp ? "false" : "true"])
            }
        }
    }

    // ======== time zone ========
    Section {
        title: "Time zone"
        padding: 0

        SettingRow {
            icon: "find-location-symbolic"
            title: (page.zone || "…").replace(/_/g, " ")
            subtitle: page.offset() + (page.zone === "UTC" ? " · UTC is rarely anyone's real zone: pick yours." : "")
            Spinner {
                visible: page.busy === "zone"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.muted
            }
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: zones.open ? "Close" : "Change"
                active: zones.open
                onClicked: zones.toggle()
            }
        }

        Column {
            id: zones
            property bool open: false
            property var all: []
            readonly property var shown: {
                const q = filter.text.trim().toLowerCase().replace(/ /g, "_");
                if (!q)
                    return all;
                return all.filter(z => z.zone.toLowerCase().includes(q) || ("utc" + z.offset).includes(q));
            }
            function toggle() {
                open = !open;
                if (open) {
                    filter.text = "";
                    filter.input.forceActiveFocus();
                    if (all.length === 0)
                        list.running = true;
                }
            }

            visible: open
            width: parent.width
            padding: Theme.spaceL
            spacing: Theme.spaceM

            Process {
                id: list
                command: ["python3", Paths.script("timezones.py")]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            zones.all = JSON.parse(text);
                        } catch (e) {
                            page.error = "Couldn't list the time zones.";
                        }
                    }
                }
            }

            InputField {
                id: filter
                width: parent.width - 28
                placeholder: "Search: a city, a region, or an offset like +05"
            }
            Item {
                width: parent.width - 28
                height: 300
                ListView {
                    id: zoneView
                    anchors.fill: parent
                    clip: true
                    spacing: Theme.spaceXs
                    boundsBehavior: Flickable.StopAtBounds
                    model: zones.shown
                    delegate: ListRow {
                        required property var modelData
                        width: zoneView.width - 6
                        title: modelData.zone.replace(/_/g, " ")
                        subtitle: "UTC" + modelData.offset.replace("-", "−")
                        active: modelData.zone === page.zone
                        onClicked: {
                            zones.open = false;
                            if (modelData.zone !== page.zone)
                                page.run("zone", ["set-timezone", modelData.zone]);
                        }
                    }
                }
                ScrollHint { view: zoneView }
                StyledText {
                    anchors.centerIn: parent
                    visible: zones.shown.length === 0
                    text: zones.all.length === 0 ? "Loading…" : "No zone matches"
                    color: Theme.dim
                }
            }
        }
    }

    // ======== by hand ========
    // A draft, taken from now; Set applies it.
    property int dYear: 2026
    property int dMonth: 1
    property int dDay: 1
    property int dHour: 0
    property int dMinute: 0
    function resetDraft() {
        const t = new Date();
        dYear = t.getFullYear();
        dMonth = t.getMonth() + 1;
        dDay = t.getDate();
        dHour = t.getHours();
        dMinute = t.getMinutes();
    }
    onNtpChanged: if (!ntp) resetDraft()
    readonly property int daysInMonth: new Date(dYear, dMonth, 0).getDate()
    onDaysInMonthChanged: if (dDay > daysInMonth) dDay = daysInMonth

    component Stepper: Column {
        id: st
        property string label
        property int value
        property int from
        property int to
        property int digits: 2
        property var names: []          // words instead of numbers (AM/PM)
        signal moved(int v)

        function step(d) {
            const span = to - from + 1;
            moved(from + ((value - from + d) % span + span) % span);
        }

        width: 76
        spacing: Theme.spaceXs

        PillButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 28
            flat: true
            icon: "pan-up-symbolic"
            iconSize: 14
            interactive: !page.ntp
            onClicked: st.step(1)
        }
        Rectangle {
            width: parent.width
            height: 50
            radius: Theme.radiusM
            color: Theme.alpha(Theme.fg, 0.05)
            StyledText {
                anchors.centerIn: parent
                text: st.names.length > 0 ? st.names[st.value - st.from] : String(st.value).padStart(st.digits, "0")
                font.pixelSize: st.names.length > 0 ? 20 : 24
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: page.ntp ? Theme.dim : Theme.fg
            }
        }
        PillButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: 28
            flat: true
            icon: "pan-down-symbolic"
            iconSize: 14
            interactive: !page.ntp
            onClicked: st.step(-1)
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: st.label
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
    }

    Section {
        title: "Set by hand"
        note: page.ntp ? "Automatic time is on: turn it off above to set the date and time yourself." : "The arrows or the mouse wheel move each part. Set applies it."
        padding: Theme.spaceL

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceM

            Stepper { label: "Day"; value: page.dDay; from: 1; to: page.daysInMonth; onMoved: v => page.dDay = v }
            Stepper { label: "Month"; value: page.dMonth; from: 1; to: 12; onMoved: v => page.dMonth = v }
            Stepper { label: "Year"; value: page.dYear; from: 2000; to: 2099; digits: 4; width: 92; onMoved: v => page.dYear = v }
            Item { width: 14; height: 1 }
            // The draft keeps 0-23 on a 12-hour clock too.
            Stepper {
                label: "Hour"
                value: Prefs.clock24h ? page.dHour : (page.dHour % 12 || 12)
                from: Prefs.clock24h ? 0 : 1
                to: Prefs.clock24h ? 23 : 12
                digits: Prefs.clock24h ? 2 : 1
                onMoved: v => page.dHour = Prefs.clock24h ? v : (v % 12) + (page.dHour >= 12 ? 12 : 0)
            }
            Stepper { label: "Minute"; value: page.dMinute; from: 0; to: 59; onMoved: v => page.dMinute = v }
            Stepper {
                visible: !Prefs.clock24h
                label: "AM / PM"
                value: page.dHour >= 12 ? 1 : 0
                from: 0
                to: 1
                names: ["AM", "PM"]
                onMoved: v => page.dHour = (page.dHour % 12) + v * 12
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceS
            topPadding: Theme.spaceL
            PillButton {
                height: 36
                text: "Now"
                interactive: !page.ntp
                tip: "Back to the current date and time"
                onClicked: page.resetDraft()
            }
            PillButton {
                height: 36
                width: 110
                text: page.busy === "time" ? "Setting…" : "Set"
                active: true
                busy: page.busy === "time"
                interactive: !page.ntp
                onClicked: {
                    const two = n => String(n).padStart(2, "0");
                    page.run("time", ["set-time", `${page.dYear}-${two(page.dMonth)}-${two(page.dDay)} ${two(page.dHour)}:${two(page.dMinute)}:00`]);
                }
            }
        }
    }

    // ======== how the clock reads ========
    Section {
        title: "Clock"
        SettingRow {
            icon: "preferences-system-time-symbolic"
            title: "24-hour clock"
            subtitle: Prefs.clock24h ? "Now: 18:30. In the dashboard, the lock screen and here." : "Now: 6:30 PM. In the dashboard, the lock screen and here."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Prefs.clock24h
                onToggled: Prefs.set("clock24h", !Prefs.clock24h)
            }
        }
        SettingRow {
            icon: "computer-symbolic"
            title: "Hardware clock in local time"
            subtitle: "Only for dual boot with Windows, which keeps it that way. Off (UTC) is the Linux default."
            Spinner {
                visible: page.busy === "rtc"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.muted
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.localRtc
                onToggled: page.run("rtc", ["set-local-rtc", page.localRtc ? "0" : "1"])
            }
        }
    }
}
