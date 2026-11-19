// ~/nikita-shell/dotfiles/quickshell/lock/LockView.qml
//
// One monitor of the lock screen, and of the login screen (GreeterView): a card
// over the blurred wallpaper, a hexagon standing like the logo's: the picture (else
// the initial) in its top point, the rocket in the bottom one. Each typed character
// shows as a ShapeMark. Everything else is in the
// card's foot: the battery, `footer`, and sleep, restart and shut down, so nobody is
// stuck here. `ctx` is a LockContext or a GreeterContext.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Io
import qs.common
import qs.services

Item {
    id: view

    required property var ctx
    // A new view each lock, so the password is hidden again.
    property bool revealed: false
    property bool showMedia: true
    property string footer: "Locked since " + clock(ctx.lockedAt) + (Prefs.clock24h ? "" : (ctx.lockedAt.getHours() < 12 ? " AM" : " PM"))
    // More buttons in the card's foot, before the power ones (the login screen's).
    default property alias extras: extraButtons.data
    // The login screen's preview: the power buttons do nothing.
    property bool preview: false

    // ---- power: sleep at once; restart and shut down ask for a second click ----
    property string armed: ""
    property string powerError: ""
    function power(action) {
        if (action !== "suspend" && armed !== action) {
            armed = action;
            disarm.restart();
            return;
        }
        armed = "";
        powerError = "";
        if (preview)
            return;
        // No password prompt: a polkit dialog couldn't show over this screen.
        powerTool.action = action;
        powerTool.command = ["systemctl", "--no-ask-password", action];
        powerTool.running = true;
    }
    Timer {
        id: disarm
        interval: 4000
        onTriggered: view.armed = ""
    }
    // systemctl only writes to stderr when it fails (an inhibitor, another user).
    Process {
        id: powerTool
        property string action: ""
        stderr: StdioCollector {
            onStreamFinished: {
                const why = text.trim().split("\n")[0];
                const what = { suspend: "sleep", reboot: "restart", poweroff: "shut down" }[powerTool.action];
                if (why !== "")
                    view.powerError = "Couldn't " + what + ": " + why;
            }
        }
    }

    property int typed: 0
    // A model rather than a count, so only the new mark bounces in.
    ListModel {
        id: marks
    }
    function syncMarks() {
        const n = Math.min(ctx.buffer.length, 16);
        while (marks.count > n)
            marks.remove(marks.count - 1);
        while (marks.count < n)
            marks.append({ "k": marks.count });
    }
    // ---- coming in and going out ----
    property real shown: 0
    NumberAnimation on shown { id: enter; to: 1; duration: Theme.ms(650); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter }
    NumberAnimation { id: leave; target: view; property: "shown"; to: 0; duration: Theme.ms(260); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExit }
    Connections {
        target: view.ctx
        function onLeavingChanged() {
            if (view.ctx.leaving) {
                enter.stop();
                leave.start();
            }
        }
        function onFailed() {
            shake.restart();
            ripple.go(true);
        }
        function onBufferChanged() {
            if (input.text !== view.ctx.buffer)
                input.text = view.ctx.buffer;
            if (view.ctx.buffer.length > view.typed)
                ripple.go(false);
            view.typed = view.ctx.buffer.length;
            view.syncMarks();
        }
    }

    Component.onCompleted: {
        input.forceActiveFocus();
        KeyboardState.refresh();
    }
    // Caps Lock, asked a moment after typing stops.
    Timer {
        id: capsCheck
        interval: 250
        onTriggered: KeyboardState.refresh()
    }

    // ---- time ----
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: view.now = new Date()
    }
    function clock(t) {
        return Prefs.clock24h ? Qt.formatTime(t, "HH:mm") : Qt.formatTime(t, "h:mm");
    }
    readonly property string greeting: {
        const h = now.getHours();
        return h >= 5 && h < 12 ? "Good morning" : h >= 12 && h < 19 ? "Good afternoon" : "Good evening";
    }

    // ---- the background ----
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }
    Image {
        id: wall
        anchors.fill: parent
        visible: false
        source: "file://" + Paths.wallpaper
        sourceSize: Qt.size(view.width, view.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: Theme.dark ? -0.12 : 0.06
        scale: 1.06 - 0.06 * Math.min(1, view.shown)
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.30)
    }

    // A click anywhere gives the password field the keyboard back.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            view.armed = "";
            input.forceActiveFocus();
        }
    }

    // ---- the card ----
    Item {
        id: card

        // The content's width. It sits between the two points, where the card is widest.
        readonly property int inner: Math.round(Math.min(Math.max(view.width * 0.18, 340), 400))
        readonly property int point: Math.round(inner * 0.33)
        readonly property real round: 0.08
        // Read over any wallpaper: barely see-through, whatever the panels are. Lit
        // from above: a shade lighter at the top, toward white in the light theme.
        readonly property real fillOpacity: Math.max(Prefs.panelOpacity, 0.94)
        readonly property color fillTop: Theme.alpha(Theme.dark ? Theme.mix(Theme.bg, Theme.fg, 0.09) : Theme.mix(Theme.bg, Qt.rgba(1, 1, 1, 1), 0.7), fillOpacity)
        readonly property color fillBottom: Theme.alpha(Theme.dark ? Theme.bg : Theme.mix(Theme.bg, Theme.fg, 0.03), fillOpacity)

        width: Math.max(inner + 72, Math.round(height * Theme.hexRatio))
        height: content.y + content.height + point + 6
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - view.shown) * 34
        opacity: Math.min(1, view.shown)
        scale: 0.95 + 0.05 * view.shown

        Behavior on height { NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSmooth } }

        // Two faint echoes of the outline, for depth. The card's own edge is Theme.rim.
        Repeater {
            model: [{ s: 1.045, a: 0.14 }, { s: 1.09, a: 0.06 }]
            HexShape {
                required property var modelData
                anchors.fill: parent
                scale: modelData.s
                point: card.point
                round: card.round
                fill: "transparent"
                stroke: Theme.alpha(Theme.fg, modelData.a)
                strokeWidth: 1
            }
        }

        // A soft shadow, so the card lifts off a light or busy wallpaper.
        HexShape {
            id: shadowShape
            anchors.fill: parent
            visible: false
            layer.enabled: true
            point: card.point
            round: card.round
            fill: "black"
        }
        MultiEffect {
            anchors.fill: parent
            anchors.topMargin: 14
            anchors.bottomMargin: -14
            source: shadowShape
            autoPaddingEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 48
            opacity: Theme.dark ? 0.5 : 0.28
        }

        HexShape {
            anchors.fill: parent
            point: card.point
            round: card.round
            gradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: card.height
                GradientStop { position: 0; color: card.fillTop }
                GradientStop { position: 1; color: card.fillBottom }
            }
            stroke: Theme.rim
            strokeWidth: 1.5
        }

        // A ripple of the outline: each key, the check (again and again), a wrong
        // password (red). Only on those: a locked screen left alone draws nothing.
        HexShape {
            id: ripple

            property bool bad: false
            function go(bad) {
                ripple.bad = bad;
                rippleRun.restart();
            }

            anchors.fill: parent
            point: card.point
            round: card.round
            fill: "transparent"
            stroke: bad ? Theme.bad : Theme.fg
            strokeWidth: 1.5
            opacity: 0

            ParallelAnimation {
                id: rippleRun
                NumberAnimation { target: ripple; property: "scale"; from: 1; to: 1.1; duration: Theme.ms(700); easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; from: ripple.bad ? 0.6 : 0.3; to: 0; duration: Theme.ms(700); easing.type: Easing.OutCubic }
            }
            Timer {
                running: view.ctx.state === "checking"
                interval: 900
                repeat: true
                triggeredOnStart: true
                onTriggered: ripple.go(false)
            }
        }

        Logo {
            mark: "rocket"
            size: 46
            color: Theme.dim
            x: (card.width - width) / 2
            y: card.height - card.point + 26
        }

        Avatar {
            id: avatar
            width: Math.round(height * Theme.hexRatio)
            height: 118
            x: (card.width - width) / 2
            y: 30 - (1 - Math.min(1, view.shown)) * 14
            path: Paths.face(view.ctx.user)
            name: view.ctx.user
        }

        Column {
            id: content
            x: (card.width - width) / 2
            y: avatar.y + avatar.height + 12
            width: card.inner
            spacing: 0

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: view.greeting + ", " + view.ctx.name
                font.pixelSize: Theme.textTitle
                color: Theme.muted
            }

            Item { width: 1; height: 16 }
            BigClock {
                anchors.horizontalCenter: parent.horizontalCenter
                date: view.now
                size: 104
            }
            Item { width: 1; height: 14 }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(view.now, "dddd  •  d MMMM").toUpperCase()
                font.pixelSize: Theme.textLabel
                font.weight: Font.DemiBold
                font.letterSpacing: 2
                color: Theme.muted
            }

            Item { width: 1; height: 26 }

            // -- the password --
            Rectangle {
                id: field

                readonly property bool wrong: ["fail", "max", "error"].includes(view.ctx.state)
                readonly property bool checking: view.ctx.state === "checking"
                property real shakeX: 0

                x: shakeX
                width: parent.width
                height: 50
                radius: height / 2
                color: Theme.card
                border.width: 1.5
                border.color: wrong ? Theme.bad : KeyboardState.capsLock ? Theme.warn : input.activeFocus ? Theme.alpha(Theme.fg, 0.22) : Theme.alpha(Theme.fg, 0.08)
                Behavior on border.color { ColorAnimation { duration: Theme.msNormal } }

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: field; property: "shakeX"; to: -14; duration: Theme.ms(60) }
                    NumberAnimation { target: field; property: "shakeX"; to: 11; duration: Theme.ms(70) }
                    NumberAnimation { target: field; property: "shakeX"; to: -7; duration: Theme.ms(70) }
                    NumberAnimation { target: field; property: "shakeX"; to: 3; duration: Theme.ms(60) }
                    NumberAnimation { target: field; property: "shakeX"; to: 0; duration: Theme.ms(60) }
                }

                // Invisible: the marks draw it.
                TextInput {
                    id: input
                    width: 1
                    height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    readOnly: field.checking || view.ctx.leaving
                    onTextChanged: if (text !== view.ctx.buffer) view.ctx.type(text)
                    onAccepted: view.ctx.submit()
                    Keys.onPressed: ev => {
                        capsCheck.restart();
                        view.armed = "";
                        view.powerError = "";
                        if (ev.key === Qt.Key_Escape) {
                            input.text = "";
                            ev.accepted = true;
                        }
                    }
                }

                Icon {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    name: "system-lock-screen-symbolic"
                    size: 16
                    color: field.wrong ? Theme.bad : Theme.dim
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: view.ctx.buffer === "" && !field.checking
                    text: "Password"
                    color: Theme.dim
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 44
                    anchors.rightMargin: 88
                    clip: true

                    StyledText {
                        visible: view.revealed
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: view.ctx.buffer
                        elide: Text.ElideLeft
                        font.pixelSize: Theme.textTitle
                    }

                    Row {
                        visible: !view.revealed
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round((parent.width - width) / 2)
                        Behavior on x { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
                        spacing: Theme.spaceS
                        SequentialAnimation on opacity {
                            running: field.checking
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.35; duration: 380; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 380; easing.type: Easing.InOutSine }
                        }
                        Repeater {
                            model: marks
                            Item {
                                id: markCell
                                required property int index
                                width: 14
                                height: 14
                                ShapeMark {
                                    id: shapeMark
                                    anchors.centerIn: parent
                                    color: Theme.fg
                                    stroke: 2
                                    scale: 0
                                    rotation: -110
                                }
                                ParallelAnimation {
                                    running: true
                                    NumberAnimation { target: shapeMark; property: "scale"; to: 1; duration: Theme.ms(440); easing.type: Easing.OutBack; easing.overshoot: 3 }
                                    NumberAnimation { target: shapeMark; property: "rotation"; to: 0; duration: Theme.ms(440); easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                                }
                            }
                        }
                    }
                }

                PillButton {
                    anchors.right: submit.left
                    anchors.rightMargin: Theme.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    flat: true
                    icon: view.revealed ? "view-conceal-symbolic" : "view-reveal-symbolic"
                    iconSize: 14
                    tip: view.revealed ? "Hide the password" : "Show the password"
                    onClicked: {
                        view.revealed = !view.revealed;
                        input.forceActiveFocus();
                    }
                }
                PillButton {
                    id: submit
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    icon: "go-next-symbolic"
                    active: view.ctx.buffer !== "" && !field.checking
                    interactive: view.ctx.buffer !== "" && !field.checking
                    onClicked: view.ctx.submit()
                }
            }

            // Always takes its line, so nothing jumps when a message comes.
            StyledText {
                readonly property string layout: KeyboardState.layouts.length > 1 ? (KeyboardState.layouts[KeyboardState.layoutIndex] || "").toUpperCase() + " keyboard" : ""
                width: parent.width
                height: 34
                horizontalAlignment: Text.AlignHCenter
                text: view.ctx.state === "checking" ? "Checking…"
                    : view.armed === "reboot" ? "Click again to restart"
                    : view.armed === "poweroff" ? "Click again to shut down"
                    : view.ctx.message !== "" ? view.ctx.message
                    : view.powerError !== "" ? view.powerError
                    : view.ctx.state === "fail" ? "Wrong password"
                    : view.ctx.state === "max" ? "Too many tries. Wait a moment."
                    : view.ctx.state === "error" ? "Couldn't check the password"
                    : KeyboardState.capsLock ? "Caps Lock is on"
                    : layout
                elide: Text.ElideRight
                color: field.wrong || view.armed !== "" || view.ctx.message !== "" || view.powerError !== "" ? Theme.bad : KeyboardState.capsLock && view.ctx.state === "" ? Theme.warn : Theme.dim
                font.pixelSize: Theme.textLabel
            }

            // A Loader, so the login screen never starts the media service.
            Item { visible: media.active; width: 1; height: 18 }
            Loader {
                id: media
                active: view.showMedia && Media.hasTrack
                visible: active
                width: parent.width
                height: 64
                sourceComponent: NowPlaying {
                    compact: true
                    radius: Theme.radiusL
                }
            }

            // -- the foot: the battery and `footer` left, the buttons right --
            Item { width: 1; height: 8 }
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.divider
            }
            Item {
                id: foot
                width: parent.width
                height: 52

                Row {
                    id: battery
                    visible: Battery.present
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceXs
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Battery.icon
                        size: 15
                        color: Battery.level
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Battery.pct + " %"
                        color: Battery.level
                        font.pixelSize: Theme.textLabel
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    anchors.fill: battery
                    visible: battery.visible
                    hoverEnabled: true
                    Tip {
                        text: Battery.detail
                    }
                }
                StyledText {
                    id: dot
                    visible: battery.visible && view.footer !== ""
                    anchors.left: battery.right
                    anchors.leftMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    color: Theme.dim
                }
                // Anchored, not in a Row: its width depends on where it starts.
                StyledText {
                    anchors.left: dot.visible ? dot.right : parent.left
                    anchors.leftMargin: dot.visible ? 7 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.min(implicitWidth, extraButtons.x - x - 12))
                    elide: Text.ElideRight
                    text: view.footer
                    color: Theme.muted
                    font.pixelSize: Theme.textLabel
                }

                Row {
                    id: extraButtons
                    anchors.right: buttons.left
                    anchors.rightMargin: width > 0 ? 4 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceXs
                }
                Row {
                    id: buttons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceXs

                    Repeater {
                        model: [
                            { action: "suspend", icon: "weather-clear-night-symbolic", tip: "Sleep" },
                            { action: "reboot", icon: "system-reboot-symbolic", tip: "Restart" },
                            { action: "poweroff", icon: "system-shutdown-symbolic", tip: "Shut down" }
                        ]
                        PillButton {
                            required property var modelData

                            implicitHeight: 34
                            flat: true
                            icon: modelData.icon
                            tip: modelData.tip
                            danger: modelData.action !== "suspend"
                            // Armed: red until the second click (the line above says so).
                            restColor: view.armed === modelData.action ? Theme.bad : "transparent"
                            onClicked: view.power(modelData.action)
                        }
                    }
                }
            }
        }
    }

    TooltipLayer {}
}
