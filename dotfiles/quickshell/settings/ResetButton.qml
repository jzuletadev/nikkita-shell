// ~/nikkita-shell/dotfiles/quickshell/settings/ResetButton.qml
// Back to the default, beside a setting: it shows only once that setting is
// changed, so a value touched by mistake can always be found again.
import QtQuick
import qs.common

PillButton {
    property bool changed: false
    property string defaultText: ""      // "600 ms", shown in the tooltip

    visible: changed
    width: 28
    height: 28
    flat: true
    icon: "edit-undo-symbolic"
    iconSize: 13
    tip: "Back to the default" + (defaultText !== "" ? ": " + defaultText : "")
}
