// ~/nikita-shell/dotfiles/quickshell/common/RollingDigit.qml
// One digit of BigClock, which rolls when it changes. It is as tall as the digits'
// ink, not the font's line, so BigClock can align its parts to the pixel.
import QtQuick
import qs.common

Item {
    id: d

    property string digit: "0"
    property int size: 64
    property int weight: Font.DemiBold
    property string family: Theme.clockFamily
    property color color: Theme.fg

    FontMetrics {
        id: fm
        font: next.font
    }
    readonly property real inkTop: -fm.tightBoundingRect("0").y     // baseline to top
    // Where a face sits so its digits' top is at y = 1 (1 px of air for overshoot).
    readonly property real base: 1 - (fm.ascent - inkTop)

    implicitWidth: Math.ceil(fm.advanceWidth("0"))
    implicitHeight: Math.ceil(inkTop) + 2
    clip: true

    property string current: ""
    property string previous: ""
    property real t: 1                  // 0 = just changed, 1 = settled

    Component.onCompleted: current = digit
    onDigitChanged: {
        if (current !== "" && digit !== current) {
            previous = current;
            roll.restart();
        }
        current = digit;
    }
    NumberAnimation {
        id: roll
        target: d
        property: "t"
        from: 0
        to: 1
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }

    component Face: Text {
        width: d.width
        horizontalAlignment: Text.AlignHCenter
        color: d.color
        font.family: d.family
        font.pixelSize: d.size
        font.weight: d.weight
        // Oswald is a variable font: Qt only thickens it through its weight axis.
        font.variableAxes: { "wght": d.weight }
        font.features: { "tnum": 1 }
    }

    Face {
        text: d.previous
        y: d.base - d.t * d.height
        opacity: 1 - d.t
        visible: d.t < 1
    }
    Face {
        id: next
        text: d.current
        y: d.base + (1 - d.t) * d.height
        opacity: Math.min(1, d.t * 1.5)
    }
}
