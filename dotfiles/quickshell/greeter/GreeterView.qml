// ~/nikkita-shell/dotfiles/quickshell/greeter/GreeterView.qml
//
// One monitor of the login screen: the lock screen's view, with the computer's name
// in the card's foot and, when there are several users, a button to switch.
import QtQuick
import qs.common
import qs.lock

LockView {
    id: view

    showMedia: false
    footer: ctx.host
    preview: ctx.preview

    PillButton {
        visible: view.ctx.users.length > 1
        implicitHeight: 34
        flat: true
        icon: "system-users-symbolic"
        tip: "Switch user"
        onClicked: view.ctx.nextUser()
    }
}
