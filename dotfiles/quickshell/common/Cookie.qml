// ~/nikita-shell/dotfiles/quickshell/common/Cookie.qml
// A scalloped badge with a value inside (CPU, GPU usage). It turns a little on each
// change. Amber from 75, red from 90.
import QtQuick
import QtQuick.Shapes
import qs.common

Item {
    id: cookie

    property real value: 0                  // 0-100; below 0 means "unknown"
    property string label: value < 0 ? "—" : Math.round(value) + "%"
    property int size: 74
    property int bumps: 9
    readonly property color tone: value >= 90 ? Theme.bad : value >= 75 ? Theme.warn : Theme.fg

    implicitWidth: size
    implicitHeight: size

    property real drawn: Math.max(0, value)
    Behavior on drawn { NumberAnimation { duration: Theme.ms(700); easing.type: Easing.OutBack } }

    // The outline: a circle whose radius waves `bumps` times around it.
    readonly property string outline: {
        const c = size / 2, r = size / 2 - 2, a = r * 0.075, n = 120;
        let d = "";
        for (let i = 0; i <= n; i++) {
            const t = 2 * Math.PI * i / n;
            const rr = r - a + a * Math.cos(bumps * t);
            d += (i === 0 ? "M " : " L ") + (c + rr * Math.cos(t)).toFixed(2) + " " + (c + rr * Math.sin(t)).toFixed(2);
        }
        return d + " Z";
    }

    Shape {
        anchors.fill: parent
        rotation: cookie.drawn * 0.9
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.overlay
            strokeColor: Theme.alpha(cookie.tone, cookie.value >= 75 ? 0.9 : 0.18)
            strokeWidth: 1.5
            PathSvg { path: cookie.outline }
        }
    }

    StyledText {
        anchors.centerIn: parent
        text: cookie.label
        color: cookie.tone
        font.pixelSize: Math.round(cookie.size * 0.27)
        font.weight: Font.DemiBold
    }
}
