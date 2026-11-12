// ~/nikkita-shell/dotfiles/quickshell/surfaces/Performance.qml

import QtQuick
import qs.common
import qs.services

Item {
    id: perf

    readonly property var d: SystemStats.latest
    readonly property var m: SystemStats.machine
    readonly property int gap: 10

    Component.onCompleted: if (!SystemStats.machine) SystemStats.loadMachine()

    function tone(v, warnAt, badAt) {
        return v >= badAt ? Theme.bad : v >= warnAt ? Theme.warn : Theme.accent;
    }

    // Case fans. One labelled for the GPU ("Video Fan" on Dell laptops) goes on the
    // GPU card, the rest on the CPU's.
    readonly property var fans: d ? d.fans : []
    readonly property var gpuFans: fans.filter(f => /gpu|video|graphic/i.test(f.name))
    readonly property var cpuFans: fans.filter(f => gpuFans.indexOf(f) < 0)

    // -1: a dedicated GPU while awake, else the first. A click on the title cycles.
    property int gpuIndex: -1
    readonly property var gpus: d && d.gpus ? d.gpus : []
    readonly property int autoGpu: Math.max(0, gpus.findIndex(g => g.kind === "dedicated" && g.awake))
    readonly property int shownGpu: gpus.length === 0 ? -1 : Math.min(gpuIndex < 0 ? autoGpu : gpuIndex, gpus.length - 1)
    readonly property var gpu: shownGpu >= 0 ? gpus[shownGpu] : null

    // ---- the CPU and GPU cards ----
    component UsageCard: Rectangle {
        id: card

        property int glyph: 0
        property string title: ""
        property string subtitle: ""
        property real usage: -1              // < 0: not reported
        property var temp: null              // °C or null
        property var freq: null              // [MHz now, MHz top], shown when there is no temperature
        property string note: ""             // instead of both (asleep, no sensor)
        property var fan: null               // { rpm } or { percent }
        property bool cycles: false          // the title switches between GPUs
        signal titleClicked

        radius: Theme.radiusL
        color: Theme.card

        Rectangle {
            id: bubble
            x: 14
            y: 14
            width: 34
            height: 34
            radius: width / 2
            color: Theme.overlay
            Glyph {
                anchors.centerIn: parent
                code: card.glyph
                size: 17
            }
        }
        Column {
            anchors.left: bubble.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: badge.left
            anchors.rightMargin: Theme.spaceS
            anchors.verticalCenter: bubble.verticalCenter
            spacing: Theme.spaceXxs
            StyledText {
                width: parent.width
                text: card.title + (card.cycles ? "  ›" : "")
                font.weight: Font.DemiBold
                font.pixelSize: Theme.textLarge
                MouseArea {
                    anchors.fill: parent
                    enabled: card.cycles
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.titleClicked()
                }
            }
            StyledText {
                width: parent.width
                text: card.subtitle
                color: Theme.muted
                font.pixelSize: Theme.textSmall
            }
        }

        Row {
            id: reading
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceL
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spaceL
            spacing: Theme.spaceS
            // The temperature; without one, the clock (now of top); else a note.
            readonly property bool hot: card.temp !== null && card.note === ""
            readonly property bool clock: !hot && card.freq !== null && card.note === ""
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                code: parent.clock ? 0xF140B : 0xF050F
                size: 14
                color: parent.hot ? perf.tone(card.temp, 80, 90) : parent.clock ? Theme.fg : Theme.dim
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.hot ? Math.round(card.temp) + "°C" : parent.clock ? card.freq[0] + " MHz" : (card.note || "no sensor")
                color: parent.hot || parent.clock ? Theme.fg : Theme.dim
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textLabel
            }
            Rectangle {
                visible: parent.hot || parent.clock
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(40, card.width - badge.width - (card.fan !== null ? 200 : 130))
                height: 5
                radius: height / 2
                color: Theme.alpha(Theme.fg, 0.1)
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: parent.width * Math.min(1, Math.max(0, reading.hot ? (card.temp || 0) / 100 : card.freq ? card.freq[0] / card.freq[1] : 0))
                    color: reading.hot ? perf.tone(card.temp || 0, 80, 90) : Theme.fg
                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                }
            }
            Glyph {
                visible: card.fan !== null
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Theme.spaceXs
                code: 0xF0210
                size: 16
                color: Theme.fg
                // A turn takes 0.3 s at 5000 rpm, 1.5 s at 1000.
                readonly property real speed: !card.fan ? 0 : card.fan.rpm !== undefined ? card.fan.rpm : (card.fan.percent || 0) * 50
                FrameAnimation {
                    running: parent.speed > 0 && card.visible
                    onTriggered: parent.rotation = (parent.rotation + frameTime * parent.speed * 0.24) % 360
                }
            }
            StyledText {
                visible: card.fan !== null
                anchors.verticalCenter: parent.verticalCenter
                text: !card.fan ? "" : card.fan.rpm !== undefined ? (card.fan.rpm > 0 ? card.fan.rpm + " rpm" : "stopped") : card.fan.percent + " %"
                color: Theme.fg
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textLabel
            }
        }

        Column {
            id: badge
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXxs
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Usage"
                color: Theme.muted
                font.pixelSize: Theme.textCaption
            }
            Cookie {
                value: card.usage
                size: Math.min(80, card.height - 34)
            }
        }
    }

    // ---- the gauge cards: storage and memory ----
    component GaugeCard: Rectangle {
        id: gcard

        property int glyph: 0
        property string title: ""
        property real value: 0
        property string line1: ""
        property string line2: ""

        radius: Theme.radiusL
        color: Theme.card

        Gauge {
            id: g
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            size: Math.min(84, gcard.height - 28)
            value: gcard.value
            caption: "used"
        }
        Column {
            anchors.left: g.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs
            Row {
                spacing: Theme.spaceS
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    code: gcard.glyph
                    size: 14
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: gcard.title
                    font.weight: Font.DemiBold
                }
            }
            StyledText {
                width: parent.width
                text: gcard.line1
                font.pixelSize: Theme.textLabel
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                text: gcard.line2
                color: Theme.muted
                font.pixelSize: Theme.textSmall
            }
        }
    }

    // ================================================================= layout
    readonly property real sideWidth: 150
    readonly property real leftWidth: width - sideWidth - gap
    readonly property real topHeight: Math.round((height - gap) * 0.47)
    readonly property real bottomHeight: height - topHeight - gap

    UsageCard {
        x: 0
        y: 0
        width: (perf.leftWidth - perf.gap) / 2
        height: perf.topHeight
        glyph: 0xF0EE0
        title: "CPU"
        subtitle: perf.m ? SystemStats.shortCpu(perf.m.cpu) : ""
        usage: perf.d ? perf.d.cpu : -1
        temp: perf.d && perf.d.cpuTemp !== null ? perf.d.cpuTemp : null
        fan: perf.cpuFans.length > 0 ? perf.cpuFans[0] : null
    }

    UsageCard {
        x: (perf.leftWidth + perf.gap) / 2
        y: 0
        width: (perf.leftWidth - perf.gap) / 2
        height: perf.topHeight
        glyph: 0xF08AE
        title: perf.gpus.length > 1 ? "GPU " + (perf.shownGpu + 1) + "/" + perf.gpus.length : "GPU"
        cycles: perf.gpus.length > 1
        onTitleClicked: perf.gpuIndex = (perf.shownGpu + 1) % perf.gpus.length
        subtitle: !perf.gpu ? "No GPU found" : [perf.gpu.name, perf.gpu.kind === "dedicated" ? "dedicated" : "integrated",
            perf.gpu.vram ? SystemStats.bytes(perf.gpu.vram[0]) + " / " + SystemStats.bytes(perf.gpu.vram[1]) : ""].filter(x => x).join(" · ")
        usage: perf.gpu && perf.gpu.awake && perf.gpu.usage !== null ? perf.gpu.usage : -1
        temp: perf.gpu && perf.gpu.awake && perf.gpu.temp !== null ? perf.gpu.temp : null
        freq: perf.gpu && perf.gpu.awake ? (perf.gpu.freq || null) : null
        // A hybrid laptop's dedicated GPU, unused.
        note: !perf.gpu ? "" : !perf.gpu.awake ? "asleep, saving power" : ""
        fan: perf.gpu && perf.gpu.awake && perf.gpu.fan ? perf.gpu.fan : perf.gpuFans.length > 0 ? perf.gpuFans[0] : null
    }

    GaugeCard {
        x: 0
        y: perf.topHeight + perf.gap
        width: (perf.leftWidth - 2 * perf.gap) * 0.33
        height: perf.bottomHeight
        glyph: 0xF02CA
        title: "Storage"
        value: SystemStats.disk ? 100 * SystemStats.disk.used / SystemStats.disk.total : 0
        line1: SystemStats.disk ? SystemStats.pair(SystemStats.disk.used, SystemStats.disk.total) : "…"
        line2: "system disk (/)"
    }

    // ---- network: the last minute, drawn ----
    Rectangle {
        id: netCard
        x: (perf.leftWidth - 2 * perf.gap) * 0.33 + perf.gap
        y: perf.topHeight + perf.gap
        width: (perf.leftWidth - 2 * perf.gap) * 0.34
        height: perf.bottomHeight
        radius: Theme.radiusL
        color: Theme.card

        readonly property real peak: Math.max(1024, ...SystemStats.net.map(r => Math.max(r.rx, r.tx)))

        Row {
            x: 14
            y: 12
            spacing: Theme.spaceS
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF06F3
                size: 14
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Network"
                font.weight: Font.DemiBold
            }
        }
        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            y: 12
            text: "peak " + SystemStats.bytes(netCard.peak) + "/s"
            color: Theme.dim
            font.family: Theme.monoFamily
            font.pixelSize: Theme.textCaption
        }

        Canvas {
            id: graph
            x: 14
            y: 36
            width: parent.width - 28
            height: parent.height - 36 - figures.height - 16
            readonly property var samples: SystemStats.net
            onSamplesChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const v = samples, n = 60, peak = netCard.peak;
                if (v.length < 2)
                    return;
                const x = i => width * (i + n - v.length) / (n - 1);
                const y = b => height - 1 - (height - 3) * Math.min(1, b / peak);
                const curve = key => {
                    ctx.moveTo(x(0), y(v[0][key]));
                    for (let i = 1; i < v.length; i++) {
                        const mx = (x(i - 1) + x(i)) / 2;
                        ctx.bezierCurveTo(mx, y(v[i - 1][key]), mx, y(v[i][key]), x(i), y(v[i][key]));
                    }
                };
                // Download: filled.
                const fill = ctx.createLinearGradient(0, 0, 0, height);
                fill.addColorStop(0, Theme.alpha(Theme.accent, 0.35));
                fill.addColorStop(1, Theme.alpha(Theme.accent, 0.02));
                ctx.beginPath();
                curve("rx");
                ctx.lineTo(x(v.length - 1), height);
                ctx.lineTo(x(0), height);
                ctx.closePath();
                ctx.fillStyle = fill;
                ctx.fill();
                ctx.beginPath();
                curve("rx");
                ctx.strokeStyle = Theme.accent;
                ctx.lineWidth = 1.5;
                ctx.stroke();
                // Upload: a line.
                ctx.beginPath();
                curve("tx");
                ctx.strokeStyle = Theme.muted;
                ctx.lineWidth = 1.2;
                ctx.setLineDash([3, 3]);
                ctx.stroke();
            }
        }
        StyledText {
            anchors.centerIn: graph
            visible: SystemStats.net.length < 2
            text: "measuring…"
            color: Theme.dim
            font.pixelSize: Theme.textSmall
        }

        Column {
            id: figures
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spaceM
            spacing: Theme.spaceXxs
            Repeater {
                model: [
                    [0xF01DA, "Down", perf.d ? SystemStats.bytes(perf.d.net.rx) + "/s" : "…"],
                    [0xF0552, "Up", perf.d ? SystemStats.bytes(perf.d.net.tx) + "/s" : "…"],
                    [0xF04A0, "Total", "↓ " + SystemStats.bytes(SystemStats.rxTotal) + "   ↑ " + SystemStats.bytes(SystemStats.txTotal)]
                ]
                Row {
                    required property var modelData
                    spacing: Theme.spaceS
                    Glyph {
                        width: 14
                        anchors.verticalCenter: parent.verticalCenter
                        code: parent.modelData[0]
                        size: 11
                        color: Theme.muted
                    }
                    StyledText {
                        width: 38
                        text: parent.modelData[1]
                        color: Theme.muted
                        font.pixelSize: Theme.textSmall
                    }
                    StyledText {
                        text: parent.modelData[2]
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.textSmall
                    }
                }
            }
        }
    }

    GaugeCard {
        x: netCard.x + netCard.width + perf.gap
        y: perf.topHeight + perf.gap
        width: perf.leftWidth - x
        height: perf.bottomHeight
        glyph: 0xF035B
        title: "Memory"
        value: perf.d ? 100 * perf.d.memory.used / perf.d.memory.total : 0
        line1: perf.d ? SystemStats.pair(perf.d.memory.used, perf.d.memory.total) : "…"
        line2: perf.d && perf.d.memory.swapTotal > 0 ? "swap " + SystemStats.pair(perf.d.memory.swap, perf.d.memory.swapTotal) : ""
    }

    // ---- battery: a tall card that fills like one ----
    Rectangle {
        id: battery
        x: perf.leftWidth + perf.gap
        width: perf.sideWidth
        height: perf.height
        radius: Theme.radiusL
        color: Theme.card
        clip: true


        Rectangle {
            visible: Battery.present
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * Battery.pct / 100
            radius: Theme.radiusL
            color: Theme.alpha(Battery.level, 0.16)
            Behavior on height { NumberAnimation { duration: 900; easing.type: Easing.OutBack } }
        }

        Column {
            visible: Battery.present
            x: 14
            y: 14
            spacing: Theme.spaceXxs
            Glyph {
                code: Battery.charging ? 0xF0084 : 0xF0079
                size: 20
                color: Battery.level
                horizontalAlignment: Text.AlignLeft
            }
            StyledText {
                text: "Battery"
                font.weight: Font.DemiBold
            }
        }
        Column {
            visible: Battery.present
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spaceL
            spacing: 0
            StyledText {
                text: !Battery.present ? "" : Battery.full ? "Full" : Battery.charging ? "Charging" : "On battery"
                color: Theme.muted
                font.pixelSize: Theme.textSmall
            }
            Row {
                spacing: Theme.spaceXxs
                Glyph {
                    visible: Battery.charging
                    anchors.verticalCenter: parent.verticalCenter
                    code: 0xF140B
                    size: 22
                    color: Battery.level
                }
                StyledText {
                    text: Battery.pct + "%"
                    font.pixelSize: Theme.textDisplay
                    font.weight: Font.DemiBold
                    color: Battery.level
                }
            }
        }

        // No battery (a desktop): the fans take the card.
        Column {
            visible: !Battery.present
            x: 14
            y: 14
            width: parent.width - 28
            spacing: Theme.spaceS
            Row {
                spacing: Theme.spaceS
                Glyph { code: 0xF0210; size: 16 }
                StyledText { text: "Fans"; font.weight: Font.DemiBold }
            }
            Repeater {
                model: perf.fans
                Column {
                    required property var modelData
                    width: parent.width
                    StyledText {
                        text: modelData.rpm > 0 ? modelData.rpm + " rpm" : "stopped"
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.textTitle
                        color: modelData.rpm > 0 ? Theme.fg : Theme.muted
                    }
                    StyledText {
                        width: parent.width
                        text: modelData.name
                        color: Theme.dim
                        font.pixelSize: Theme.textCaption
                    }
                }
            }
            StyledText {
                visible: perf.fans.length === 0
                text: "No sensors"
                color: Theme.dim
                font.pixelSize: Theme.textSmall
            }
        }
    }
}
