// ~/nikita-shell/dotfiles/quickshell/settings/BluetoothPage.qml
// Bluetooth devices (panels/BluetoothPanel) and how this computer shows itself to
// others.
import QtQuick
import Quickshell.Bluetooth
import qs.common
import qs.panels

Column {
    id: page
    spacing: Theme.spaceXl

    readonly property var adapter: Bluetooth.defaultAdapter

    Section {
        title: "Devices"
        padding: Theme.spaceL
        BluetoothPanel { width: parent.width }
    }

    Section {
        title: "This computer"
        visible: page.adapter !== null && page.adapter.enabled
        SettingRow {
            icon: "computer-symbolic"
            title: "Name"
            subtitle: "How other devices see this computer."
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: page.adapter ? page.adapter.name : ""
                color: Theme.muted
            }
        }
        SettingRow {
            icon: "view-reveal-symbolic"
            title: "Visible"
            subtitle: "Nearby devices can find this computer."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.adapter !== null && page.adapter.discoverable
                onToggled: page.adapter.discoverable = !page.adapter.discoverable
            }
        }
        SettingRow {
            icon: "changes-prevent-symbolic"
            title: "Accept pairing"
            subtitle: "Other devices can ask to pair with this one."
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.adapter !== null && page.adapter.pairable
                onToggled: page.adapter.pairable = !page.adapter.pairable
            }
        }
    }
}
