// ~/nikita-shell/dotfiles/quickshell/settings/SettingsPages.qml
//
// The Settings pages: the window's sidebar and the launcher both list them.
// `keys` are extra words a search should find the page by. The order is the sidebar's:
// what people come for first (network, sound, screen, power), then the look, then input.
pragma Singleton

import Quickshell

Singleton {
    readonly property var list: [
        { id: "network", group: 0, title: "Network", subtitle: "Wi-Fi, wired", icon: "network-wireless-symbolic", keys: "wifi internet password nmtui vpn ethernet cable wired lan" },
        { id: "bluetooth", group: 0, title: "Bluetooth", subtitle: "Devices, pairing", icon: "bluetooth-symbolic", keys: "headphones mouse keyboard pair" },
        { id: "sound", group: 0, title: "Sound", subtitle: "Volume, devices, apps", icon: "audio-volume-high-symbolic", keys: "audio speakers microphone output input mute" },
        { id: "display", group: 0, title: "Display", subtitle: "Brightness, monitors", icon: "video-display-symbolic", keys: "screen resolution refresh scale" },
        { id: "power", group: 0, title: "Power", subtitle: "Battery, mode, idle", icon: "battery-level-80-symbolic", keys: "performance saver profile suspend lock awake sleep" },
        { id: "appearance", group: 1, title: "Appearance", subtitle: "Wallpaper, picture, theme", icon: "preferences-color-symbolic", keys: "dark light wallpaper background transparency blur picture photo avatar profile face user account" },
        { id: "panels", group: 1, title: "Panels", subtitle: "Edges, workspaces", icon: "view-grid-symbolic", keys: "dashboard tray clipboard rail hover touch corner" },
        { id: "notifications", group: 1, title: "Notifications", subtitle: "Do not disturb, history", icon: "preferences-system-notifications-symbolic", keys: "dnd toasts" },
        { id: "keyboard", group: 2, title: "Keyboard", subtitle: "Layouts, typing, backlight", icon: "input-keyboard-symbolic", keys: "layout language repeat delay speed num lock backlight light teclado idioma" },
        { id: "shortcuts", group: 2, title: "Shortcuts", subtitle: "The keys for every action", icon: "preferences-desktop-keyboard-shortcuts-symbolic", keys: "keybinds keys binds hotkeys shortcut rebind custom command atajos teclas" },
        { id: "pointer", group: 2, title: "Mouse & touchpad", subtitle: "Speed, scrolling, gestures", icon: "input-touchpad-symbolic", keys: "mouse touchpad trackpad pointer cursor speed sensitivity acceleration scroll natural tap click gestures swipe pinch fingers left-handed raton" },
        { id: "datetime", group: 3, title: "Date & time", subtitle: "Time zone, clock", icon: "preferences-system-time-symbolic", keys: "clock time date timezone zone ntp automatic 24 hour 12 hour rtc hora fecha zona" },
        { id: "apps", group: 3, title: "Default apps", subtitle: "Browser, files, images, video", icon: "applications-system-symbolic", keys: "mime open with browser viewer player" },
        { id: "about", group: 3, title: "About", subtitle: "This computer", icon: "help-about-symbolic", keys: "system version kernel hardware cpu gpu" }
    ]
}
