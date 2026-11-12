// ~/nikkita-shell/dotfiles/quickshell/surfaces/ScreenSurface.qml

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData
    // The screen can go before this surface does (a monitor unplugged).
    readonly property string screenName: modelData ? modelData.name : ""

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nikkita"
    // Never the keyboard: it would steal keys from the windows.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Sizes {
        id: m
        screenWidth: win.width
        screenHeight: win.height
    }

    IdleInhibitor {
        window: win
        enabled: ShellState.keepAwake
    }

    mask: Region {
        Region { item: workspaces.stripA }
        Region { item: workspaces.zone }
        Region { item: ctrl.stripA }
        Region { item: ctrl.zone }
        Region { item: power.stripA }
        Region { item: power.stripB }
        Region { item: power.zone }
        Region { item: quickActions.stripA }
        Region { item: quickActions.stripB }
        Region { item: quickActions.zone }
        Region { item: notifications.stripA }
        Region { item: notifications.stripB }
        Region { item: notifications.zone }
        Region { item: toasts.zone }
        Region { item: clipboard.stripA }
        Region { item: clipboard.stripB }
        Region { item: clipboard.zone }
        Region { item: dashboard.stripA }
        Region { item: dashboard.zone }
        Region { item: tray.stripA }
        Region { item: tray.zone }
    }

    Workspaces { id: workspaces; m: m; screenName: win.screenName }
    Ctrl { id: ctrl; m: m; screenName: win.screenName }
    Power { id: power; m: m; screenName: win.screenName }
    QuickActions { id: quickActions; m: m; screenName: win.screenName }
    Clipboard { id: clipboard; m: m; screenName: win.screenName }
    Dashboard { id: dashboard; m: m; screenName: win.screenName }
    Tray { id: tray; m: m; screenName: win.screenName }
    RecordingMark { m: m; screenName: win.screenName; trayOpen: tray.isOpen }
    PrivacyMark { m: m; screenName: win.screenName; trayOpen: tray.isOpen }
    NotificationCenter { id: notifications; m: m; screenName: win.screenName }
    Toasts { id: toasts; m: m; screenName: win.screenName; historyOpen: notifications.isOpen }

    Launcher { m: m; screen: win.screen; screenName: win.screenName }
    Switcher { screen: win.screen; screenName: win.screenName }

    TooltipLayer {}
}
