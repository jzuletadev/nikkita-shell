// ~/nikita-shell/dotfiles/quickshell/common/AppIcon.qml
// An application icon, in full color. Takes a theme icon name or a path.
import QtQuick
import Quickshell
import Quickshell.Widgets

IconImage {
    id: ic

    property string name: ""
    property string fallback: "application-x-executable"
    property int size: 24

    implicitSize: size
    asynchronous: true
    source: {
        const n = ic.name;
        if (n === "")
            return Quickshell.iconPath(ic.fallback, true);
        if (n.startsWith("/"))
            return "file://" + n;
        if (n.includes("://"))
            return n;
        return Quickshell.iconPath(n, ic.fallback);
    }
}
