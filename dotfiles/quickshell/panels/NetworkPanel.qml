// ~/nikkita-shell/dotfiles/quickshell/panels/NetworkPanel.qml
//
// Wi-Fi (NetworkManager, through Quickshell's networking module). A secured network
// asks for its password here; on failure the reason is shown and the password
// stays selected to retry.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.common
import qs.services

Item {
    id: network

    implicitHeight: col.implicitHeight

    readonly property var wifi: Net.wifi
    readonly property var networks: !wifi ? [] : wifi.networks.values.filter(n => n.name !== "").slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (strength(b) - strength(a)))
    property var asking: null           // the secured network whose password is being typed
    property var pending: null          // the network being connected to, until it is or fails
    property string error: ""

    Binding {
        when: network.wifi !== null && network.visible && Networking.wifiEnabled
        target: network.wifi
        property: "scannerEnabled"
        value: true
    }

    function strength(n) {
        const s = n.signalStrength;
        return s > 1 ? s / 100 : s;
    }
    function icon(n) {
        const s = strength(n);
        const level = s > 0.75 ? "excellent" : s > 0.5 ? "good" : s > 0.25 ? "ok" : "weak";
        return `network-wireless-signal-${level}-symbolic`;
    }
    function isOpen(n) {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe;
    }
    function toggle(n) {
        error = "";
        if (n.connected) {
            n.disconnect();
        } else if (n.known || isOpen(n)) {
            asking = null;
            pending = n;
            n.connect();
        } else if (asking === n) {
            asking = null;              // clicked again: never mind
        } else {
            asking = n;
            passwordField.text = "";
            passwordField.revealed = false;
            passwordField.input.forceActiveFocus();
        }
    }

    function connectAsking() {
        if (!asking || passwordField.text.length === 0 || pending !== null)
            return;
        error = "";
        pending = asking;
        asking.connectWithPsk(passwordField.text);
    }

    Connections {
        target: network.pending
        function onConnectedChanged() {
            if (network.pending && network.pending.connected) {
                if (network.asking === network.pending)
                    network.asking = null;
                network.pending = null;
            }
        }
        function onConnectionFailed(reason) {
            const n = network.pending;
            network.error = `Couldn't connect to ${n.name}: ${Net.reason(reason)}`;
            network.pending = null;
            if (network.asking === n) {
                passwordField.input.selectAll();
                passwordField.input.forceActiveFocus();
            }
        }
    }
    // A hung connection must not leave the spinner turning forever.
    Timer {
        running: network.pending !== null
        interval: 45000
        onTriggered: {
            network.error = `No answer from ${network.pending.name}`;
            network.pending = null;
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.spaceM

        Row {
            width: parent.width
            StyledText {
                width: parent.width - sw.width
                // The section above already says "Wi-Fi": this says how it is.
                readonly property var current: network.networks.find(n => n.connected) ?? null
                text: !Networking.wifiHardwareEnabled ? "Blocked by a hardware switch"
                    : !Networking.wifiEnabled ? "Off"
                    : current !== null ? "Connected to " + current.name : "On, not connected"
                color: Networking.wifiEnabled ? Theme.fg : Theme.muted
                font.weight: Font.Medium
                height: sw.height
            }
            ToggleSwitch {
                id: sw
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spaceS
            visible: network.asking !== null
            StyledText {
                text: network.asking ? "Password for " + network.asking.name : ""
                color: Theme.muted
                font.pixelSize: Theme.textLabel
            }
            Row {
                width: parent.width
                spacing: Theme.spaceS
                InputField {
                    id: passwordField
                    width: parent.width - connectButton.width - 8
                    icon: "dialog-password-symbolic"
                    placeholder: "Password"
                    secret: true
                    onSubmitted: network.connectAsking()
                }
                Binding {
                    target: passwordField.input
                    property: "readOnly"
                    value: network.pending !== null
                }
                PillButton {
                    id: connectButton
                    readonly property bool working: network.pending !== null && network.pending === network.asking
                    // As wide as "Connecting…", so the field doesn't move when it changes.
                    width: 132
                    height: 40
                    text: working ? "Connecting…" : "Connect"
                    busy: working
                    active: true
                    interactive: passwordField.text.length > 0
                    onClicked: network.connectAsking()
                }
            }
        }

        StyledText {
            visible: network.error !== ""
            width: parent.width
            text: network.error
            color: Theme.bad
            font.pixelSize: Theme.textLabel
            wrapMode: Text.Wrap
        }

        Item {
            width: parent.width
            height: Math.min(listView.contentHeight, 340)
            visible: Networking.wifiEnabled

            ListView {
                id: listView
                width: parent.width - 6
                height: parent.height
                clip: true
                spacing: Theme.spaceXs
                boundsBehavior: Flickable.StopAtBounds
                model: network.networks

                delegate: ListRow {
                    id: row
                    required property var modelData
                    width: listView.width
                    icon: network.icon(modelData)
                    title: modelData.name
                    active: modelData.connected
                    readonly property bool working: modelData.stateChanging || (network.pending === modelData && !modelData.connected)
                    subtitle: working ? (modelData.connected ? "Disconnecting…" : "Connecting…")
                        : modelData.connected ? "Connected" : modelData.known ? "Saved" : network.isOpen(modelData) ? "Open" : "Secured"
                    onClicked: network.toggle(modelData)

                    Spinner {
                        visible: row.working
                        anchors.verticalCenter: parent.verticalCenter
                        size: 14
                        color: Theme.muted
                    }

                    PillButton {
                        visible: row.modelData.known
                        height: 26
                        flat: true
                        icon: "user-trash-symbolic"
                        iconSize: 13
                        tip: "Forget this network"
                        onClicked: row.modelData.forget()
                    }
                }
            }
            ScrollHint { view: listView }
        }

        StyledText {
            visible: Networking.wifiEnabled && network.networks.length === 0
            text: network.wifi ? "Looking for networks…" : "No Wi-Fi device"
            color: Theme.dim
        }
    }
}
