// ~/nikkita-shell/dotfiles/quickshell/services/Net.qml
//
// The Wi-Fi and wired devices (NetworkManager). Wired: `hasLink` is the cable; its
// `network` (the profile) doesn't exist until a cable is first plugged in.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: net

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool cable: wired !== null && wired.hasLink
    readonly property bool wiredConnected: wired !== null && wired.connected
    readonly property bool wiredBusy: wired !== null && wired.network !== null && wired.network.stateChanging
    readonly property string wiredStatus: {
        if (!wired)
            return "";
        if (!wired.hasLink)
            return "Cable unplugged";
        if (wiredBusy)
            return wiredConnected ? "Disconnecting…" : "Connecting…";
        return wiredConnected ? "Connected · " + speed(wired.linkSpeed) : "Not connected";
    }

    function speed(mbps) {
        return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s";
    }

    function toggleWired() {
        if (!cable)
            return;
        if (wired.connected)
            wired.disconnect();
        else if (wired.network)
            wired.network.connect();
    }

    // NetworkManager says "no secrets" for a wrong password, or the handshake times out.
    function reason(r) {
        switch (r) {
        case ConnectionFailReason.NoSecrets:
            return "wrong password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "no answer in time (wrong password?)";
        case ConnectionFailReason.WifiNetworkLost:
            return "the network went out of reach";
        case ConnectionFailReason.WifiClientFailed:
        case ConnectionFailReason.WifiClientDisconnected:
            return "the network refused the connection";
        default:
            return "unknown error";
        }
    }
}
