//@ pragma UseQApplication
//@ pragma IconTheme Adwaita

// ~/nikita-shell/dotfiles/quickshell/greeter.qml
//
// The login screen: the lock screen's view, with greetd instead of PAM. greetd
// runs it in a Hyprland of its own (system/greetd), from the copy that
// scripts/install-greeter.sh keeps in /usr/share/nikita-shell.
//
// Preview in a window (your theme and wallpaper; nothing logs in):
//   NIKITA_GREETER_PREVIEW=1 qs -p ~/nikita-shell/dotfiles/quickshell/greeter.qml

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.greeter

ShellRoot {
    GreeterContext {
        id: greeterContext
    }

    Variants {
        model: greeterContext.preview ? [] : Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "nikita-greeter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            GreeterView {
                anchors.fill: parent
                ctx: greeterContext
            }
        }
    }

    LazyLoader {
        active: greeterContext.preview

        FloatingWindow {
            title: "Login screen (preview)"
            implicitWidth: 1280
            implicitHeight: 800
            color: "black"

            GreeterView {
                anchors.fill: parent
                ctx: greeterContext
            }
        }
    }
}
