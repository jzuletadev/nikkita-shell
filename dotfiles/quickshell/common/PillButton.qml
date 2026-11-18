// ~/nikita-shell/dotfiles/quickshell/common/PillButton.qml
//
// The desktop's pill: icon (or a Nerd Font glyph), text or both. `active` fills it
// (a toggle that is on, the chosen option); the pointer only lightens it and draws a
// ring (Theme's state rule). `toggle` marks a switch rather than an action: a dot
// before the text, hollow while off. `danger` tints the icon red at rest and turns
// the whole pill red under the pointer. `busy` swaps the icon for a spinner and
// holds clicks.
import QtQuick
import qs.common

Rectangle {
    id: b

    property string icon: ""
    property int glyph: 0              // a Nerd Font code point, for what Adwaita has no icon for
    property string tip: ""            // Tip.qml
    property string tipSide: ""
    property string text: ""
    property bool active: false
    property bool toggle: false
    property bool danger: false
    property bool flat: false
    property bool interactive: true
    property bool busy: false
    property int iconSize: 15
    property int textSize: Theme.textLabel
    property color restColor: flat ? "transparent" : Theme.control
    readonly property bool hovering: area.containsMouse
    readonly property bool clickable: interactive && !busy
    readonly property bool lit: hovering && clickable
    readonly property bool red: !active && (Qt.colorEqual(restColor, Theme.bad) || (lit && danger))
    readonly property color ink: red ? Theme.badInk : active ? Theme.accentText : interactive ? Theme.fg : Theme.dim
    readonly property color iconInk: danger && !red && !active && interactive ? Theme.bad : ink

    signal clicked
    signal rightClicked
    signal middleClicked

    implicitHeight: 32
    implicitWidth: text !== "" ? row.implicitWidth + 2 * Theme.spaceM : implicitHeight
    radius: height / 2
    color: {
        if (active)
            return lit ? Theme.activeHover : Theme.accent;
        if (!lit)
            return restColor;
        if (!danger)
            return Theme.hoverFill;
        // Already red at rest ("Yes, shut down"): a darker red, so it still moves.
        return Qt.colorEqual(restColor, Theme.bad) ? Qt.darker(Theme.bad, 1.25) : Theme.bad;
    }
    // Busy isn't off: it keeps its look, it just doesn't take clicks.
    opacity: interactive || busy ? 1 : 0.6
    scale: area.pressed ? 0.95 : 1

    Behavior on color { ColorAnimation { duration: Theme.msFast } }
    Behavior on scale { NumberAnimation { duration: Theme.msFast; easing.type: Easing.OutCubic } }

    // The hover ring.
    Rectangle {
        anchors.fill: parent
        radius: b.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.hoverRing
        opacity: b.lit && !b.active && !b.red ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.msFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spaceS

        // A switch's state: a hollow dot while off, filled while on.
        Rectangle {
            visible: b.toggle
            width: 9
            height: 9
            radius: width / 2
            color: b.active ? b.ink : "transparent"
            border.width: 1.5
            border.color: b.ink
            anchors.verticalCenter: parent.verticalCenter
        }
        Spinner {
            visible: b.busy
            size: b.iconSize
            color: b.ink
            anchors.verticalCenter: parent.verticalCenter
        }
        Icon {
            visible: b.icon !== "" && !b.busy
            name: b.icon
            size: b.iconSize
            color: b.iconInk
            anchors.verticalCenter: parent.verticalCenter
        }
        Glyph {
            visible: b.glyph > 0 && !b.busy
            code: b.glyph
            size: b.iconSize + 2
            color: b.iconInk
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            visible: b.text !== ""
            text: b.text
            color: b.ink
            font.pixelSize: b.textSize
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        // Off, it takes no clicks but still the hover: its tooltip may say why.
        acceptedButtons: b.clickable ? Qt.LeftButton | Qt.RightButton | Qt.MiddleButton : Qt.NoButton
        cursorShape: b.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: Tooltips.cancel(area)
        onClicked: ev => {
            if (ev.button === Qt.RightButton)
                b.rightClicked();
            else if (ev.button === Qt.MiddleButton)
                b.middleClicked();
            else
                b.clicked();
        }

        Tip {
            text: b.tip
            side: b.tipSide
        }
    }
}
