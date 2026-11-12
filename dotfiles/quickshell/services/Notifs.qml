// ~/nikkita-shell/dotfiles/quickshell/services/Notifs.qml
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

    function clear() {
        history = [];
        save();
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
            icon: n.appIcon || "",
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
