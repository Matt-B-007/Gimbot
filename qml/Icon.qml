import QtQuick
import QtQuick.Shapes

// Line icons drawn from SVG paths on a 24-unit grid, colored by `color`.
Item {
    id: root
    property string name: ""
    property color color: Theme.text
    property real size: 18
    property real stroke: 2

    implicitWidth: size
    implicitHeight: size

    readonly property var paths: ({
        "moon": "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z",
        "gear": "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z",
        "search": "M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14z M20 20l-3.5-3.5",
        "chevron-down": "M6 9l6 6 6-6",
        "undo": "M9 14L4 9l5-5 M4 9h10.5a5.5 5.5 0 0 1 0 11H11",
        "help": "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3 M12 17h.01",
        "pause": "M8 5v14 M16 5v14",
        "move": "M5 9l-3 3 3 3 M9 5l3-3 3 3 M15 19l-3 3-3-3 M19 9l3 3-3 3 M2 12h20 M12 2v20",
        "chevron-up": "M6 15l6-6 6 6",
        "chevron-left": "M15 6l-6 6 6 6",
        "chevron-right": "M9 6l6 6-6 6",
        "plus": "M12 5v14 M5 12h14",
        "x": "M6 6l12 12 M18 6L6 18",
        "check": "M5 12.5l4.5 4.5L19 7.5",
        "target": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
        "crosshair": "M12 2v4 M12 18v4 M2 12h4 M18 12h4 M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10z",
        "camera": "M7 3h10a4 4 0 0 1 4 4v5a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V7a4 4 0 0 1 4-4z M12 12.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M9 21h6 M12 16v5",
        "bug": "M8 10a4 4 0 0 1 8 0v4a4 4 0 0 1-8 0z M12 10v8 M4 12h4 M16 12h4 M5 7l3 2 M19 7l-3 2 M5 18l3-2 M19 18l-3-2 M10 6l-1-2.5 M14 6l1-2.5",
        "info": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 11v5 M12 7.6v.2",
        "dots": "M5 12h.01 M12 12h.01 M19 12h.01",
        "grid": "M3 9h18 M3 15h18 M9 3v18 M15 3v18",
        "eye": "M2 12c1.5-3.5 5.5-7 10-7s8.5 3.5 10 7c-1.5 3.5-5.5 7-10 7S3.5 15.5 2 12z M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
        "eye-off": "M3 3l18 18 M10.6 5.1A10 10 0 0 1 12 5c4.5 0 8.5 3.5 10 7a14 14 0 0 1-2.7 3.7 M6.6 6.6C4.5 8 2.9 10 2 12c1.5 3.5 5.5 7 10 7 1.8 0 3.4-.5 4.8-1.3 M9.9 9.9a3 3 0 0 0 4.2 4.2",
        "download": "M12 4v11 M7 10l5 5 5-5 M5 20h14",
        "upload": "M12 20V9 M7 14l5-5 5 5 M5 4h14",
        "folder": "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
        "copy": "M9 9h11v11H9z M5 15H4V4h11v1",
        "external": "M14 4h6v6 M20 4l-9 9 M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5",
        "refresh": "M20 11a8 8 0 1 0-2.3 5.7 M20 4v7h-7",
        "trash": "M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13",
        "edit": "M4 20h4L19 9l-4-4L4 16z",
        "person": "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 21a8 8 0 0 1 16 0",
        "keyboard": "M3 6h18v12H3z M7 10h.01 M11 10h.01 M15 10h.01 M7 14h10",
        "sliders": "M4 6h9 M17 6h3 M4 12h3 M11 12h9 M4 18h11 M19 18h1 M15 4v4 M9 10v4 M17 16v4",
        "power": "M12 3v8 M6.3 6.3a8 8 0 1 0 11.4 0",
        "sun": "M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M12 2v2 M12 20v2 M4.9 4.9l1.4 1.4 M17.7 17.7l1.4 1.4 M2 12h2 M20 12h2 M4.9 19.1l1.4-1.4 M17.7 6.3l1.4-1.4",
        "mic": "M12 3a3 3 0 0 1 3 3v6a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z M5 11a7 7 0 0 0 14 0 M12 18v3",
        "hand": "M8 13V5.5a1.5 1.5 0 0 1 3 0V11 M11 10V4.5a1.5 1.5 0 0 1 3 0V11 M14 10V5.5a1.5 1.5 0 0 1 3 0V13 M17 9.5a1.5 1.5 0 0 1 3 0V14a7 7 0 0 1-7 7h-1a7 7 0 0 1-5.6-2.8L3.8 15a1.6 1.6 0 0 1 2.5-2L8 15",
        "area": "M4 8V5a1 1 0 0 1 1-1h3 M16 4h3a1 1 0 0 1 1 1v3 M20 16v3a1 1 0 0 1-1 1h-3 M8 20H5a1 1 0 0 1-1-1v-3 M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z",
        "play": "M7 4l13 8-13 8z",
        "layers": "M12 3l9 5-9 5-9-5z M3 13l9 5 9-5",
        "zap": "M13 2L4 14h7l-1 8 9-12h-7z",
        "alert": "M12 3l10 18H2z M12 10v4 M12 17.5v.2"
    })

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        // Render into a texture: smooth edges on the GPU, and correct
        // clipping inside scroll areas.
        layer.enabled: root.visible // re-rendered when shown, so color changes made while hidden appear
        layer.samples: 4
        layer.smooth: true
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.paths[root.name] || "" }
        }
    }
}
