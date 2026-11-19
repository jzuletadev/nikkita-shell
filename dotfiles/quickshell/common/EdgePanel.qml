// ~/nikita-shell/dotfiles/quickshell/common/EdgePanel.qml
//
// A panel that grows out of a screen edge, drawn inside one full-screen surface
// per monitor (ScreenSurface.qml), so it animates without resizing a layer surface.
//
//   * Closed, only a strip `m.strip` px wide takes the pointer (ScreenSurface builds
//     the input mask from `stripA`, `stripB`, `zone`).
//   * Entering the strip widens the zone BEFORE the open delay: otherwise moving
//     inward leaves the strip and the panel never opens.
//   * A corner panel opens from either of its two edges (the "L").
//   * A rim and a soft shadow keep it apart from what is behind; both skip the
//     stretches along the screen edge (Outline.rim).
import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services
import "Outline.js" as Outline

Item {
    id: panel

    // ---- where it lives ----
    required property Sizes m
    property string screenName: ""
    property string name: ""            // for ShellState.peek(name, ...)
    property string edge: "left"         // left | right | top | bottom
    property string placement: "center"       // center | start | end (start = top/left)
    property real offset: 0             // from the center, when placement = center
    property real span: 200              // along the edge
    property real depth: 60               // how far it reaches into the screen when open
    property real inset: m.inset
    property bool touchable: true           // a panel you open by touching its edge (not toasts)
    property bool hoverable: touchable && Prefs.opensOnTouch(name) && !m.edgesOff   // Settings → Panels can turn it off
    property color panelColor: Theme.panel
    property bool peekable: touchable       // answers "peek all" (`qs ipc call nikita all`, Settings → Panels)
    // Only panels in the panel color get a rim and a shadow: not the small colored marks.
    readonly property bool plain: Qt.colorEqual(panelColor, Theme.panel)
    property bool shadowed: true            // off while the panel's own size is animating

    // ---- state ----
    property bool pinned: false            // keep it open from outside
    property bool hoverOpen: false
    property bool peeking: false
    readonly property bool isOpen: hoverOpen || peeking || pinned
    // Closed, the pointer counts only on the strip. The input mask sees to that for
    // real motion, but Qt replays the last position whenever the scene changes:
    // closed under a pointer that stays put (a click on its button), a panel would
    // open again by itself as soon as it can, in the screenshot that click took.
    // Set from events, not bound: being hovered engages the panel, and a binding
    // that read `engaged` would loop.
    property bool hovering: false
    function atEdge(p) {
        const within = s => p.x >= s.x && p.x < s.x + s.width && p.y >= s.y && p.y < s.y + s.height;
        return within(stripA) || within(stripB);
    }
    function sense() {
        const now = hover.hovered && (engaged || isOpen || atEdge(hover.point.position));
        if (now !== hovering)
            hovering = now;
    }
    onEngagedChanged: sense()
    property bool engaged: false
    property real progress: 0
    property int openDelay: 140              // rest on the edge before opening
    property int closeDelay: 280              // wait before closing on leave

    // ---- what it shows ----
    default property alias content: interior.data
    readonly property alias interior: interior
    readonly property alias stripA: stripA
    readonly property alias stripB: stripB
    readonly property alias zone: zone
    readonly property real extent: Math.max(0, depth * progress)

    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property real sw: m.screenWidth
    readonly property real sh: m.screenHeight
    readonly property real longAxis: vertical ? sh : sw
    readonly property real longPos: placement === "start" ? 0 : placement === "end" ? longAxis - span : (longAxis - span) / 2 + offset

    x: edge === "right" ? sw - depth : edge === "left" ? 0 : longPos
    y: edge === "bottom" ? sh - depth : edge === "top" ? 0 : longPos
    width: vertical ? depth : span
    height: vertical ? span : depth

    signal opening
    signal closed

    function peek(ms) {
        peeking = true;
        peekTimer.interval = ms;
        peekTimer.restart();
    }

    function close() {
        peeking = false;
        hoverOpen = false;
        engaged = false;
    }

    // ---- the animation: bounces in, leaves crisply ----
    NumberAnimation {
        id: animOpen
        target: panel
        property: "progress"
        to: 1
        duration: Theme.msSlow
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveEnter
    }
    NumberAnimation {
        id: animClose
        target: panel
        property: "progress"
        to: 0
        duration: Theme.msNormal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveExit
        onFinished: panel.closed()
    }
    onIsOpenChanged: {
        if (isOpen) {
            animClose.stop();
            animOpen.start();
            opening();
        } else {
            animOpen.stop();
            animClose.start();
        }
        sense();
    }

    // ---- the pointer ----
    HoverHandler {
        id: hover
        enabled: panel.hoverable || panel.isOpen
        onHoveredChanged: panel.sense()
        onPointChanged: panel.sense()
    }
    onHoveringChanged: {
        if (hovering) {
            engaged = true;
            closeTimer.stop();
            if (!isOpen)
                openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }
    Timer {
        id: openTimer
        interval: panel.openDelay
        onTriggered: if (panel.hovering && panel.hoverable) panel.hoverOpen = true
    }
    Timer {
        id: closeTimer
        interval: panel.closeDelay
        onTriggered: if (!panel.hovering) {
            panel.hoverOpen = false;
            panel.engaged = false;
        }
    }
    Timer {
        id: peekTimer
        onTriggered: {
            panel.peeking = false;
            // If the pointer stayed on it, the panel stays open because of it.
            if (panel.hovering)
                panel.hoverOpen = true;
        }
    }

    Connections {
        target: ShellState
        function onPeek(who, ms, where) {
            if (who !== panel.name && !(who === "*" && panel.peekable))
                return;
            const here = where === "" ? ShellState.focusedScreen() : where;
            if (here === panel.screenName)
                panel.peek(ms);
        }
    }

    // ---- what takes the pointer (ScreenSurface reads it for the mask) ----
    // The strip along the panel's own edge.
    Item {
        id: stripA
        visible: false
        readonly property real t: panel.m.strip
        x: panel.edge === "right" ? panel.width - t : 0
        y: panel.edge === "bottom" ? panel.height - t : 0
        width: !panel.hoverable ? 0 : panel.vertical ? t : panel.width
        height: !panel.hoverable ? 0 : panel.vertical ? panel.height : t
    }
    // The one along the perpendicular edge, only for corners: the other leg of the "L".
    Item {
        id: stripB
        visible: false
        readonly property real t: panel.m.strip
        readonly property bool available: panel.hoverable && panel.placement !== "center"
        x: panel.vertical ? 0 : (panel.placement === "end" ? panel.width - t : 0)
        y: panel.vertical ? (panel.placement === "end" ? panel.height - t : 0) : 0
        width: !available ? 0 : panel.vertical ? panel.width : t
        height: !available ? 0 : panel.vertical ? t : panel.height
    }
    // The whole panel, as soon as it is engaged or open.
    Item {
        id: zone
        visible: false
        width: (panel.engaged || panel.isOpen) ? panel.width : 0
        height: (panel.engaged || panel.isOpen) ? panel.height : 0
    }

    // ---- the drawing ----
    // Visible rectangle, in screen coordinates.
    readonly property real vx: edge === "right" ? sw - extent : edge === "left" ? 0 : x
    readonly property real vy: edge === "bottom" ? sh - extent : edge === "top" ? 0 : y
    readonly property real vw: vertical ? extent : width
    readonly property real vh: vertical ? height : extent
    readonly property string outlinePath: Outline.outline(vx, vy, vw, vh, sw, sh, m.radius, Math.min(m.notch, extent))
    readonly property string rimPath: Outline.rim(vx, vy, vw, vh, sw, sh, m.radius, Math.min(m.notch, extent))
    // The shadow follows the panel at rest, so opening doesn't redraw it at every frame.
    readonly property string shadowPath: Outline.rim(x, y, width, height, sw, sh, m.radius, Math.min(m.notch, depth))

    // Wide strokes one over the other: darker near the edge, fading outward. They need
    // neither an offscreen layer nor a blur, which a full-screen surface would pay for.
    Shape {
        x: -panel.x
        y: -panel.y
        width: panel.sw
        height: panel.sh
        visible: panel.plain && panel.shadowed && opacity > 0
        opacity: Math.max(0, Math.min(1, (panel.progress - 0.85) / 0.15))
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.panelShadow
            strokeWidth: 30
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: panel.shadowPath }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.panelShadow
            strokeWidth: 22
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: panel.shadowPath }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.panelShadow
            strokeWidth: 15
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: panel.shadowPath }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.panelShadow
            strokeWidth: 9
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: panel.shadowPath }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.panelShadow
            strokeWidth: 4
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: panel.shadowPath }
        }
    }

    Shape {
        id: shape
        x: -panel.x
        y: -panel.y
        width: panel.sw
        height: panel.sh
        visible: panel.extent > 0.5
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: panel.panelColor
            strokeColor: "transparent"
            strokeWidth: 0
            PathSvg { path: panel.outlinePath }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: panel.plain ? Theme.panelRim : "transparent"
            strokeWidth: panel.plain ? 1 : 0
            capStyle: ShapePath.FlatCap
            PathSvg { path: panel.rimPath }
        }
    }

    // The content sticks to the INNER side of the panel, so as the panel grows it
    // slides in from the edge instead of popping up.
    Item {
        id: viewport
        clip: true
        visible: panel.extent > 0.5
        x: panel.edge === "right" ? panel.width - panel.extent : 0
        y: panel.edge === "bottom" ? panel.height - panel.extent : 0
        width: panel.vertical ? panel.extent : panel.width
        height: panel.vertical ? panel.height : panel.extent

        Item {
            id: body
            x: panel.edge === "left" ? viewport.width - panel.depth : 0
            y: panel.edge === "top" ? viewport.height - panel.depth : 0
            width: panel.width
            height: panel.height
            opacity: Math.max(0, Math.min(1, (panel.progress - 0.2) / 0.5))

            Item {
                id: interior
                anchors.fill: parent
                anchors.margins: panel.inset
            }
        }
    }
}
