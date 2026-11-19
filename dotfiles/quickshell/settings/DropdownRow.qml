// ~/nikita-shell/dotfiles/quickshell/settings/DropdownRow.qml
// A setting picked from a list: the row shows the current choice, and a click
// unfolds the choices under it (the way Default apps does). `options`:
// [{ label, value, detail?, group? }]; with a single option there is nothing to
// unfold. Options that carry a `group` get its name as a heading over the first of
// them, so keep each group together. A long list has shorter rows.
import QtQuick
import qs.common

Column {
    id: drop

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property var options: []
    property var current
    property bool open: false
    signal picked(var value)

    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }
    readonly property var chosen: options.find(o => same(o.value, current)) ?? null
    readonly property bool compact: options.length > 8

    width: parent ? parent.width : 0

    // Escape folds the choices and keeps the focus on the row, not on a choice that is gone.
    Keys.onEscapePressed: ev => {
        if (open) {
            open = false;
            header.forceActiveFocus();
            ev.accepted = true;
        }
    }

    SettingRow {
        id: header
        divider: drop.Positioner.index > 0
        icon: drop.icon
        title: drop.title
        subtitle: drop.subtitle
        clickable: drop.options.length > 1
        onClicked: drop.open = !drop.open

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: drop.chosen ? drop.chosen.label : "—"
            font.weight: Font.Medium
        }
        Icon {
            visible: drop.options.length > 1
            anchors.verticalCenter: parent.verticalCenter
            name: "pan-down-symbolic"
            size: 14
            color: Theme.muted
            rotation: drop.open ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.msNormal } }
        }
    }

    Column {
        id: choices
        visible: drop.open
        x: Theme.spaceL
        width: parent.width - 2 * Theme.spaceL
        spacing: drop.compact ? Theme.spaceXxs : Theme.spaceXs
        bottomPadding: Theme.spaceM

        Repeater {
            model: drop.open ? drop.options : []

            Column {
                id: choice
                required property var modelData
                required property int index
                readonly property string group: modelData.group ?? ""
                readonly property bool heads: group !== "" && (index === 0 || (drop.options[index - 1].group ?? "") !== group)
                width: choices.width

                StyledText {
                    visible: choice.heads
                    leftPadding: Theme.spaceS
                    topPadding: choice.index > 0 ? Theme.spaceM : Theme.spaceXs
                    bottomPadding: Theme.spaceXs
                    text: choice.group
                    color: Theme.muted
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.DemiBold
                }
                ListRow {
                    width: choices.width
                    implicitHeight: drop.compact ? 34 : 44
                    title: choice.modelData.label
                    subtitle: choice.modelData.detail ?? ""
                    active: drop.same(choice.modelData.value, drop.current)
                    // Closing empties the model and takes this row, and the names
                    // it resolves, with it: hold on to them first.
                    onClicked: {
                        const d = drop, v = choice.modelData.value;
                        d.picked(v);
                        d.open = false;
                    }
                }
            }
        }
    }
}
