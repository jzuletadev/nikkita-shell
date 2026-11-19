// ~/nikita-shell/dotfiles/quickshell/surfaces/Toasts.qml

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
    span: Math.max(60, stack.implicitHeight - Theme.spaceS + 2 * inset)
    inset: 12
    property bool historyOpen: false
    // Only on the focused monitor.
    readonly property bool here: ShellState.focusedScreen() === screenName
    pinned: here && cards.length > 0 && !historyOpen

    // The cards on screen: a notification's stays until it has finished leaving.
    readonly property var current: Notifs.toasts.slice(0, 4)
    property var cards: []
    onCurrentChanged: {
        const fresh = current.filter(n => !cards.some(c => c.key === n.id)).map(n => ({ key: n.id }));
        if (fresh.length > 0)
            cards = fresh.concat(cards);
    }
    function drop(card) {
        cards = cards.filter(c => c !== card);
    }

    // Each card opens and closes its own slot, so the others simply follow.
    Column {
        id: stack
        width: parent.width

        Repeater {
            // ScriptModel keeps existing cards, so a new toast doesn't restart the others.
            model: ScriptModel {
                values: toasts.cards
            }

            Item {
                id: slot
                required property var modelData
                width: stack.width
                height: (card.height + Theme.spaceS) * card.reveal
                clip: true

                Card {
                    id: card
                    entry: slot.modelData
                    width: parent.width
                    paused: toasts.hovering
                }
            }
        }
    }

    component Card: Rectangle {
        id: t

        required property var entry
        // The live notification; null once it is gone.
        readonly property var n: toasts.current.find(x => x.id === entry.key) ?? null
        property bool paused: false
        readonly property bool critical: n && n.urgency === NotificationUrgency.Critical
        // The app's timeout, or 6 s; critical ones never time out.
        readonly property int lifetime: critical ? 0 : notice ? 2600 : (n && n.expireTimeout > 0 ? n.expireTimeout : 6000)
        property real remaining: 1

        // What it shows stays while it leaves: by then the notification is gone.
        property string appName: ""
        property string summary: ""
        property string body: ""
        property string image: ""
        property string appIcon: ""
        property bool notice: false
        Binding on appName { when: !!t.n; value: t.n ? t.n.appName || "Notification" : ""; restoreMode: Binding.RestoreNone }
        Binding on summary { when: !!t.n; value: t.n ? t.n.summary : ""; restoreMode: Binding.RestoreNone }
        Binding on body { when: !!t.n; value: t.n ? t.n.body : ""; restoreMode: Binding.RestoreNone }
        Binding on image { when: !!t.n; value: t.n ? t.n.image : ""; restoreMode: Binding.RestoreNone }
        Binding on appIcon { when: !!t.n; value: t.n ? t.n.appIcon : ""; restoreMode: Binding.RestoreNone }
        Binding on notice { when: !!t.n; value: Notifs.isNotice(t.n); restoreMode: Binding.RestoreNone }
        readonly property real fitted: content.implicitHeight + 24
        property real kept: 0
        onFittedChanged: if (n) kept = fitted
        height: n ? fitted : kept

        // Arriving: its slot opens as it slides in. Leaving: it slides out, then the
        // slot closes.
        readonly property bool going: n === null
        property real reveal: 0
        property real away: 0
        x: 48 * (1 - reveal + away)
        opacity: reveal * (1 - away)
        NumberAnimation {
            id: arrive
            target: t
            property: "reveal"
            to: 1
            duration: Theme.msNormal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveSmooth
        }
        SequentialAnimation {
            id: leave
            NumberAnimation { target: t; property: "away"; to: 1; duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExit }
            NumberAnimation { target: t; property: "reveal"; to: 0; duration: Theme.msFast; easing.type: Easing.OutCubic }
            ScriptAction { script: toasts.drop(t.entry) }
        }
        Component.onCompleted: arrive.start()
        onGoingChanged: {
            if (going) {
                arrive.stop();
                leave.start();
            } else {
                leave.stop();
                away = 0;
                arrive.start();
            }
        }
        radius: Theme.radiusM
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
            enabled: !!t.n
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

            // A desktop notice: its symbolic icon, in the theme's color.
            HexShape {
                id: noticeMark
                visible: t.notice
                height: 36
                width: Math.round(height * Theme.hexRatio)
                fill: Theme.cardHover
                anchors.verticalCenter: parent.verticalCenter
                Icon {
                    anchors.centerIn: parent
                    name: t.image.replace("image://icon/", "")
                    size: 16
                }
            }

            // A picture, or a theme icon by name (which may not exist: Qt would paint
            // its magenta checkerboard).
            Item {
                id: image
                readonly property string source: t.notice ? "" : t.image
                readonly property bool isIcon: source.startsWith("image://icon/")
                visible: source !== ""
                width: visible ? 44 : 0
                height: 44

                Image {
                    anchors.fill: parent
                    visible: !image.isIcon
                    source: image.isIcon ? "" : image.source
                    sourceSize.width: 88
                    sourceSize.height: 88
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                AppIcon {
                    anchors.centerIn: parent
                    visible: image.isIcon
                    name: image.isIcon ? image.source : ""
                    initial: t.appName || t.summary
                    size: 44
                }
            }

            Column {
                width: parent.width - (t.notice ? noticeMark.width + parent.spacing : image.visible ? image.width + parent.spacing : 0)
                spacing: t.notice ? Theme.spaceXxs : Theme.spaceXs
                anchors.verticalCenter: t.notice ? parent.verticalCenter : undefined

                Row {
                    visible: !t.notice
                    width: parent.width
                    spacing: Theme.spaceS
                    // Only a real one, and not the one already shown big.
                    AppIcon {
                        id: appMark
                        name: t.appIcon
                        size: 14
                        visible: found !== "" && "image://icon/" + name !== image.source
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        width: parent.width - (appMark.visible ? 14 + parent.spacing : 0) - 20 - parent.spacing
                        text: t.appName
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
                    text: t.summary
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: t.body
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
            visible: t.lifetime > 0 && !t.notice
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
