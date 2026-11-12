// ~/nikkita-shell/dotfiles/quickshell/surfaces/AuthDialog.qml

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.common
import qs.services

Scope {
    id: auth

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    readonly property bool asking: agent.isActive && flow !== null
    onAskingChanged: ShellState.authAsking = asking
    property bool checking: false
    property string error: ""

    onFlowChanged: {
        checking = false;
        error = "";
    }

    Connections {
        target: auth.flow
        function onIsResponseRequiredChanged() {
            if (auth.flow && auth.flow.isResponseRequired) {
                auth.checking = false;
                field.text = "";
                field.input.forceActiveFocus();
            }
        }
        function onAuthenticationFailed() {
            auth.checking = false;
            auth.error = "Wrong password";
            shake.restart();
        }
    }

    function submit() {
        if (!flow || checking || field.text === "")
            return;
        checking = true;
        error = "";
        flow.submit(field.text);
    }
    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    PanelWindow {
        id: dialog

        visible: auth.asking
        screen: Quickshell.screens.find(s => s.name === ShellState.focusedScreen()) ?? Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nikkita-auth"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        property real shown: 0
        onVisibleChanged: {
            if (visible) {
                shown = 0;
                enter.restart();
                field.text = "";
                field.revealed = false;
                field.input.forceActiveFocus();
            }
        }
        NumberAnimation { id: enter; target: dialog; property: "shown"; to: 1; duration: Theme.msSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.dark ? "black" : Theme.bg, 0.55)
            // A click outside doesn't close a password prompt.
            MouseArea { anchors.fill: parent }
        }

        Rectangle {
            id: card
            readonly property int pad: 28
            width: 440
            height: content.height + 2 * pad
            anchors.centerIn: parent
            anchors.verticalCenterOffset: (1 - dialog.shown) * 24
            radius: Theme.radiusXl
            color: Theme.mix(Theme.bg, Theme.fg, 0.05)
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.08)
            opacity: Math.min(1, dialog.shown)
            scale: 0.95 + 0.05 * dialog.shown

            Column {
                id: content
                x: card.pad
                y: card.pad
                width: card.width - 2 * card.pad
                spacing: 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56
                    height: 56
                    radius: width / 2
                    color: Theme.overlay
                    Icon {
                        anchors.centerIn: parent
                        name: "system-lock-screen-symbolic"
                        size: 24
                    }
                }
                Item { width: 1; height: 16 }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Authentication required"
                    font.pixelSize: Theme.textHeading
                    font.weight: Font.DemiBold
                }
                Item { width: 1; height: 8 }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: auth.flow ? auth.flow.message : ""
                    color: Theme.muted
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
                Item { width: 1; height: 22 }

                InputField {
                    id: field
                    property real shakeX: 0
                    x: shakeX
                    width: parent.width
                    height: 46
                    icon: "dialog-password-symbolic"
                    placeholder: "Password for " + (auth.flow && auth.flow.selectedIdentity && auth.flow.selectedIdentity.displayName ? auth.flow.selectedIdentity.displayName : (Quickshell.env("USER") || "you"))
                    secret: !(auth.flow && auth.flow.responseVisible)
                    border.width: auth.error !== "" ? 1.5 : input.activeFocus ? 1 : 0
                    border.color: auth.error !== "" ? Theme.bad : Theme.accent
                    onSubmitted: auth.submit()
                    onSpecialKey: ev => {
                        if (ev.key === Qt.Key_Escape) {
                            auth.cancel();
                            ev.accepted = true;
                        }
                    }
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: field; property: "shakeX"; to: -12; duration: 60 }
                        NumberAnimation { target: field; property: "shakeX"; to: 9; duration: 70 }
                        NumberAnimation { target: field; property: "shakeX"; to: -5; duration: 70 }
                        NumberAnimation { target: field; property: "shakeX"; to: 0; duration: 60 }
                    }
                }
                Binding {
                    target: field.input
                    property: "readOnly"
                    value: auth.checking
                }

                // PAM's own note if it is an error (account locked...), or ours.
                StyledText {
                    width: parent.width
                    height: 30
                    horizontalAlignment: Text.AlignHCenter
                    text: auth.flow && auth.flow.supplementaryIsError && auth.flow.supplementaryMessage !== "" ? auth.flow.supplementaryMessage : auth.error
                    color: Theme.bad
                    font.pixelSize: Theme.textLabel
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.spaceS
                    PillButton {
                        height: 38
                        text: "Cancel"
                        flat: true
                        onClicked: auth.cancel()
                    }
                    PillButton {
                        height: 38
                        width: 150
                        text: auth.checking ? "Checking…" : "Authenticate"
                        active: true
                        busy: auth.checking
                        interactive: field.text !== ""
                        onClicked: auth.submit()
                    }
                }
            }
        }
    }
}
