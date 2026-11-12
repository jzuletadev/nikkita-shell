// ~/nikkita-shell/dotfiles/quickshell/services/Commands.qml
//
// Every command the desktop runs for you goes through here, so a failure always
// says so: a notification with what failed and the program's last words.
//
//   run(argv, what, done)   a short command (systemctl, a script). Reported if it
//                           exits non-zero or isn't installed. `what` names the
//                           action for people ("Shut down"); null when the program
//                           reports its own failures (scripts that notify).
//                           `done(code, stderr)` is optional.
//   runAsRoot(argv, what, done)
//                           the same as root, through pkexec: the desktop's own
//                           dialog asks for the password. Closing that dialog is a
//                           "no", not a failure to report.
//   launch(argv, what)      an app or a terminal: started by uwsm as a systemd unit of
//                           its own, so it outlives the shell (which is a service:
//                           whatever it starts directly is part of it). Reported only
//                           if the program isn't installed.
//   launchEntry(entry, what) an app from its desktop entry (the launcher), the same way.
//   report(what, why)       the same notification, for failures found elsewhere.
//   notify(title, body, icon, critical)
//                           a notice from the desktop itself (a low battery).
//                           Critical ones stay until dismissed and pass Do not
//                           disturb.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: commands

    // The same failure again within this time isn't shown twice (a held key).
    readonly property int quietMs: 10000
    property var shownAt: ({})

    function report(what, why) {
        console.warn(`${what} failed: ${why}`);
        const now = Date.now();
        if (shownAt[what] !== undefined && now - shownAt[what] < quietMs)
            return;
        shownAt[what] = now;
        Quickshell.execDetached(["notify-send", "-a", "Desktop", "-i", "dialog-warning-symbolic", what + " didn't work", why]);
    }

    function notify(title, body, icon, critical) {
        Quickshell.execDetached(["notify-send", "-a", "Desktop", "-i", icon || "dialog-information-symbolic",
                                 "-u", critical ? "critical" : "normal", title, body]);
    }

    function run(argv, what, done) {
        runner.createObject(commands, { command: argv, what: what ?? "", done: done ?? null, running: true });
    }

    function runAsRoot(argv, what, done) {
        run(["pkexec"].concat(argv), null, (code, err) => {
            // 126: the dialog was closed, or this user may not. 127 with nothing
            // said: pkexec itself is missing.
            if (code === 127 && err === "")
                report(what, "pkexec isn't installed (the polkit package).");
            else if (code !== 0 && code !== 126)
                report(what, lastLine(err) || `${argv[0]} ended with code ${code}.`);
            if (done)
                done(code, err);
        });
    }

    // Without uwsm (an install from before it was required), the app starts
    // directly, as before.
    readonly property string detach: 'if command -v uwsm >/dev/null 2>&1; then exec uwsm app -- "$@"; fi; exec "$@"'

    function launch(argv, what) {
        // $1 names the action, $2 the program; then the command itself.
        Quickshell.execDetached(["sh", "-c",
            "command -v \"$2\" >/dev/null 2>&1 || exec notify-send -a Desktop -i dialog-warning-symbolic \"$1 didn't work\" \"$2 isn't installed.\"; shift; " + detach,
            "sh", what || argv[0]].concat(argv));
    }

    // uwsm reads the entry itself (its Exec, Path, terminal); without uwsm, its
    // command runs directly.
    function launchEntry(entry, what) {
        if (!entry.id) {
            entry.execute();
            return;
        }
        Quickshell.execDetached(["sh", "-c",
            'command -v uwsm >/dev/null 2>&1 && exec uwsm app -- "$1"; shift; exec "$@"', "sh", entry.id + ".desktop"].concat(entry.command));
    }

    // The useful part of an error is usually its last line.
    function lastLine(text) {
        const lines = (text || "").split("\n").map(l => l.trim()).filter(l => l !== "");
        return lines.length > 0 ? lines[lines.length - 1] : "";
    }

    Component {
        id: runner

        Process {
            id: proc
            property string what
            property var done
            property bool started: false

            stderr: StdioCollector {}

            // A program that isn't there never starts and never exits (tested): only
            // `running` goes back to false.
            onRunningChanged: {
                if (running) {
                    started = true;
                } else if (!started) {
                    if (what !== "")
                        commands.report(what, `${command[0]} isn't installed.`);
                    if (done)
                        done(127, "");
                    destroy();
                }
            }
            // stderr is complete by now: it finishes before the exit (tested).
            onExited: code => {
                if (code !== 0 && what !== "")
                    commands.report(what, commands.lastLine(stderr.text) || `${command[0]} ended with code ${code}.`);
                if (done)
                    done(code, stderr.text);
                destroy();
            }
        }
    }
}
