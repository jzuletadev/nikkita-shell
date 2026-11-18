// ~/nikita-shell/dotfiles/quickshell/settings/AboutPage.qml
// This desktop and this computer, from `system-stats.py --machine`. The Arch logo
// on the workspace rail opens this page.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    readonly property var f: SystemStats.machine
    property string qsVersion: ""

    Component.onCompleted: {
        readSnapshots();
        SystemStats.loadMachine();
        version.running = true;
    }
    Process {
        id: version
        command: ["qs", "--version"]
        stdout: StdioCollector {
            onStreamFinished: page.qsVersion = (/Quickshell ([\d.]+)/.exec(text) || ["", ""])[1]
        }
    }

    function uptime() {
        if (!f)
            return "";
        const s = Math.floor(Date.now() / 1000 - f.boot);
        const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        return (d > 0 ? d + " d " : "") + (h > 0 ? h + " h " : "") + m + " min";
    }

    Rectangle {
        width: parent.width
        height: 210
        radius: Theme.radiusXl
        color: Theme.alpha(Theme.fg, 0.045)

        Column {
            anchors.centerIn: parent
            spacing: Theme.spaceM
            Logo {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 76
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nikita Shell"
                font.pixelSize: Theme.textDisplay
                font.weight: Font.DemiBold
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.f ? [page.f.os, "Hyprland " + (page.f.hyprland || "").replace(/^v/, ""), page.qsVersion ? "Quickshell " + page.qsVersion : ""].filter(x => x).join("  ·  ") : "…"
                color: Theme.muted
            }
        }
    }

    Section {
        title: "This computer"
        Repeater {
            model: !page.f ? [] : [
                ["computer-symbolic", "Name", page.f.host],
                ["avatar-default-symbolic", "User", page.f.user],
                ["computer-symbolic", "Device", page.f.model],
                ["", "Processor", page.f.cpu + (page.f.cores ? ` · ${page.f.cores} threads` : ""), 0xF0EE0],
                ["", "Graphics", (page.f.gpus || []).join(", "), 0xF08AE],
                ["", "Memory", SystemStats.bytes(page.f.memory), 0xF035B],
                ["drive-harddisk-symbolic", "Disk", page.f.disk ? SystemStats.bytes(page.f.disk.used) + " used of " + SystemStats.bytes(page.f.disk.total) : ""],
                ["preferences-system-time-symbolic", "Uptime", page.uptime()]
            ].filter(x => x[2])
            SettingRow {
                id: hw
                required property var modelData
                icon: modelData[0]
                glyph: modelData[3] || 0
                title: modelData[1]
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(hw.modelData[2])
                    color: Theme.muted
                }
            }
        }
    }

    Section {
        title: "Software"
        Repeater {
            model: !page.f ? [] : [
                ["Distribution", page.f.os],
                ["Kernel", page.f.kernel],
                ["Hyprland", (page.f.hyprland || "").replace(/^v/, "")],
                ["Quickshell", page.qsVersion],
                ["Packages", String(page.f.packages)],
                ["Shell", page.f.shell],
                ["Theme", Theme.dark ? "Dark" : "Light"]
            ].filter(x => x[1])
            SettingRow {
                id: sw
                required property var modelData
                title: modelData[0]
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sw.modelData[1]
                    color: Theme.muted
                }
            }
        }
    }

    // Where this desktop comes from, online: the address of the repository's
    // `origin` (a fork shows its own), opened in your browser.
    property string projectUrl: ""
    readonly property string projectHost: projectUrl.replace(/^https:\/\/([^\/]+)\/.*$/, "$1")
    readonly property string projectSite: ({ "github.com": "GitHub", "gitlab.com": "GitLab", "codeberg.org": "Codeberg" })[projectHost] ?? projectHost
    Process {
        running: true
        command: ["git", "-C", Paths.repo, "remote", "get-url", "origin"]
        stdout: StdioCollector {
            // git@github.com:user/repo.git and https://github.com/user/repo.git alike.
            onStreamFinished: {
                const u = text.trim().replace(/^git@([^:]+):/, "https://$1/").replace(/\.git$/, "");
                page.projectUrl = /^https:\/\/[^\/]+\/./.test(u) ? u : "";
            }
        }
    }
    Section {
        visible: page.projectUrl !== ""
        SettingRow {
            icon: "web-browser-symbolic"
            title: "The project on " + page.projectSite
            subtitle: page.projectUrl.replace(/^https:\/\/[^\/]+\//, "") + " · the source, what changed in each version, and where to report a problem."
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Open"
                tip: "Open " + page.projectUrl + " in the browser"
                onClicked: {
                    ShellState.settingsOpen = false;
                    Commands.launch(["xdg-open", page.projectUrl], "Opening " + page.projectSite);
                }
            }
        }
    }

    Section {
        title: "Updates"
        note: "Checked when this page or the Power corner opens, if the last check is older than six hours. pacman asks for your password in the terminal."
        Component.onCompleted: Updates.checkIfStale()
        SettingRow {
            icon: "software-update-available-symbolic"
            title: Updates.summary
            subtitle: Updates.error !== "" && Updates.checkedAt > 0 ? "The last check failed: " + Updates.error
                : Updates.repo.concat(Updates.aur).slice(0, 8).map(u => u.name).join(", ") + (Updates.count > 8 ? "…" : "")
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Check now"
                busy: Updates.checking
                onClicked: Updates.check(true)
            }
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Updates.count > 0
                text: "Update"
                onClicked: Updates.install()
            }
        }
    }

    // ---- snapshots before updates (scripts/snapshots.sh), on a btrfs root ----
    property var snap: null
    function readSnapshots() {
        snapStatus.running = true;
    }
    Process {
        id: snapStatus
        command: [Paths.script("snapshots.sh"), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.snap = JSON.parse(text);
                } catch (e) {
                    page.snap = null;
                }
            }
        }
    }
    property bool settingUp: false
    Section {
        title: "Snapshots"
        visible: page.snap !== null && page.snap.btrfs
        note: page.snap && page.snap.configured
            ? "To put the system back as it was before an update: sudo snapper -c root undochange N..0, with N the \"pre\" snapshot. Your home folder isn't in them."
            : "A way back from a bad update: a snapshot of the system before and after every pacman run, the last 10 kept. Setting it up asks for your password."
        SettingRow {
            icon: "drive-harddisk-symbolic"
            title: page.snap && page.snap.configured ? "On: before and after every update" : "Off"
            subtitle: {
                const s = page.snap ? page.snap.snapshots : [];
                if (!page.snap || !page.snap.configured)
                    return "This system is on btrfs, so it can keep them.";
                if (s.length === 0)
                    return "None yet: the next update makes the first ones.";
                const last = s[s.length - 1];
                return s.length + " kept · the last, #" + last.number + ": " + (last.description || "snapshot") + " · " + last.date;
            }
            PillButton {
                visible: page.snap !== null && !page.snap.configured
                anchors.verticalCenter: parent.verticalCenter
                text: "Set up"
                busy: page.settingUp
                onClicked: {
                    page.settingUp = true;
                    Commands.runAsRoot([Paths.script("snapshots.sh"), "setup"], "Setting up snapshots", () => {
                        page.settingUp = false;
                        page.readSnapshots();
                    });
                }
            }
        }
    }
}
