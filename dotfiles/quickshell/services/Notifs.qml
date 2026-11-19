// ~/nikita-shell/dotfiles/quickshell/services/Notifs.qml
//
// The notification server (drawn by Toasts.qml).
//
//   toasts    the ones on screen now, live objects (with their actions)
//   history   flat copy of all of them, newest first; saved to disk
//
// A toast that times out is CLOSED (expire): `notify-send --action` waits for that.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.common

Singleton {
    id: notifs

    property var toasts: []
    property var history: []
    readonly property int limit: 40
    readonly property string file: Paths.state + "/notifications.json"

    function removeToast(n) {
        toasts = toasts.filter(a => a !== n);
    }

    function expire(n) {
        removeToast(n);
        if (n && n.tracked)
            n.expire();
    }

    function dismiss(n) {
        removeToast(n);
        if (n && n.tracked)
            n.dismiss();
    }

    function removeEntry(key) {
        history = history.filter(e => e.key !== key);
        save();
    }

    // Gone at once, from the disk too; for a few seconds it can come back (Undo).
    property var undoable: null
    function clear() {
        undoable = history;
        history = [];
        save();
        undoTimer.restart();
    }
    function undo() {
        if (undoable === null)
            return;
        history = history.concat(undoable).slice(0, limit);
        undoable = null;
        save();
    }
    Timer {
        id: undoTimer
        interval: 8000
        onTriggered: notifs.undoable = null
    }

    // A desktop notice (Commands.notice).
    function isNotice(n) {
        return !!n && !!n.hints && n.hints["x-nikita-notice"] !== undefined;
    }

    // The notification behind a history entry, while it is still on screen.
    function liveFor(entry) {
        return toasts.find(n => n.id === entry.nid) ?? null;
    }
    function defaultAction(n) {
        return n.actions.find(a => a.identifier === "default") ?? (n.actions.length === 1 ? n.actions[0] : null);
    }

    // The app an entry came from, if one is installed. The desktop's own notices
    // have none.
    function appFor(entry) {
        if (entry.app === "Desktop" || entry.app === "Wallpaper")
            return null;
        return (entry.desktop ? DesktopEntries.byId(entry.desktop) : null)
            ?? (entry.app ? DesktopEntries.heuristicLookup(entry.app) : null);
    }
    // Back to its window, or opens it. False when there is no app to go to.
    function openApp(entry) {
        const app = appFor(entry);
        if (!app)
            return false;
        const open = Hyprland.toplevels.values.find(t => {
            const id = (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject.class) || "";
            return id !== "" && DesktopEntries.heuristicLookup(id) === app;
        });
        if (open)
            Background.raise(open);
        else
            Commands.launchEntry(app, "Opening " + app.name);
        return true;
    }

    function save() {
        store.setText(JSON.stringify(history));
    }

    function flatten(n) {
        const img = n.image || "";
        return {
            key: n.id + "-" + Date.now(),
            nid: n.id,
            app: n.appName || "",
            desktop: n.desktopEntry || "",
            // Sent as a theme icon by name, it is the app's icon as far as the history goes.
            icon: n.appIcon || (img.startsWith("image://icon/") ? img.slice(13) : ""),
            // Only file images outlive the notification.
            image: (img.startsWith("/") || img.startsWith("file://")) ? img : "",
            summary: n.summary || "",
            body: n.body || "",
            time: Date.now(),
            critical: n.urgency === NotificationUrgency.Critical
        };
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            // Transient ones ("done", "set") show as a toast but aren't kept.
            if (!n.transient) {
                const e = notifs.flatten(n);
                // One that replaces another (same id) updates its entry instead of adding one.
                notifs.history = [e].concat(notifs.history.filter(h => h.nid !== n.id || Date.now() - h.time > 3600000)).slice(0, notifs.limit);
                notifs.save();
            }
            n.closed.connect(() => notifs.removeToast(n));
            // One notice at a time: the newest says what is true now.
            if (notifs.isNotice(n))
                for (const old of notifs.toasts.filter(a => notifs.isNotice(a)))
                    notifs.dismiss(old);
            if (ShellState.doNotDisturb && n.urgency !== NotificationUrgency.Critical) {
                n.expire();
                return;
            }
            notifs.toasts = [n].concat(notifs.toasts.filter(a => a !== n));
        }
    }

    FileView {
        id: store
        path: notifs.file
        printErrors: false
        onLoaded: {
            try {
                const v = JSON.parse(text());
                if (Array.isArray(v))
                    notifs.history = v.slice(0, notifs.limit);
            } catch (e) {
                console.warn("notifs: unreadable history, starting from scratch");
            }
        }
    }
}
