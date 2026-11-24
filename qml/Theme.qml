pragma Singleton
import QtQuick

// Colors, type and spacing for the whole app. Follows the system's light or
// dark setting (or the user's override) and can use the Plasma accent color.
QtObject {
    id: t

    // Set from Main.qml: 0 follow system, 1 dark, 2 light.
    property int mode: 0
    property bool useSystemAccent: false

    readonly property SystemPalette sys: SystemPalette { colorGroup: SystemPalette.Active }
    readonly property bool systemDark: sys.window.hslLightness < 0.5
    readonly property bool dark: mode === 1 ? true : mode === 2 ? false : systemDark

    readonly property color brand: dark ? "#8b9cff" : "#4c5bd4"
    readonly property color systemAccent: (sys.accent !== undefined && sys.accent !== null) ? sys.accent : sys.highlight
    readonly property color accent: useSystemAccent ? systemAccent : brand
    // Text on an accent background: dark on light accents, white on dark ones.
    readonly property color inkDark: "#0e0f11"
    readonly property color inkLight: "#ffffff"
    readonly property bool lightAccent: useSystemAccent ? systemAccent.hslLightness > 0.6 : dark
    readonly property color accentInk: lightAccent ? inkDark : inkLight
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.16 : 0.12)
    readonly property color accentText: dark ? Qt.lighter(accent, 1.25) : Qt.darker(accent, 1.15)

    readonly property color bg: dark ? "#0e0f11" : "#f4f5f7"
    readonly property color surface: dark ? "#17191c" : "#ffffff"
    readonly property color surface2: dark ? "#1f2226" : "#eef0f3"
    readonly property color sunken: dark ? "#0b0c0e" : "#e7e9ed"
    readonly property color video: "#050506"
    readonly property color border: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color borderStrong: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color text: dark ? "#f2f3f5" : "#14161a"
    readonly property color textMuted: dark ? "#9aa0a8" : "#596069"
    readonly property color textFaint: dark ? "#6f757d" : "#858b94"
    readonly property color danger: dark ? "#ff8a80" : "#c62828"
    readonly property color success: dark ? "#4ade80" : "#1f9d55"
    readonly property color warning: dark ? "#f0b45c" : "#a8660b"
    readonly property color overlay: Qt.rgba(0.055, 0.06, 0.067, 0.78) // chips on top of video
    readonly property color scrim: Qt.rgba(0, 0, 0, dark ? 0.55 : 0.35)

    readonly property string font: interLoader.status === FontLoader.Ready ? "Inter" : Qt.application.font.family
    readonly property int fontSize: 14
    readonly property int small: 12
    readonly property int large: 16
    readonly property int title: 22

    readonly property int radiusSm: 8
    readonly property int radius: 12
    readonly property int radiusLg: 18
    readonly property int gap: 12
    readonly property int pad: 16

    readonly property int fast: 120
    readonly property int normal: 200

    readonly property FontLoader interLoader: FontLoader { source: "fonts/Inter-Regular.ttf" }
    readonly property FontLoader interMedium: FontLoader { source: "fonts/Inter-Medium.ttf" }
    readonly property FontLoader interSemi: FontLoader { source: "fonts/Inter-SemiBold.ttf" }
    readonly property FontLoader interBold: FontLoader { source: "fonts/Inter-Bold.ttf" }
}
