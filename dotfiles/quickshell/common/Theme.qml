// ~/nikita-shell/dotfiles/quickshell/common/Theme.qml
//
// The desktop colors: two gray themes, dark and light. Red and amber only warn
// (recording, danger, high load). The theme file (theme-manager.sh) is watched and
// colors change live, with a transition.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: theme

    property bool dark: true

    // The two bases. ThemePanel.qml also uses them for its samples.
    readonly property var darkBase: ({ bg: "#141414", fg: "#e6e6e6", bad: "#e5534b", warn: "#d9a441" })
    readonly property var lightBase: ({ bg: "#f2f2f2", fg: "#1a1a1a", bad: "#c62f2a", warn: "#a86a00" })
    readonly property var base: dark ? darkBase : lightBase

    // ---- colors (animated when the theme changes) ----
    property color bg: base.bg
    property color fg: base.fg
    property color bad: base.bad
    property color warn: base.warn

    Behavior on bg { ColorAnimation { duration: theme.msSlow } }
    Behavior on fg { ColorAnimation { duration: theme.msSlow } }
    Behavior on bad { ColorAnimation { duration: theme.msSlow } }
    Behavior on warn { ColorAnimation { duration: theme.msSlow } }

    // Everything else is a mix of bg and fg, so it animates along with them.
    readonly property color surface: mix(bg, fg, 0.06)
    readonly property color overlay: mix(bg, fg, 0.14)
    // Text: `muted` for secondary lines, `dim` for notes and hints. Both pass 4.5:1 on
    // `bg` and on `card`, in both themes. The light one needs less of `bg`: mid grays
    // read fainter on a light ground.
    readonly property color muted: mix(fg, bg, dark ? 0.28 : 0.24)
    readonly property color dim: mix(fg, bg, dark ? 0.44 : 0.34)
    // Never for text: scroll bars, a muted slider, an empty workspace's dot.
    readonly property color faint: mix(fg, bg, 0.62)
    readonly property color accent: fg          // no color: highlighted things use the text tone
    readonly property color accentText: bg
    readonly property color info: muted

    // ---- derived ----
    readonly property color panel: alpha(bg, Prefs.panelOpacity)   // Settings → Appearance
    // Translucent, like `control`: a step above whatever is under them. Opaque, a card
    // vanished on a panel lit from behind by a bright window.
    readonly property color card: alpha(fg, 0.07)            // cards inside a panel
    readonly property color cardHover: alpha(fg, 0.13)       // hover over a card
    // A button at rest: translucent, so it is one step above whatever it sits on
    // (a panel or a card). An opaque `card` vanished on a card.
    readonly property color control: alpha(fg, 0.08)
    readonly property color accentSoft: mix(bg, accent, 0.22)
    readonly property color divider: alpha(fg, 0.08)
    // The edge of what floats over a picture (the lock card, your picture's frame):
    // the opposite tone, stronger in the light theme, where a wallpaper turns gray.
    readonly property color rim: alpha(fg, dark ? 0.28 : 0.42)
    // A panel's edge and the shadow around it (EdgePanel): what keeps a panel apart
    // from a window or wallpaper of its own tone. The shadow is laid down in passes.
    readonly property color panelRim: alpha(fg, dark ? 0.13 : 0.17)
    readonly property color panelShadow: Qt.rgba(0, 0, 0, dark ? 0.034 : 0.022)

    // ---- states (the same everywhere) ----
    // Filled with the text tone (`accent`) means ON: a toggle that is on, the chosen
    // option. The pointer never looks like that: a hovered button gets one step
    // lighter with a thin ring and keeps its ink. On and hovered dims a little; a
    // dangerous one turns red. List rows only take `cardHover`.
    readonly property color hoverFill: mix(bg, fg, 0.17)
    readonly property color hoverRing: alpha(fg, 0.30)
    readonly property color activeHover: mix(accent, bg, 0.18)
    // On red, the light one of the two, in both themes.
    readonly property color badInk: dark ? fg : bg

    // ---- typography ----
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string monoFamily: "JetBrainsMono Nerd Font"
    // Nerd Font icons (Glyph.qml). The "Propo" cut: in the plain one an icon is
    // wider than the cell it advances, so a centered one sits 2 px to the right.
    readonly property string glyphFamily: "JetBrainsMono Nerd Font Propo"
    // BigClock: Oswald from assets/fonts, loaded here rather than installed.
    readonly property string clockFamily: clockFont.status === FontLoader.Ready ? clockFont.name : fontFamily
    FontLoader {
        id: clockFont
        source: "file://" + Paths.repo + "/assets/fonts/Oswald-Variable.ttf"
    }
    // ---- type scale: every font size comes from here ----
    readonly property int textCaption: 10    // times, counts, axis labels
    readonly property int textSmall: 11      // subtitles, secondary lines
    readonly property int textLabel: 12      // buttons, section labels, tooltips
    readonly property int textBody: 13       // the default (StyledText)
    readonly property int textLarge: 14      // row titles in Settings, text fields
    readonly property int textTitle: 16      // card titles
    readonly property int textHeading: 20    // a panel's big figure, dialog titles
    readonly property int textDisplay: 28    // page titles, big numbers
    readonly property int textHero: 44       // the one number a page is about

    // ---- spacing: a 4 px grid (2 only between stacked lines of text) ----
    readonly property int spaceXxs: 2
    readonly property int spaceXs: 4
    readonly property int spaceS: 8
    readonly property int spaceM: 12
    readonly property int spaceL: 16
    readonly property int spaceXl: 24

    // ---- corner radius: nested shapes go one step down ----
    // Anything that is just round (pills, dots, thin bars) uses height / 2.
    readonly property int radiusS: 8         // small pieces: covers, key caps, tooltips
    readonly property int radiusM: 12        // rows, tiles, text fields; windows (hyprland.lua)
    readonly property int radiusL: 16        // cards and panels
    readonly property int radiusXl: 24       // dialogs and the big cards

    // ---- the hexagon: it stands on a point, as in the logo ----
    readonly property real hexRatio: 0.905   // its width / height in the logo

    // ---- motion ----
    // Material 3 "expressive": the enter curve overshoots a little.
    readonly property var curveEnter: [0.38, 1.21, 0.22, 1.0, 1, 1]
    readonly property var curveExit: [0.3, 0.0, 0.8, 0.15, 1, 1]
    readonly property var curveSmooth: [0.2, 0.0, 0.0, 1.0, 1, 1]
    // Choreographies (the launcher opening, the lock's shake, gauges filling) keep
    // their own timings, through ms(); every plain transition uses one of these.
    // Endless loops (a spinner) stay out of ms(): at 0 they would spin every frame.
    // Every animation's length, in one place; Settings → Appearance → Reduce animations
    // makes it 0 (everything lands at once).
    readonly property real motionScale: Prefs.reduceMotion ? 0 : 1
    function ms(duration) {
        return Math.round(duration * motionScale);
    }
    readonly property int msFast: ms(150)    // feedback: hover, press, a color
    readonly property int msNormal: ms(250)  // fades, moves, sizes; a panel leaving
    readonly property int msSlow: ms(480)    // a panel arriving, the theme crossfade

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a, b, t) {
        t = Math.max(0, Math.min(1, t));
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    FileView {
        id: file
        path: Paths.state + "/theme"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            theme.dark = text().trim() !== "light";
            Paths.syncGreeter();
        }
        // If it doesn't exist it is created as dark and read again: FileView only
        // watches a file that already existed when it was read (tested). The login
        // screen only reads.
        onLoadFailed: if (!Paths.greeter) setText("dark\n")
        onSaved: reload()
    }
}
