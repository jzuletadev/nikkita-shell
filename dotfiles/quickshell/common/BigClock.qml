// ~/nikkita-shell/dotfiles/quickshell/common/BigClock.qml
//
// The big clock (dashboard, lock screen): big hours; beside them the minutes at
// half size over a tag, AM/PM (12 h) or the seconds (24 h). For the seconds to move,
// `date` must tick every second (a SystemClock with Seconds).
import QtQuick
import qs.common

Item {
    id: c

    property date date: new Date()
    property int size: 110              // the hours; the rest follows
    property int weight: Font.DemiBold
    property color color: Theme.fg

    readonly property int hours: date.getHours()
    readonly property string hh: Prefs.clock24h ? String(hours).padStart(2, "0") : String(hours % 12 || 12)
    readonly property string mm: String(date.getMinutes()).padStart(2, "0")
    readonly property string tag: Prefs.clock24h ? String(date.getSeconds()).padStart(2, "0") : (hours < 12 ? "AM" : "PM")

    implicitWidth: row.width
    implicitHeight: row.height

    Row {
        id: row
        spacing: Math.round(c.size * 0.07)

        Row {
            id: hoursRow
            RollingDigit { visible: c.hh.length === 2; digit: c.hh.length === 2 ? c.hh[0] : "0"; size: c.size; weight: c.weight; color: c.color }
            RollingDigit { digit: c.hh[c.hh.length - 1]; size: c.size; weight: c.weight; color: c.color }
        }

        Column {
            id: side
            spacing: Math.round(c.size * 0.07)

            Row {
                id: minutesRow
                RollingDigit { digit: c.mm[0]; size: Math.round(c.size * 0.5); weight: c.weight; color: c.color }
                RollingDigit { digit: c.mm[1]; size: Math.round(c.size * 0.5); weight: c.weight; color: c.color }
            }
            Rectangle {
                width: minutesRow.width
                height: Math.max(12, hoursRow.height - minutesRow.height - side.spacing)
                radius: Math.round(height * 0.28)
                color: Theme.alpha(c.color, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: c.tag
                    color: c.color
                    font.family: Theme.clockFamily
                    font.pixelSize: Math.round(parent.height * 0.62)
                    font.weight: c.weight
                    font.variableAxes: { "wght": c.weight }
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
