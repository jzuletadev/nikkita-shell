// ~/nikita-shell/dotfiles/quickshell/common/SlideMark.qml
//
// The fill that says "this one is chosen", sliding from the option that had it to the
// new one instead of jumping. Put it behind a Row of options (declare it before the
// Row), name the Row as `host` and the chosen option as `target`; the options that
// are carried this way don't paint their own chosen fill (PillButton `carried`).
// The first placement doesn't animate: it appears where it belongs.
import QtQuick
import qs.common

Rectangle {
    id: mark

    property Item host: null
    property var target: null           // an Item, as `var` for its radius, which not every Item has
    property bool settled: false

    visible: target !== null
    color: Theme.accent
    radius: target ? target.radius ?? height / 2 : 0
    x: target && host ? host.x + target.x : 0
    y: target && host ? host.y + target.y : 0
    width: target ? target.width : 0
    height: target ? target.height : 0

    onTargetChanged: if (target && !settled) Qt.callLater(() => settled = true)

    Behavior on x { enabled: mark.settled; NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter } }
    Behavior on y { enabled: mark.settled; NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter } }
    Behavior on width { enabled: mark.settled; NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter } }
    Behavior on height { enabled: mark.settled; NumberAnimation { duration: Theme.msNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEnter } }
}
