// ~/nikita-shell/dotfiles/quickshell/panels/BluetoothPanel.qml
//
// Bluetooth. Search runs for 10 s; unpaired devices with no name (only an address)
// are hidden. New devices pair through scripts/bt-pair.py: pairing needs a BlueZ
// agent, and Quickshell has none.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.common

Item {
    id: bt

    implicitHeight: col.implicitHeight

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool checked: adapter !== null && adapter.enabled

    // ---- the devices ----
    function named(d) {
        const n = (d.name || "").trim();
        return n !== "" && n.toUpperCase() !== d.address.toUpperCase() && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(n);
    }
    readonly property var all: adapter ? adapter.devices.values : []
    readonly property var mine: all.filter(d => d.paired || d.connected).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var found: all.filter(d => !d.paired && !d.connected && named(d)).sort((a, b) => a.name.localeCompare(b.name))
    readonly property int unnamed: all.filter(d => !d.paired && !d.connected && !named(d)).length

    // ---- search: 10 seconds, then stop ----
    property bool searching: false
    property bool searched: false
    function search() {
        if (!checked)
            return;
        error = "";
        searching = true;
        searched = true;
        adapter.discovering = true;
        searchEnd.restart();
    }
    Timer {
        id: searchEnd
        interval: 10000
        onTriggered: {
            bt.searching = false;
            if (bt.adapter)
                bt.adapter.discovering = false;
        }
    }
    Component.onDestruction: if (searching && adapter) adapter.discovering = false

    // ---- pairing and connecting: one at a time ----
    property string busy: ""            // the address being paired or connected
    property string busyKind: ""        // "pair" or "connect"
    property string error: ""

    function connectDone() {
        connectWait.stop();
    }
    function toggle(d) {
        if (busy !== "")
            return;
        error = "";
        if (d.connected) {
            d.disconnect();
        } else if (d.paired) {
            busy = d.address;
            busyKind = "connect";
            d.connect();
            connectWait.restart();
        } else {
            busy = d.address;
            busyKind = "pair";
            pairing.name = d.name;
            pairing.command = ["python3", Paths.script("bt-pair.py"), d.address];
            pairing.running = true;
        }
    }
    Process {
        id: pairing
        property string name: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (!r.ok)
                        bt.error = pairing.name + ": " + r.error;
                } catch (e) {
                    bt.error = pairing.name + ": the pairing helper failed.";
                }
                bt.busy = "";
            }
        }
    }
    Timer {
        id: connectWait
        interval: 20000
        onTriggered: {
            const d = bt.all.find(x => x.address === bt.busy);
            if (d && !d.connected)
                bt.error = `${d.name}: it didn't connect. Is it on and close? If it is connected to a phone, disconnect it there.`;
            bt.busy = "";
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
                height: sw.height
                text: !bt.adapter ? "No Bluetooth adapter" : bt.checked ? "Bluetooth" : "Bluetooth is off"
                color: bt.checked ? Theme.fg : Theme.muted
                font.weight: Font.Medium
            }
            ToggleSwitch {
                id: sw
                visible: bt.adapter !== null
                checked: bt.checked
                onToggled: bt.adapter.enabled = !bt.adapter.enabled
            }
        }

        StyledText {
            visible: bt.error !== ""
            width: parent.width
            text: bt.error
            color: Theme.bad
            font.pixelSize: Theme.textLabel
            wrapMode: Text.Wrap
        }

        StyledText {
            visible: bt.checked && bt.mine.length > 0
            text: "My devices"
            color: Theme.muted
            font.pixelSize: Theme.textSmall
            font.weight: Font.Medium
        }
        Repeater {
            model: bt.checked ? bt.mine : []
            BluetoothRow {
                panel: bt
                width: col.width
            }
        }

        Row {
            visible: bt.checked
            width: parent.width
            spacing: Theme.spaceM
            topPadding: Theme.spaceXs
            PillButton {
                id: searchButton
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                icon: "view-refresh-symbolic"
                text: bt.searching ? "Searching…" : "Search"
                busy: bt.searching
                active: !bt.searching
                onClicked: bt.search()
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - searchButton.width - parent.spacing
                text: bt.searching ? "Looking for 10 seconds. Put the device in pairing mode."
                    : "To add a device, put it in pairing mode and search."
                color: Theme.dim
                font.pixelSize: Theme.textSmall
                wrapMode: Text.Wrap
            }
        }
        StyledText {
            visible: bt.checked && bt.found.length > 0
            text: "Found"
            color: Theme.muted
            font.pixelSize: Theme.textSmall
            font.weight: Font.Medium
        }
        Repeater {
            model: bt.checked ? bt.found : []
            BluetoothRow {
                panel: bt
                width: col.width
            }
        }
        StyledText {
            visible: bt.checked && !bt.searching && bt.searched && bt.found.length === 0
            text: "Nothing new found. Is it in pairing mode, and not connected to another device?"
            width: parent.width
            color: Theme.dim
            font.pixelSize: Theme.textSmall
            wrapMode: Text.Wrap
        }
        StyledText {
            visible: bt.checked && bt.unnamed > 0
            text: bt.unnamed + (bt.unnamed === 1 ? " device without a name, hidden" : " devices without a name, hidden")
            color: Theme.dim
            font.pixelSize: Theme.textSmall
        }
    }
}
