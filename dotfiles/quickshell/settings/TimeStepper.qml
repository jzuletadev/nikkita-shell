// ~/nikita-shell/dotfiles/quickshell/settings/TimeStepper.qml
// A time of day in half-hour steps: − 20:00 +. `value` is minutes after midnight.
import QtQuick
import qs.common
import qs.services

Row {
    id: stepper

    property int value: 0
    property int step: 30
    signal picked(int v)

    spacing: Theme.spaceS

    PillButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "list-remove-symbolic"
        tip: "Earlier"
        onClicked: stepper.picked((stepper.value - stepper.step + 1440) % 1440)
    }
    StyledText {
        width: 64
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        text: NightLight.clock(stepper.value)
        font.family: Theme.monoFamily
    }
    PillButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "list-add-symbolic"
        tip: "Later"
        onClicked: stepper.picked((stepper.value + stepper.step) % 1440)
    }
}
