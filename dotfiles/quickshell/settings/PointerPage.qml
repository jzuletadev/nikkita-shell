// ~/nikita-shell/dotfiles/quickshell/settings/PointerPage.qml
// Mouse and touchpad: speed, scrolling, clicking, and what each touchpad gesture
// does. The touchpad parts show only where there is one. Hyprland owns all of it:
// services/HyprSettings.qml applies each change and reads the values back.
import QtQuick
import qs.common
import qs.services

Column {
    id: page
    spacing: Theme.spaceXl

    Component.onCompleted: HyprSettings.refresh()

    readonly property bool touchpad: HyprSettings.touchpads.length > 0

    // Sliders are 0-100. Speed: Hyprland's -1 to 1, the middle is its default.
    function speedToSlider(v) {
        return Math.round(((Number(v) || 0) + 1) * 50);
    }
    function sliderToSpeed(s) {
        return Math.round((s / 50 - 1) * 20) / 20;
    }
    function speedText(v) {
        const n = Number(v) || 0;
        return n === 0 ? "Default" : (n > 0 ? "+" : "") + n.toFixed(2);
    }
    // Scrolling: ×0.2 to ×3, in tenths.
    function factorToSlider(v) {
        return Math.round(((Number(v) || 1) - 0.2) / 0.028);
    }
    function sliderToFactor(s) {
        return Math.round((0.2 + s * 0.028) * 10) / 10;
    }
    function on(name) {
        return HyprSettings.value(name) === true;
    }

    HyprProblems {}

    // ---------------------------------------------------------------- mouse
    Section {
        title: "Mouse"
        SettingRow {
            icon: "input-mouse-symbolic"
            title: "Pointer speed"
            subtitle: "For mice" + (page.touchpad ? "; the touchpad has its own below." : ".")
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("sensitivity")
                onClicked: HyprSettings.setInput("sensitivity", undefined)
            }
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: page.speedToSlider(HyprSettings.value("sensitivity"))
                onMoved: v => HyprSettings.setInput("sensitivity", page.sliderToSpeed(v))
            }
            StyledText {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: page.speedText(HyprSettings.value("sensitivity"))
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
        SettingRow {
            title: "Acceleration"
            subtitle: "A fast move goes further than a slow one. Off, the pointer moves exactly as far as the mouse."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("accel_profile")
                onClicked: HyprSettings.setInput("accel_profile", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: HyprSettings.value("accel_profile") !== "flat"
                onToggled: HyprSettings.setInput("accel_profile", HyprSettings.value("accel_profile") === "flat" ? "adaptive" : "flat")
            }
        }
        SettingRow {
            title: "Scroll speed"
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("scroll_factor")
                onClicked: HyprSettings.setInput("scroll_factor", undefined)
            }
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: page.factorToSlider(HyprSettings.value("scroll_factor"))
                onMoved: v => HyprSettings.setInput("scroll_factor", page.sliderToFactor(v))
            }
            StyledText {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: "×" + (Number(HyprSettings.value("scroll_factor")) || 1).toFixed(1)
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
        SettingRow {
            title: "Natural scrolling"
            subtitle: "The page follows the wheel, as it does a finger on a touch screen."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("natural_scroll")
                onClicked: HyprSettings.setInput("natural_scroll", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.on("natural_scroll")
                onToggled: HyprSettings.setInput("natural_scroll", !page.on("natural_scroll"))
            }
        }
        SettingRow {
            title: "Left-handed"
            subtitle: "The right button is the main one."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("left_handed")
                onClicked: HyprSettings.setInput("left_handed", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.on("left_handed")
                onToggled: HyprSettings.setInput("left_handed", !page.on("left_handed"))
            }
        }
    }

    // -------------------------------------------------------------- touchpad
    Section {
        title: "Touchpad"
        visible: page.touchpad
        SettingRow {
            icon: "input-touchpad-symbolic"
            title: "Pointer speed"
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("touchpad.speed")
                onClicked: HyprSettings.setInput("touchpad.speed", undefined)
            }
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: page.speedToSlider(HyprSettings.value("touchpad.speed"))
                onMoved: v => HyprSettings.setInput("touchpad.speed", page.sliderToSpeed(v))
            }
            StyledText {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: page.speedText(HyprSettings.value("touchpad.speed"))
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
        SettingRow {
            title: "Tap to click"
            subtitle: "A light tap is a click; with two fingers, a right click."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("touchpad.tap_to_click")
                onClicked: HyprSettings.setInput("touchpad.tap_to_click", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.on("touchpad.tap_to_click")
                onToggled: HyprSettings.setInput("touchpad.tap_to_click", !page.on("touchpad.tap_to_click"))
            }
        }
        SettingRow {
            title: "Tap and drag"
            subtitle: "Tap, then touch again and move, to drag."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("touchpad.tap_and_drag")
                onClicked: HyprSettings.setInput("touchpad.tap_and_drag", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.on("touchpad.tap_and_drag")
                onToggled: HyprSettings.setInput("touchpad.tap_and_drag", !page.on("touchpad.tap_and_drag"))
            }
        }
        SettingRow {
            title: "Right click with two fingers"
            subtitle: "Pressing with two fingers is the right button, with three the middle one. Off, the bottom right corner is the right button."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("touchpad.clickfinger_behavior")
                onClicked: HyprSettings.setInput("touchpad.clickfinger_behavior", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.on("touchpad.clickfinger_behavior")
                onToggled: HyprSettings.setInput("touchpad.clickfinger_behavior", !page.on("touchpad.clickfinger_behavior"))
            }
        }
        SettingRow {
            title: "Natural scrolling"
            subtitle: "The page follows your fingers."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("touchpad.natural_scroll")
                onClicked: HyprSettings.setInput("touchpad.natural_scroll", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.on("touchpad.natural_scroll")
                onToggled: HyprSettings.setInput("touchpad.natural_scroll", !page.on("touchpad.natural_scroll"))
            }
        }
        SettingRow {
            title: "Scroll speed"
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("touchpad.scroll_factor")
                onClicked: HyprSettings.setInput("touchpad.scroll_factor", undefined)
            }
            HorizontalSlider {
                width: 220
                anchors.verticalCenter: parent.verticalCenter
                value: page.factorToSlider(HyprSettings.value("touchpad.scroll_factor"))
                onMoved: v => HyprSettings.setInput("touchpad.scroll_factor", page.sliderToFactor(v))
            }
            StyledText {
                width: 64
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: "×" + (Number(HyprSettings.value("touchpad.scroll_factor")) || 1).toFixed(1)
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.textSmall
            }
        }
        SettingRow {
            title: "Off while typing"
            subtitle: "So a palm on the touchpad doesn't move the pointer."
            ResetButton {
                anchors.verticalCenter: parent.verticalCenter
                changed: HyprSettings.changed("touchpad.disable_while_typing")
                onClicked: HyprSettings.setInput("touchpad.disable_while_typing", undefined)
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.on("touchpad.disable_while_typing")
                onToggled: HyprSettings.setInput("touchpad.disable_while_typing", !page.on("touchpad.disable_while_typing"))
            }
        }
    }

    // --------------------------------------------------------------- gestures
    // One dropdown per gesture, the choices grouped as hyprland.lua groups them;
    // one unfolded at a time. A pinch is named after the fingers: in brings them
    // together, out spreads them (hyprland.lua turns it into Hyprland's words).
    property string unfolded: ""         // "3left", the gesture being chosen
    readonly property var moves: [
        { direction: "left", title: "Swipe left" }, { direction: "right", title: "Swipe right" },
        { direction: "up", title: "Swipe up" }, { direction: "down", title: "Swipe down" },
        { direction: "pinchin", title: "Pinch in", subtitle: "Fingers together" },
        { direction: "pinchout", title: "Pinch out", subtitle: "Fingers apart" }
    ]
    // What follows the fingers along an axis is only for a swipe on that axis.
    function choices(direction) {
        const sideways = direction === "left" || direction === "right";
        const upright = direction === "up" || direction === "down";
        return [{ label: "Nothing", value: "" }].concat(HyprSettings.gestureActions
            .filter(a => a.swipe === "" || (a.swipe === "horizontal" && sideways) || (a.swipe === "vertical" && upright))
            .map(a => ({ label: a.title, value: a.id, group: a.group || "" })));
    }

    Repeater {
        model: page.touchpad ? [{ fingers: 3, title: "Gestures with three fingers" }, { fingers: 4, title: "Gestures with four fingers" }] : []

        Section {
            id: hand
            required property var modelData
            title: modelData.title
            note: modelData.fingers === 4 ? "With two fingers, scrolling and zooming belong to the app under them." : ""

            Repeater {
                model: page.moves

                DropdownRow {
                    id: move
                    required property var modelData
                    readonly property string key: hand.modelData.fingers + modelData.direction
                    readonly property string action: HyprSettings.gesture(hand.modelData.fingers, modelData.direction)
                    title: modelData.title
                    subtitle: HyprSettings.follows(action) ? "Both ways go together: it follows your fingers." : (modelData.subtitle ?? "")
                    options: page.choices(modelData.direction)
                    current: action
                    onPicked: v => HyprSettings.setGesture(hand.modelData.fingers, move.modelData.direction, v)
                    onOpenChanged: if (open) page.unfolded = key
                    Connections {
                        target: page
                        function onUnfoldedChanged() {
                            if (page.unfolded !== move.key)
                                move.open = false;
                        }
                    }
                }
            }
        }
    }

    // Every option on this page back to hyprland.lua's, in one go.
    readonly property var names: ["sensitivity", "accel_profile", "scroll_factor", "natural_scroll", "left_handed",
        "touchpad.speed", "touchpad.tap_to_click", "touchpad.tap_and_drag", "touchpad.clickfinger_behavior",
        "touchpad.natural_scroll", "touchpad.scroll_factor", "touchpad.disable_while_typing"]
    Section {
        visible: page.names.some(n => HyprSettings.changed(n))
        SettingRow {
            icon: "edit-undo-symbolic"
            title: "Back to the default mouse and touchpad settings"
            subtitle: "Speed, scrolling and clicking as they were. The gestures have their own button."
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset"
                onClicked: HyprSettings.resetInputs(page.names)
            }
        }
    }

    Section {
        visible: page.touchpad && Prefs.gestures !== null
        SettingRow {
            icon: "edit-undo-symbolic"
            title: "Back to the default gestures"
            subtitle: "The ones in dotfiles/hypr/hyprland.lua."
            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset"
                onClicked: {
                    page.unfolded = "";
                    HyprSettings.resetGestures();
                }
            }
        }
    }
}
