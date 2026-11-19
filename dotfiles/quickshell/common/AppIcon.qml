// ~/nikita-shell/dotfiles/quickshell/common/AppIcon.qml
// An application icon, in full color. Takes a theme icon name, a path or an
// image://icon/ address. With `initial` (usually the app's name), one that doesn't
// exist becomes that letter in a hexagon; without it, the generic app icon.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

IconImage {
    id: ic

    property string name: ""
    property string initial: ""
    property string fallback: "application-x-executable"
    property int size: 24
    // The real icon, "" when there is none.
    readonly property string found: {
        const n = ic.name.startsWith("image://icon/") ? ic.name.slice(13) : ic.name;
        if (n === "")
            return "";
        if (n.startsWith("/"))
            return "file://" + n;
        if (n.includes("://"))
            return n;
        return Quickshell.iconPath(n, true);
    }

    implicitSize: size
    asynchronous: true
    source: found !== "" ? found : initial !== "" ? "" : Quickshell.iconPath(fallback, true)

    HexShape {
        anchors.centerIn: parent
        visible: ic.found === "" && ic.initial !== ""
        height: ic.size
        width: Math.round(height * Theme.hexRatio)
        fill: Theme.cardHover
        label: ic.initial.charAt(0).toUpperCase()
        labelColor: Theme.muted
        labelSize: Math.max(Theme.textCaption, Math.round(ic.size * 0.42))
    }
}
