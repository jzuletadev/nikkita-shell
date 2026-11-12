// ~/nikkita-shell/dotfiles/quickshell/common/Tooltips.qml
//
// The desktop's one tooltip. Items ask through Tip.qml; the TooltipLayer of the
// item's window draws it. It waits a second; right after one hides the next comes
// almost at once, so a row of icons can be read by sliding along it.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: tips

    property Item target: null          // the item being explained (null = none)
    property string text: ""
    property string side: ""

    property Item pending: null
    property string pendingText: ""
    property string pendingSide: ""
    property double hiddenAt: 0

    readonly property int delay: 1000
    readonly property int warmDelay: 120
    readonly property int warmFor: 700  // after one hides, how long the next is "warm"

    function request(item, text, side) {
        if (!item || text === "")
            return;
        pending = item;
        pendingText = text;
        pendingSide = side;
        const warm = target !== null || Date.now() - hiddenAt < warmFor;
        timer.interval = warm ? warmDelay : delay;
        timer.restart();
    }

    // The pointer left, or pressed: no tooltip for this item.
    function cancel(item) {
        if (!item)
            return;
        if (pending === item) {
            pending = null;
            timer.stop();
        }
        if (target === item) {
            target = null;
            hiddenAt = Date.now();
        }
    }

    function update(item, text) {
        if (!item)
            return;
        if (pending === item)
            pendingText = text;
        if (target === item) {
            if (text === "")
                cancel(item);
            else
                tips.text = text;
        }
    }

    Timer {
        id: timer
        onTriggered: {
            if (!tips.pending)
                return;
            tips.text = tips.pendingText;
            tips.side = tips.pendingSide;
            tips.target = tips.pending;
            tips.pending = null;
        }
    }
}
