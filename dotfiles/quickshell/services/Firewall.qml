// ~/nikita-shell/dotfiles/quickshell/services/Firewall.qml
//
// The firewall (scripts/firewall.sh): whether it is on and what is let in. Reading
// needs nothing; every change needs root, so it goes through pkexec and the
// desktop's password dialog. Read when Settings → Network opens.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: fw

    property bool loaded: false
    property bool installed: false
    property bool active: false
    property string other: ""            // ufw or firewalld running instead
    property var allowed: []             // "ssh", "8080/tcp"...
    property bool sshd: false
    property string sshPorts: "22"
    property string busy: ""             // what is being changed, while the dialog asks

    function refresh() {
        status.running = true;
    }
    function run(args, what) {
        busy = args.join(" ");
        Commands.runAsRoot([Paths.script("firewall.sh")].concat(args), what, () => {
            fw.busy = "";
            fw.refresh();
        });
    }
    function setOn(on) {
        if (on)
            run(installed ? ["on"] : ["install"], "Turning the firewall on");
        else
            run(["off"], "Turning the firewall off");
    }
    function allow(what) {
        run(["allow", what], "Letting " + what + " in");
    }
    function deny(what) {
        run(["deny", what], "Closing " + what);
    }
    // The same check firewall.sh makes, so a typo is caught before the password.
    function valid(what) {
        if (["ssh", "kdeconnect", "syncthing"].indexOf(what) >= 0)
            return true;
        const m = /^(\d{1,5})(-(\d{1,5}))?\/(tcp|udp)$/.exec(what);
        if (!m)
            return false;
        const a = parseInt(m[1]), b = m[3] ? parseInt(m[3]) : a;
        return a >= 1 && b <= 65535 && b >= a;
    }

    Process {
        id: status
        command: [Paths.script("firewall.sh"), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    fw.installed = d.installed;
                    fw.active = d.active;
                    fw.other = d.other;
                    fw.allowed = d.allowed;
                    fw.sshd = d.sshd;
                    fw.sshPorts = d.sshPorts;
                    fw.loaded = true;
                } catch (e) {
                    console.warn("firewall: can't read firewall.sh status:", e);
                }
            }
        }
    }
}
