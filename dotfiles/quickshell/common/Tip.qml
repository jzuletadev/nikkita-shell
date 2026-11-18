// ~/nikita-shell/dotfiles/quickshell/common/Tip.qml
//
// A tooltip for what takes the pointer: declare it inside that item.
//
//     MouseArea { ...; Tip { text: "Wi-Fi\nRight click: settings" } }
//
// The first line is the name, the rest is shown dimmer. `side` is "" (above, or
// below without room), "left" or "right". A pointer warped by `hl.dsp.cursor.move`
// enters and leaves at once: test it with a real mouse.
import QtQuick
import qs.common

HoverHandler {
    id: tip

    property string text: ""
    property string side: ""

    onHoveredChanged: {
        if (hovered)
            Tooltips.request(tip.parent, text, side);
        else
            Tooltips.cancel(tip.parent);
    }
    onTextChanged: Tooltips.update(tip.parent, text)
    // Gone while shown (a panel rebuilt, Settings closed): take the tooltip with it.
    Component.onDestruction: Tooltips.cancel(tip.parent)
}
