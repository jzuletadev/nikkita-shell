// ~/nikkita-shell/dotfiles/quickshell/surfaces/Toasts.qml

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.common
import qs.services

EdgePanel {
    id: toasts

    name: "toasts"
    edge: "right"
    placement: "start"
    touchable: false
    depth: m.corner
    span: Math.max(60, stack.implicitHeight + 2 * inset)
    inset: 12
    property bool historyOpen: false
    // Only on the focused monitor.
    readonly property bool here: ShellState.focusedScreen() === screenName
    pinned: here && Notifs.toasts.length > 0 && !historyOpen

    Behavior on span {
        NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth }
    }

    Column {
        id: stack
        width: parent.width
        spacing: Theme.spaceS

        Repeater {
            // ScriptModel keeps existing cards, so a new toast doesn't restart the others.
            model: ScriptModel {
                values: Notifs.toasts.slice(0, 4)
            }

            Card {
                required property var modelData
                n: modelData
                width: stack.width
                paused: toasts.hovering
            }
        }
    }

    component Card: Rectangle {
        id: t

        property var n
        property bool paused: false
        readonly property bool critical: n && n.urgency === NotificationUrgency.Critical
        // The app's timeout, or 6 s; critical ones never time out.
        readonly property int lifetime: critical ? 0 : (n && n.expireTimeout > 0 ? n.expireTimeout : 6000)
        property real remaining: 1

        implicitHeight: content.implicitHeight + 24
        radius: Theme.radiusM
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: Theme.msNormal } }
        color: zone.containsMouse ? Theme.cardHover : Theme.card
        border.width: critical ? 1 : 0
        border.color: Theme.bad
        Behavior on color { ColorAnimation { duration: Theme.msFast } }

        NumberAnimation on remaining {
            id: countdown
            running: t.lifetime > 0
            paused: t.paused && running
            from: 1
            to: 0
            duration: t.lifetime
            onFinished: Notifs.expire(t.n)
        }

        MouseArea {
            id: zone
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            // The default action, else the only one (screenshots' "Annotate"), else dismiss.
            onClicked: ev => {
                if (ev.button === Qt.LeftButton) {
                    const acc = t.n.actions;
                    const def = acc.find(a => a.identifier === "default") ?? (acc.length === 1 ? acc[0] : null);
                    if (def) {
                        // Invoking can destroy this toast, `t` with it.
                        const n = t.n;
                        def.invoke();
                        Notifs.removeToast(n);
                        return;
                    }
                }
                Notifs.dismiss(t.n);
            }
        }

        Row {
            id: content
            x: 12
            y: 12
            width: parent.width - 24
            spacing: Theme.spaceM

            Image {
                id: image
                visible: t.n && t.n.image !== ""
                width: visible ? 44 : 0
                height: 44
                source: t.n ? t.n.image : ""
                sourceSize.width: 88
                sourceSize.height: 88
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Column {
                width: parent.width - (image.visible ? image.width + parent.spacing : 0)
                spacing: Theme.spaceXs

                Row {
                    width: parent.width
                    spacing: Theme.spaceS
                    AppIcon {
                        name: t.n ? t.n.appIcon : ""
                        size: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        width: parent.width - 14 - 20 - 2 * parent.spacing
                        text: t.n ? (t.n.appName || "Notification") : ""
                        color: t.critical ? Theme.bad : Theme.muted
                        font.pixelSize: Theme.textSmall
                        font.weight: Font.Medium
                    }
                    PillButton {
                        width: 20
                        height: 20
                        flat: true
                        icon: "window-close-symbolic"
                        iconSize: 11
                        onClicked: Notifs.dismiss(t.n)
                    }
                }
                StyledText {
                    width: parent.width
                    text: t.n ? t.n.summary : ""
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: t.n ? t.n.body : ""
                    textFormat: Text.StyledText
                    color: Theme.muted
                    font.pixelSize: Theme.textLabel
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    onLinkActivated: url => Qt.openUrlExternally(url)
                }
                Flow {
                    width: parent.width
                    spacing: Theme.spaceS
                    visible: actions.count > 0
                    topPadding: Theme.spaceXs
                    Repeater {
                        id: actions
                        model: t.n ? t.n.actions.filter(a => a.identifier !== "default") : []
                        PillButton {
                            required property var modelData
                            text: modelData.text
                            height: 28
                            restColor: Theme.cardHover
                            onClicked: {
                                const n = t.n;   // invoking can destroy this toast
                                modelData.invoke();
                                Notifs.removeToast(n);
                            }
                        }
                    }
                }
            }
        }

        // Time left.
        Rectangle {
            visible: t.lifetime > 0
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: Theme.spaceXs
            anchors.leftMargin: Theme.spaceL
            height: 2
            radius: height / 2
            width: (parent.width - 28) * t.remaining
            color: Theme.alpha(Theme.accent, 0.5)
        }
    }
}
