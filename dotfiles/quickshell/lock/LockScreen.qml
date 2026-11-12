// ~/nikkita-shell/dotfiles/quickshell/lock/LockScreen.qml
//
// The lock screen (Wayland session lock): one LockView per monitor, sharing one
// LockContext. If Quickshell dies while locked the session STAYS locked, and
// hyprlock can take over (allow_session_lock_restore in hyprland.lua).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Scope {
    id: root

    // Not `ctx`: inside LockView that name is its own property, and `ctx: ctx`
    // would bind it to itself.
    LockContext {
        id: lockContext
        onUnlocked: release.start()
    }

    Timer {
        id: release
        interval: 280
        onTriggered: sessionLock.locked = false
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            color: "black"

            LockView {
                anchors.fill: parent
                ctx: lockContext
            }
        }
    }

    // `secure` announces itself with secureStateChanged, so a Binding rather than
    // an on…Changed handler.
    Binding {
        target: ShellState
        property: "lockSecure"
        value: sessionLock.secure
    }

    Connections {
        target: ShellState
        function onLockRequested() {
            if (sessionLock.locked)
                return;
            lockContext.reset();
            sessionLock.locked = true;
        }
    }
}
