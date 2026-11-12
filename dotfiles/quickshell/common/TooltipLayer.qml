// ~/nikkita-shell/dotfiles/quickshell/common/TooltipLayer.qml
//
// Draws the tooltip (Tooltips) when its item is in this window. Put it last in the
// window; it takes no input.
import QtQuick
import qs.common

Item {
    id: layer

    anchors.fill: parent
    z: 1000

    readonly property Item target: Tooltips.target
    readonly property bool mine: target !== null && target.visible && target.Window.window === layer.Window.window
    readonly property var lines: Tooltips.text.split("\n")

    property real tx: 0
    property real ty: 0

    onTargetChanged: place()
    onMineChanged: place()

    function place() {
        // `target` can be gone without a change signal (its window closed): check it.
        if (!mine || !target)
            return;
        const gap = 8, edge = 6;
        const r = target.mapToItem(layer, 0, 0, target.width, target.height);
        const w = bubble.width, h = bubble.height;
        let x, y;
        if (Tooltips.side === "left" || Tooltips.side === "right") {
            x = Tooltips.side === "left" ? r.x - w - gap : r.x + r.width + gap;
            y = r.y + r.height / 2 - h / 2;
        } else {
            x = r.x + r.width / 2 - w / 2;
            y = r.y - h - gap;
            if (y < edge)
                y = r.y + r.height + gap;
        }
        tx = Math.round(Math.max(edge, Math.min(layer.width - w - edge, x)));
        ty = Math.round(Math.max(edge, Math.min(layer.height - h - edge, y)));
    }

    Rectangle {
        id: bubble

        x: layer.tx
        y: layer.ty + (layer.mine ? 0 : 3)
        width: content.width + 20
        height: content.height + 12
        radius: Theme.radiusS
        color: Theme.mix(Theme.bg, Theme.fg, 0.15)
        border.width: 1
        border.color: Theme.alpha(Theme.fg, 0.10)
        opacity: layer.mine ? 1 : 0
        visible: opacity > 0

        onWidthChanged: layer.place()
        onHeightChanged: layer.place()

        Behavior on opacity { NumberAnimation { duration: Theme.msFast } }
        // Sliding from one icon to the next, the bubble follows instead of jumping.
        Behavior on x { enabled: bubble.opacity > 0.5; NumberAnimation { duration: Theme.msFast; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.msFast; easing.type: Easing.OutCubic } }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: Theme.spaceXxs

            StyledText {
                width: Math.min(implicitWidth, 340)
                text: layer.lines[0]
                font.pixelSize: Theme.textLabel
                font.weight: Font.Medium
            }
            StyledText {
                visible: layer.lines.length > 1
                width: Math.min(implicitWidth, 340)
                text: layer.lines.slice(1).join("  ·  ")
                color: Theme.muted
                font.pixelSize: Theme.textSmall
            }
        }
    }
}
