// ~/nikita-shell/dotfiles/quickshell/services/Updates.qml
//
// Package updates (scripts/updates.sh): shown in the Power corner, Settings → About
// and the launcher. Asked when one of those opens and the last answer is older
// than six hours, never on a timer. Those quiet checks keep a failure (no network)
// for their tooltip; "Check now" reports it.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: updates

    property var repo: []
    property var aur: []
    readonly property int count: repo.length + aur.length
    property real checkedAt: 0
    property string error: ""
    readonly property bool checking: proc.running
    property bool loud: false

    // "12 updates", "Up to date", "Not checked yet".
    readonly property string summary: checking && checkedAt === 0 ? "Checking for updates"
        : error !== "" && checkedAt === 0 ? "Couldn't check: " + error
        : checkedAt === 0 ? "Not checked yet"
        : count === 0 ? "Up to date"
        : count + (count === 1 ? " update" : " updates") + (aur.length > 0 ? ` (${aur.length} from the AUR)` : "")

    function check(report) {
        loud = loud || report === true;
        if (!proc.running)
            proc.running = true;
    }
    function checkIfStale() {
        if (Date.now() - checkedAt > 6 * 3600000)
            check(false);
    }
    // In a terminal: pacman asks for the password there. The script checks again at
    // the end (`qs ipc call nikita updates`).
    function install() {
        Commands.launch(["kitty", "--title", "System update", "-e", Paths.script("updates.sh"), "install"], "Updating the system");
    }

    Process {
        id: proc
        command: [Paths.script("updates.sh"), "check"]
        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onExited: code => {
            if (code === 0) {
                try {
                    const d = JSON.parse(out.text);
                    updates.repo = d.repo;
                    updates.aur = d.aur;
                    updates.checkedAt = Date.now();
                    updates.error = "";
                } catch (e) {
                    updates.error = "can't read updates.sh: " + e;
                }
            } else {
                updates.error = Commands.lastLine(err.text) || `updates.sh ended with code ${code}.`;
            }
            if (updates.error !== "" && updates.loud)
                Commands.report("Checking for updates", updates.error);
            updates.loud = false;
        }
    }
}
