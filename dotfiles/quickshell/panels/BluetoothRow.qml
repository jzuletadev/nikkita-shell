// ~/nikita-shell/dotfiles/quickshell/panels/BluetoothRow.qml
// One device in BluetoothPanel. A click asks the panel to act (`panel.toggle`).
import QtQuick
import Quickshell.Bluetooth
import qs.common

ListRow {
    id: row

    required property var modelData
    required property var panel
    readonly property bool working: panel.busy === modelData.address

    icon: (modelData.icon || "bluetooth") + "-symbolic"
    title: modelData.name || modelData.address
    active: modelData.connected
    subtitle: {
        const d = modelData;
        if (working && panel.busyKind === "pair")
            return "Pairing…";
        if (working || d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (!d.paired)
            return "Click to pair";
        let s = d.connected ? "Connected" : "Paired · click to connect";
        if (d.connected && d.batteryAvailable)
            s += " · " + Math.round(d.battery > 1 ? d.battery : d.battery * 100) + " %";
        return s;
    }
    onClicked: panel.toggle(modelData)

    // Connected while the panel waited: done.
    Connections {
        target: row.modelData
        function onConnectedChanged() {
            if (row.modelData.connected && row.working && row.panel.busyKind === "connect") {
                row.panel.busy = "";
                row.panel.connectDone();
            }
        }
    }

    Spinner {
        visible: row.working || row.modelData.state === BluetoothDeviceState.Connecting
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.muted
    }
    PillButton {
        visible: row.modelData.paired && !row.working
        height: 26
        flat: true
        icon: "user-trash-symbolic"
        iconSize: 13
        tip: "Forget this device"
        onClicked: row.modelData.forget()
    }
}
