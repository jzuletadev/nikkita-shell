// ~/nikita-shell/dotfiles/quickshell/settings/NetworkPage.qml
// Wired, Wi-Fi (panels/NetworkPanel), the firewall (services/Firewall.qml) and
// NetworkManager's own tool. Wired goes last while unplugged, so "Cable unplugged"
// isn't the first thing you read.
import QtQuick
import Quickshell
import qs.common
import qs.panels
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    Component.onCompleted: Firewall.refresh()

    // What a name stands for, for people.
    function describe(what) {
        return ({ ssh: "SSH, remote login (port " + Firewall.sshPorts + ")", kdeconnect: "KDE Connect, your phone", syncthing: "Syncthing, file sync" })[what]
            ?? "Port " + what.replace("/", " (") + ")";
    }

    component Wired: Section {
        title: "Wired"
        SettingRow {
            icon: Net.cable ? "network-wired-symbolic" : "network-wired-disconnected-symbolic"
            title: "Ethernet" + (Net.wired ? ` (${Net.wired.name})` : "")
            subtitle: Net.wiredStatus
            Spinner {
                visible: Net.wiredBusy
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.muted
            }
            ToggleSwitch {
                visible: Net.cable && (Net.wiredConnected || Net.wired.network !== null)
                anchors.verticalCenter: parent.verticalCenter
                checked: Net.wiredConnected
                onToggled: Net.toggleWired()
            }
        }
    }

    Wired { visible: Net.wired !== null && Net.cable }

    Section {
        title: "Wi-Fi"
        padding: Theme.spaceL
        NetworkPanel { width: parent.width }
    }

    Wired { visible: Net.wired !== null && !Net.cable }

    Section {
        title: "Firewall"
        note: Firewall.other !== "" ? ""
            : "What this computer opens itself (web, updates, SSH to other computers) is never blocked. Containers that publish a port (Docker) are reachable whatever this says. Changes ask for your password."
        SettingRow {
            icon: Firewall.active ? "security-high-symbolic" : "security-low-symbolic"
            title: "Block incoming connections"
            subtitle: !Firewall.loaded ? "Reading…"
                : Firewall.other !== "" ? Firewall.other + " is this computer's firewall: change it there."
                : Firewall.active ? "On: other computers can't connect to this one, except what is allowed below."
                : "Off: any program here that listens can be reached by others on the same network (a café, an airport)."
            Spinner {
                visible: Firewall.busy === "on" || Firewall.busy === "off" || Firewall.busy === "install"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.muted
            }
            ToggleSwitch {
                visible: Firewall.loaded && Firewall.other === ""
                anchors.verticalCenter: parent.verticalCenter
                checked: Firewall.active
                onToggled: if (Firewall.busy === "") Firewall.setOn(!Firewall.active)
            }
        }
        Repeater {
            model: Firewall.other === "" && Firewall.installed ? Firewall.allowed : []
            SettingRow {
                required property string modelData
                icon: "network-server-symbolic"
                title: page.describe(modelData)
                subtitle: modelData === "ssh" ? "Let in, at most 20 new connections a minute from one address." : "Let in."
                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "user-trash-symbolic"
                    tip: "Stop letting it in"
                    busy: Firewall.busy === "deny " + modelData
                    interactive: Firewall.busy === ""
                    onClicked: Firewall.deny(modelData)
                }
            }
        }
        SettingRow {
            visible: Firewall.other === "" && Firewall.installed
            icon: "list-add-symbolic"
            title: "Let something in"
            subtitle: portField.text !== "" && !Firewall.valid(portField.text.trim()) ? "A name (ssh, kdeconnect, syncthing) or a port: 8080/tcp, 5000-5010/udp."
                : Firewall.sshd && Firewall.allowed.indexOf("ssh") < 0 ? "SSH is running here but closed: write ssh to let it in."
                : "A name (ssh, kdeconnect, syncthing) or a port: 8080/tcp."
            InputField {
                id: portField
                width: 200
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                icon: "network-server-symbolic"
                placeholder: "8080/tcp"
                onSubmitted: add.go()
            }
            PillButton {
                id: add
                anchors.verticalCenter: parent.verticalCenter
                text: "Allow"
                interactive: Firewall.valid(portField.text.trim()) && Firewall.busy === ""
                function go() {
                    const w = portField.text.trim();
                    if (!Firewall.valid(w) || Firewall.busy !== "")
                        return;
                    Firewall.allow(w);
                    portField.text = "";
                }
                onClicked: go()
            }
        }
    }

    Section {
        title: "More"
        SettingRow {
            icon: "utilities-terminal-symbolic"
            title: "Advanced settings"
            subtitle: "VPNs, hidden networks, fixed addresses: NetworkManager's own tool, in the terminal."
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Open nmtui"
                onClicked: Commands.launch(["kitty", "-e", "nmtui"], "Opening nmtui")
            }
        }
    }
}
