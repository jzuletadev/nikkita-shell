// ~/nikkita-shell/dotfiles/quickshell/lock/LockContext.qml
//
// What every monitor of the lock screen shares: the password and the PAM check.
// PAM uses the `login` stack, so faillock applies and its message is shown as is.
// GreeterContext has the same properties, for the login screen.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: ctx

    property string buffer: ""
    // "" while typing, "checking", "fail", "max" (too many tries) or "error".
    property string state: ""
    property string message: ""         // what PAM said, when it was an error
    property bool leaving: false        // the password was right: the views fade out
    property date lockedAt: new Date()
    readonly property string user: Quickshell.env("USER") || ""
    // The real name from /etc/passwd, else the user name.
    property string name: user

    signal unlocked
    signal failed

    function reset() {
        lockedAt = new Date();
        buffer = "";
        state = "";
        message = "";
        leaving = false;
    }

    function type(text) {
        buffer = text;
        if (text !== "" && state !== "checking") {
            state = "";
            message = "";
        }
    }

    function submit() {
        if (buffer === "" || state === "checking" || leaving)
            return;
        state = "checking";
        message = "";
        if (!pam.start()) {
            state = "error";
            failed();
        }
    }

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (responseRequired)
                respond(ctx.buffer);
            else if (messageIsError)
                ctx.message = message;
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                ctx.state = "";
                ctx.leaving = true;
                ctx.unlocked();
                return;
            }
            ctx.buffer = "";
            ctx.state = result === PamResult.MaxTries ? "max" : result === PamResult.Failed ? "fail" : "error";
            ctx.failed();
        }
        onError: err => {
            ctx.buffer = "";
            ctx.state = "error";
            ctx.failed();
        }
    }

    Process {
        running: true
        command: ["getent", "passwd", ctx.user]
        stdout: StdioCollector {
            onStreamFinished: {
                const real = (text.split(":")[4] || "").split(",")[0].trim();
                if (real !== "")
                    ctx.name = real;
            }
        }
    }
}
