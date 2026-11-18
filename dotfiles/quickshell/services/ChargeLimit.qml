// ~/nikita-shell/dotfiles/quickshell/services/ChargeLimit.qml
//
// The battery's charge limit ("stop at 80 %"), on laptops whose driver has the
// kernel's switch for it (scripts/charge-limit.sh: which ones, and how they
// differ). Reading it is free; changing it needs root, so it goes through pkexec
// and the desktop's own password dialog. Read when Settings → Power opens.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: charge

    property bool supported: false
    property int limit: 100            // in force now; 100 = it charges to full
    property int changing: -1          // the limit being set, while the dialog asks

    function refresh() {
        status.running = true;
    }
    function set(n) {
        changing = n;
        Commands.runAsRoot([Paths.script("charge-limit.sh"), "set", String(n)], "Setting the charge limit", () => {
            charge.changing = -1;
            charge.refresh();
        });
    }

    Process {
        id: status
        command: [Paths.script("charge-limit.sh"), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    charge.supported = d.supported === true;
                    charge.limit = d.limit;
                } catch (e) {
                    charge.supported = false;
                }
            }
        }
    }
}
