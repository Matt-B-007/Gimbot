// SPDX-License-Identifier: MIT
pragma Singleton
import QtQuick

// Colors, type and spacing for the whole app. Follows the system's light or
// dark setting (or the user's override) and can use the Plasma accent color.
// Every text color passes 4.5:1 on every surface in both themes, and button
// text on the accent too; tests/test_ui.cpp checks it.
QtObject {
    id: t

    // Set from Main.qml: 0 follow system, 1 dark, 2 light.
    property int mode: 0
    property bool useSystemAccent: false

    readonly property SystemPalette sys: SystemPalette { colorGroup: SystemPalette.Active }
    readonly property bool systemDark: sys.window.hslLightness < 0.5
    readonly property bool dark: mode === 1 ? true : mode === 2 ? false : systemDark

    // House standard v1.3: Gimbot's purple accent on the navy "hull" shared
    // by all five apps. If "Use the system accent color" is on, the Plasma
    // accent wins.
    readonly property color brand: dark ? "#c084fc" : "#7e22ce"
    readonly property color systemAccent: (sys.accent !== undefined && sys.accent !== null) ? sys.accent : sys.highlight
    readonly property color accent: useSystemAccent ? systemAccent : brand
    // Text on a filled accent button: dark ink in the dark theme, white in the
    // light theme (for a system accent: whichever suits its lightness).
    readonly property color inkDark: "#0c1016"
    readonly property color inkLight: "#ffffff"
    readonly property bool lightAccent: useSystemAccent ? systemAccent.hslLightness > 0.6 : dark
    readonly property color accentInk: lightAccent ? inkDark : inkLight
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.16 : 0.12)
    // Accent-colored text and links. The brand colors already pass 4.5:1.
    readonly property color accentText: useSystemAccent ? (dark ? Qt.lighter(accent, 1.25) : Qt.darker(accent, 1.15)) : brand
    // Family details: the card edge, corner brackets and the one glow.
    readonly property color cardEdge: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color glow: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
    // The camera's own status light is blue while it tracks you; Gimbot's
    // tracking dot and frame match it (the same in both themes, on video).
    readonly property color ledBlue: "#38bdf8"

    // The hull.
    readonly property color bg: dark ? "#0c1016" : "#f5f7fa"
    readonly property color sidebar: dark ? "#080b10" : "#edf1f5"
    readonly property color surface: dark ? "#131922" : "#ffffff"   // cards
    readonly property color surface2: dark ? "#1a212c" : "#f1f4f8"  // controls
    readonly property color hover: dark ? "#212a37" : "#e9eef4"
    readonly property color sunken: sidebar                         // wells and tracks
    readonly property color video: "#05070a"
    readonly property color border: dark ? "#263040" : "#dce3eb"
    readonly property color borderStrong: dark ? "#364459" : "#c3ceda"
    readonly property color text: dark ? "#e8edf4" : "#0f1620"
    readonly property color textMuted: dark ? "#9aa6b8" : "#556274"
    readonly property color textFaint: textMuted // the standard has two text colors
    readonly property color danger: dark ? "#f87171" : "#b91c1c"
    readonly property color success: dark ? "#6ee7b7" : "#047857"
    readonly property color warning: dark ? "#fbbf24" : "#975a06"
    readonly property color overlay: Qt.rgba(0.047, 0.063, 0.086, 0.8) // chips on top of video
    readonly property color scrim: Qt.rgba(0.02, 0.03, 0.05, dark ? 0.6 : 0.35)

    readonly property string font: interLoader.status === FontLoader.Ready ? "Inter" : Qt.application.font.family // qmllint disable missing-property
    readonly property int fontSize: 14
    readonly property int small: 12
    readonly property int large: 16
    readonly property int title: 22

    readonly property int radiusSm: 8
    readonly property int radius: 12
    readonly property int radiusLg: 16
    readonly property int gap: 12
    readonly property int pad: 16

    readonly property int fast: 120
    readonly property int normal: 200

    readonly property FontLoader interLoader: FontLoader { source: "fonts/Inter-Regular.ttf" }
    readonly property FontLoader interMedium: FontLoader { source: "fonts/Inter-Medium.ttf" }
    readonly property FontLoader interSemi: FontLoader { source: "fonts/Inter-SemiBold.ttf" }
    readonly property FontLoader interBold: FontLoader { source: "fonts/Inter-Bold.ttf" }
    // Large titles only (house standard v1.3); body text stays Inter.
    readonly property FontLoader displayLoader: FontLoader { source: "fonts/SpaceGrotesk-SemiBold.ttf" }
    readonly property string displayFont: displayLoader.status === FontLoader.Ready ? displayLoader.name : font
}
