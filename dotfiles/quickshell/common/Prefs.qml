// ~/nikita-shell/dotfiles/quickshell/common/Prefs.qml
//
// Preferences only the desktop owns, in ~/.local/state/nikita-shell/settings.json
// (the theme, volume and Wi-Fi keep their own homes). The file is watched; writes are
// delayed so a dragged slider doesn't write on every pixel.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: prefs

    // Never below 0.6: under 0.5 hyprland.lua's ignore_alpha stops the blur.
    readonly property real panelOpacity: Math.max(0.6, Math.min(1, store.panelOpacity))
    readonly property bool railPeek: store.railPeek
    readonly property bool clock24h: store.clock24h
    // The first-start hint (services/SystemNotices.qml) has been shown.
    readonly property bool introSeen: store.introSeen
    // Effects (Settings → Appearance): no animation at all, and the desktop clearing
    // for a moment when the wallpaper changes, so the change is seen whole.
    readonly property bool reduceMotion: store.reduceMotion
    readonly property bool peekWallpaper: store.peekWallpaper
    // Panels that don't open on touching their edge, only by key.
    readonly property var manualPanels: store.manualPanels
    // System notices turned off, by category (services/SystemNotices.qml).
    readonly property var quietNotices: store.quietNotices
    // Night light (services/NightLight.qml): times are minutes after midnight.
    readonly property bool nightLight: store.nightLight
    readonly property bool nightScheduled: store.nightScheduled
    readonly property int nightFrom: store.nightFrom
    readonly property int nightTo: store.nightTo
    readonly property int nightTemperature: Math.max(2500, Math.min(6000, store.nightTemperature))
    // What Settings changed in Hyprland (services/HyprSettings.qml turns these into
    // hyprland-settings.lua): input options by name, keys by shortcut id ("" = off),
    // your own shortcuts, and the touchpad gestures (null = hyprland.lua's).
    readonly property var hyprInput: store.hyprInput ?? ({})
    readonly property var shortcutKeys: store.shortcutKeys ?? ({})
    readonly property var customShortcuts: store.customShortcuts ?? []
    readonly property var gestures: store.gestures ?? null

    function set(key, value) {
        store[key] = value;
    }
    // What a setting is before you change it (the JsonAdapter below), for the
    // "back to the default" buttons.
    readonly property var defaults: ({ panelOpacity: 0.92, nightTemperature: 4000, nightFrom: 1200, nightTo: 420, nightScheduled: true })
    function isDefault(key) {
        return JSON.stringify(store[key]) === JSON.stringify(defaults[key]);
    }
    function reset(key) {
        store[key] = defaults[key];
    }
    function opensOnTouch(name) {
        return manualPanels.indexOf(name) < 0;
    }
    function noticeShown(category) {
        return quietNotices.indexOf(category) < 0;
    }
    function setNoticeShown(category, on) {
        const v = [];
        for (const c of quietNotices)
            if (c !== category)
                v.push(c);
        if (!on)
            v.push(category);
        store.quietNotices = v;
    }
    function setOpensOnTouch(name, on) {
        const v = [];
        for (const n of manualPanels)
            if (n !== name)
                v.push(n);
        if (!on)
            v.push(name);
        store.manualPanels = v;
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file
        path: Paths.state + "/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: Paths.syncGreeter()
        // The login screen only reads.
        onAdapterUpdated: if (!Paths.greeter) saveTimer.restart()
        onLoadFailed: if (!Paths.greeter) writeAdapter()

        JsonAdapter {
            id: store
            property real panelOpacity: 0.92
            property bool railPeek: true
            property bool clock24h: true
            property bool introSeen: false
            property bool reduceMotion: false
            property bool peekWallpaper: true
            property list<string> manualPanels: []
            property list<string> quietNotices: []
            property bool nightLight: false
            property bool nightScheduled: true
            property int nightFrom: 1200
            property int nightTo: 420
            property int nightTemperature: 4000
            property var hyprInput: ({})
            property var shortcutKeys: ({})
            property var customShortcuts: []
            property var gestures: null
        }
    }
}
