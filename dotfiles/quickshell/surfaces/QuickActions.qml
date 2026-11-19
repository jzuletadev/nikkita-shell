// ~/nikita-shell/dotfiles/quickshell/surfaces/QuickActions.qml

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.common
import qs.services

EdgePanel {
    id: qa

    name: "quickactions"
    edge: "bottom"
    placement: "end"
    span: m.corner
    depth: content.implicitHeight + 2 * inset

    property bool satty: false
    property bool withAudio: false

    // Captures and recordings start once the panel has finished leaving, so it is
    // neither in the picture nor under slurp's crosshair. Meanwhile it can't reopen
    // (that would cancel the leaving, and the capture with it).
    property var afterClose: null
    hoverable: touchable && Prefs.opensOnTouch(name) && !m.edgesOff && afterClose === null
    function closeThen(f) {
        afterClose = f;
        qa.close();
    }
    onClosed: if (afterClose !== null) {
        const f = afterClose;
        afterClose = null;
        f();
    }

    function capture(region) {
        const arg = region ? (satty ? "annotate" : "region") : "screen";
        // screenshot.sh reports its own failures. `annotate` only knows regions: for
        // the full screen it captures, then Satty opens the newest file.
        let sh = `"$1" ${arg}`;
        if (!region && satty)
            sh += ` && f=$(ls -t "$2"/*.png 2>/dev/null | head -1) && [ -n "$f" ] && exec satty -f "$f"`;
        closeThen(() => Commands.launch(["sh", "-c", sh, "sh", Paths.script("screenshot.sh"), Paths.screenshots], "Screenshot"));
    }

    function record(region) {
        if (Recorder.active) {
            Recorder.stop();
            return;
        }
        closeThen(() => Recorder.start(region, qa.withAudio));
    }

    function openSettings(page) {
        qa.close();
        ShellState.openSettings(page);
    }

    function openFolder(dir) {
        qa.close();
        ShellState.openFolder(dir);
    }

    component Section: Column {
        id: section
        property string title
        property string icon
        default property alias buttons: box.data
        width: parent.width
        spacing: Theme.spaceS

        Row {
            spacing: Theme.spaceS
            Icon { name: section.icon; size: 12; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: section.title; color: Theme.muted; font.pixelSize: Theme.textSmall; font.weight: Font.Medium }
        }
        Row {
            id: box
            width: parent.width
            spacing: Theme.spaceS
        }
    }

    Column {
        id: content
        anchors.fill: parent
        spacing: Theme.spaceM

        Section {
            title: "Screenshot"
            icon: "camera-photo-symbolic"
            PillButton { text: "Screen"; onClicked: qa.capture(false) }
            PillButton { text: "Region"; onClicked: qa.capture(true) }
            PillButton { text: "Satty"; toggle: true; active: qa.satty; tip: "Annotate\nOpens the screenshot in Satty to draw on it"; onClicked: qa.satty = !qa.satty }
            Item { width: parent.width - x - 32 - parent.spacing; height: 1 }
            PillButton { icon: "folder-symbolic"; tip: "Screenshots folder"; onClicked: qa.openFolder(Paths.screenshots) }
        }

        Section {
            title: Recorder.active ? "Recording · click to stop" : "Recording"
            icon: "media-record-symbolic"
            PillButton {
                text: Recorder.active ? "Stop" : "Screen"
                icon: Recorder.active ? "media-playback-stop-symbolic" : ""
                active: Recorder.active
                onClicked: qa.record(false)
            }
            PillButton { visible: !Recorder.active; text: "Region"; onClicked: qa.record(true) }
            PillButton { visible: !Recorder.active; text: "Audio"; toggle: true; active: qa.withAudio; tip: "Record the sound too"; onClicked: qa.withAudio = !qa.withAudio }
            Item { width: parent.width - x - 32 - parent.spacing; height: 1 }
            PillButton { icon: "folder-symbolic"; tip: "Recordings folder"; onClicked: qa.openFolder(Recorder.dir) }
        }

        // Toggles; a right click opens its Settings page.
        Section {
            title: "Quick actions"
            icon: "view-grid-symbolic"

            PillButton {
                icon: Networking.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-disabled-symbolic"
                active: Networking.wifiEnabled
                interactive: Networking.wifiHardwareEnabled
                tip: Networking.wifiHardwareEnabled ? "Wi-Fi\nRight click: settings" : "Wi-Fi is off by a hardware switch"
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                onRightClicked: qa.openSettings("network")
            }
            PillButton {
                visible: Net.cable
                icon: Net.wiredConnected ? "network-wired-symbolic" : "network-wired-disconnected-symbolic"
                active: Net.wiredConnected
                busy: Net.wiredBusy
                tip: "Wired network\n" + (Net.wiredConnected ? Net.speed(Net.wired.linkSpeed) + " · " : "") + "Right click: settings"
                onClicked: Net.toggleWired()
                onRightClicked: qa.openSettings("network")
            }
            PillButton {
                readonly property var adapter: Bluetooth.defaultAdapter
                icon: adapter !== null && adapter.enabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
                active: adapter !== null && adapter.enabled
                interactive: adapter !== null
                tip: adapter !== null ? "Bluetooth\nRight click: settings" : "No Bluetooth adapter"
                onClicked: adapter.enabled = !adapter.enabled
                onRightClicked: qa.openSettings("bluetooth")
            }
            PillButton {
                icon: Audio.micMuted ? "microphone-sensitivity-muted-symbolic" : "microphone-sensitivity-high-symbolic"
                active: !Audio.micMuted
                interactive: Audio.source !== null
                tip: (Audio.micMuted ? "Microphone (muted)" : "Microphone") + "\nRight click: sound settings"
                onClicked: Audio.toggleMic()
                onRightClicked: qa.openSettings("sound")
            }
            // The style in use: its icon and its name, and the click switches to the
            // other. Not filled in either: neither style is "on", and so the pointer
            // lights it the same way in both.
            PillButton {
                glyph: Theme.dark ? Glyphs.darkStyle : Glyphs.lightStyle
                tip: (Theme.dark ? "Dark style\nClick: switch to light" : "Light style\nClick: switch to dark") + "\nRight click: appearance settings"
                onClicked: Commands.run([Paths.script("theme-manager.sh"), Theme.dark ? "light" : "dark"], "Switching the theme")
                onRightClicked: qa.openSettings("appearance")
            }
            PillButton {
                icon: "night-light-symbolic"
                active: NightLight.enabled
                tip: "Night light · " + NightLight.status + "\nRight click: display settings"
                onClicked: Prefs.set("nightLight", !Prefs.nightLight)
                onRightClicked: qa.openSettings("display")
            }
            Item { width: parent.width - x - settingsButton.width - parent.spacing; height: 1 }
            // A Nerd Font gear: Adwaita's settings icon is a wrench and a screwdriver.
            PillButton {
                id: settingsButton
                glyph: Glyphs.settings
                tip: "Settings" + (HyprSettings.keysLabel("settings") !== "" ? "\n" + HyprSettings.keysLabel("settings") : "")
                onClicked: qa.openSettings("")
            }
        }
    }
}
