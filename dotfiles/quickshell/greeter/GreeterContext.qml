// ~/nikkita-shell/dotfiles/quickshell/greeter/GreeterContext.qml
//
// The login screen's LockContext: the same properties, but the password goes to
// greetd, which then starts the session (Hyprland through uwsm).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.common

Scope {
    id: ctx

    // NIKKITA_GREETER_PREVIEW=1: in a window, and the power buttons do nothing (LockView).
    readonly property bool preview: Quickshell.env("NIKKITA_GREETER_PREVIEW") === "1"

    property string buffer: ""
    // "" while typing, "checking", "fail" or "error".
    property string state: ""
    property string message: ""
    property bool leaving: false
    // Who can log in: [{ user, name }]. The last one to use the desktop comes first.
    property var users: []
    property int userIndex: 0
    readonly property string user: users[userIndex]?.user ?? ""
    readonly property string name: users[userIndex]?.name || user
    property string host: ""

    readonly property var session: ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"]

    signal failed

    function type(text) {
        buffer = text;
        if (text !== "" && state !== "checking") {
            state = "";
            message = "";
        }
    }

    function submit() {
        if (buffer === "" || state === "checking" || leaving || user === "")
            return;
        message = "";
        if (!Greetd.available) {
            state = "error";
            message = "greetd isn't running";
            failed();
            return;
        }
        state = "checking";
        Greetd.createSession(user);
    }

    function nextUser() {
        if (users.length < 2 || state === "checking" || leaving)
            return;
        userIndex = (userIndex + 1) % users.length;
        buffer = "";
        state = "";
        message = "";
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(ctx.buffer);
            else if (error)
                ctx.message = message;
        }
        function onAuthFailure(message) {
            ctx.buffer = "";
            ctx.state = "fail";
            ctx.failed();
        }
        function onReadyToLaunch() {
            ctx.state = "";
            ctx.leaving = true;
            launch.start();
        }
        function onError(error) {
            ctx.buffer = "";
            ctx.state = "error";
            ctx.message = error;
            ctx.leaving = false;
            ctx.failed();
        }
    }

    // Lets the views fade out first. Quickshell quits once greetd has the session.
    Timer {
        id: launch
        interval: 280
        onTriggered: Greetd.launch(ctx.session, ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland"])
    }

    // People, not system accounts: UID 1000-59999 with a login shell.
    Process {
        running: true
        command: ["getent", "passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const f = line.split(":");
                    const uid = parseInt(f[2]);
                    if (uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6] || ""))
                        found.push({ user: f[0], name: (f[4] || "").split(",")[0].trim() });
                }
                ctx.users = found;
                ctx.pickLast();
            }
        }
    }

    FileView {
        id: last
        path: Paths.state + "/user"
        printErrors: false
        onLoaded: ctx.pickLast()
    }
    function pickLast() {
        const i = users.findIndex(u => u.user === last.text().trim());
        userIndex = Math.max(0, i);
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: ctx.host = text().trim()
    }
}
