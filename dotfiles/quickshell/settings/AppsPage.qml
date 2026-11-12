// ~/nikkita-shell/dotfiles/quickshell/settings/AppsPage.qml
//
// The app that opens each kind of file, through `gio mime` (~/.config/mimeapps.list).
// Choosing an app sets it for every type of that kind (all image formats, say).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Column {
    id: page
    spacing: Theme.spaceXl

    readonly property var kinds: [
        { id: "browser", title: "Web browser", icon: "web-browser-symbolic", types: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html"] },
        { id: "files", title: "Folders", icon: "folder-symbolic", types: ["inode/directory"] },
        { id: "images", title: "Images", icon: "image-x-generic-symbolic", types: ["image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp"] },
        { id: "video", title: "Video", icon: "video-x-generic-symbolic", types: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"] },
        { id: "music", title: "Music", icon: "audio-x-generic-symbolic", types: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"] },
        { id: "pdf", title: "PDF documents", icon: "x-office-document-symbolic", types: ["application/pdf"] },
        { id: "text", title: "Text files", icon: "text-x-generic-symbolic", types: ["text/plain"] }
    ]

    // kind id -> { current: "org.gnome.Loupe.desktop", options: ["org.gnome.Loupe.desktop", ...] }
    property var info: ({})
    property string expanded: ""

    function entry(desktopId) {
        return desktopId ? DesktopEntries.byId(desktopId.replace(/\.desktop$/, "")) : null;
    }
    function appName(desktopId) {
        const e = entry(desktopId);
        return e ? e.name : desktopId ? desktopId.replace(/\.desktop$/, "") : "Not set";
    }
    function appIcon(desktopId) {
        const e = entry(desktopId);
        return e && e.icon ? e.icon : "application-x-executable";
    }

    function query() {
        reader.running = true;
    }
    function choose(kind, desktopId) {
        writer.command = ["sh", "-c", 'app=$1; shift; for t in "$@"; do gio mime "$t" "$app" >/dev/null; done', "sh", desktopId].concat(kind.types);
        writer.running = true;
        expanded = "";
    }

    Component.onCompleted: query()

    // `gio mime TYPE`, in English (LC_ALL=C) so it can be parsed:
    //   Default application for "image/png": org.gnome.Loupe.desktop
    //   Registered applications:
    //   	org.gnome.Loupe.desktop
    Process {
        id: reader
        command: ["sh", "-c", 'for t in "$@"; do printf "@@%s\\n" "$t"; LC_ALL=C gio mime "$t" 2>/dev/null; done', "sh"].concat(page.kinds.map(k => k.types[0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const block of text.split("@@").slice(1)) {
                    const lines = block.split("\n");
                    const kind = page.kinds.find(k => k.types[0] === lines[0].trim());
                    if (!kind)
                        continue;
                    let current = "", options = [], inRegistered = false;
                    for (const line of lines.slice(1)) {
                        if (line.startsWith("Default application"))
                            current = line.split(": ").pop().trim();
                        else if (line.startsWith("Registered applications"))
                            inRegistered = true;
                        else if (line.startsWith("Recommended applications"))
                            inRegistered = false;
                        else if (inRegistered && line.startsWith("\t"))
                            options.push(line.trim());
                    }
                    v[kind.id] = { current: current, options: options };
                }
                page.info = v;
            }
        }
    }
    Process {
        id: writer
        onExited: page.query()
    }

    Section {
        title: "Open with"
        note: "Click a kind to change its app. The terminal is set in hyprland.lua (`terminal`)."

        Repeater {
            model: page.kinds

            Column {
                id: kind
                required property var modelData
                readonly property var choice: page.info[modelData.id] || { current: "", options: [] }
                readonly property bool open: page.expanded === modelData.id
                width: parent.width

                SettingRow {
                    divider: kind.Positioner.index > 0
                    icon: kind.modelData.icon
                    title: kind.modelData.title
                    subtitle: kind.choice.options.length === 0 ? "No installed app opens these" : kind.choice.options.length + (kind.choice.options.length === 1 ? " app can open these" : " apps can open these")
                    clickable: kind.choice.options.length > 0
                    onClicked: page.expanded = kind.open ? "" : kind.modelData.id

                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: kind.choice.current !== ""
                        name: page.appIcon(kind.choice.current)
                        size: 22
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.appName(kind.choice.current)
                        color: kind.choice.current ? Theme.fg : Theme.dim
                        font.weight: Font.Medium
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: kind.choice.options.length > 0
                        name: "pan-down-symbolic"
                        size: 14
                        color: Theme.muted
                        rotation: kind.open ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: Theme.msNormal } }
                    }
                }

                Column {
                    width: parent.width - 32
                    x: 16
                    spacing: Theme.spaceXs
                    visible: kind.open
                    bottomPadding: Theme.spaceM
                    Repeater {
                        model: kind.open ? kind.choice.options : []
                        ListRow {
                            required property string modelData
                            width: parent.width
                            appIcon: page.appIcon(modelData)
                            title: page.appName(modelData)
                            subtitle: modelData
                            active: modelData === kind.choice.current
                            onClicked: page.choose(kind.modelData, modelData)
                        }
                    }
                }
            }
        }

        SettingRow {
            icon: "utilities-terminal-symbolic"
            title: "Terminal"
            subtitle: "What SUPER + T opens."
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "kitty"
                font.weight: Font.Medium
            }
        }
    }
}
