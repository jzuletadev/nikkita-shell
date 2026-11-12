// ~/nikkita-shell/dotfiles/quickshell/common/InputField.qml
// A text field with an icon. `secret` adds an eye that shows what is typed.
import QtQuick
import qs.common

Rectangle {
    id: c

    property alias text: input.text
    property alias input: input
    property string icon: "system-search-symbolic"
    property string placeholder: ""
    property bool secret: false
    property bool revealed: false
    // For a field that grows out of its icon (the launcher): where the icon sits
    // and how visible the text is meanwhile.
    property real iconX: 14
    property real contentOpacity: 1
    signal submitted
    signal specialKey(var ev)

    implicitHeight: 40
    radius: height / 2
    color: Theme.card
    border.width: input.activeFocus ? 1 : 0
    border.color: Theme.accent

    // A click anywhere on the field, its padding and its icon included, is a click
    // on the text: the TextInput itself is only as tall as a line.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: input.forceActiveFocus()
    }

    Icon {
        id: ico
        x: c.iconX
        anchors.verticalCenter: parent.verticalCenter
        name: c.icon
        size: 15
        color: input.activeFocus ? Theme.accent : Theme.muted
    }

    TextInput {
        id: input
        anchors.left: ico.right
        anchors.leftMargin: Theme.spaceM
        opacity: c.contentOpacity
        anchors.right: parent.right
        anchors.rightMargin: c.secret ? 44 : 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textLarge
        clip: true
        echoMode: c.secret && !c.revealed ? TextInput.Password : TextInput.Normal
        onAccepted: c.submitted()
        Keys.onPressed: ev => c.specialKey(ev)

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: c.placeholder
            color: Theme.dim
            font.pixelSize: Theme.textLarge
        }
    }

    PillButton {
        visible: c.secret
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        flat: true
        icon: c.revealed ? "view-conceal-symbolic" : "view-reveal-symbolic"
        iconSize: 14
        tip: c.revealed ? "Hide the password" : "Show the password"
        onClicked: {
            c.revealed = !c.revealed;
            input.forceActiveFocus();
        }
    }
}
