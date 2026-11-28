// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick

// A soft accent glow (about 0 0 12px at 35%) behind one element: the single
// primary action on a screen, or what has keyboard focus. Drawn with a few
// rounded rings rather than a blur, so it costs nothing. Put it first inside
// the element and set `radius` to match.
Item {
    id: root
    property real radius: Theme.radiusSm
    property color color: Theme.glow
    property bool on: true
    anchors.fill: parent
    z: -1
    visible: opacity > 0
    opacity: on ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.normal } }

    Repeater {
        model: 4 // 4 rings, 3 px apart: about 12 px of falloff
        Rectangle {
            required property int index
            readonly property real spread: (index + 1) * 3
            x: -spread
            y: -spread
            width: root.width + spread * 2
            height: root.height + spread * 2
            radius: root.radius + spread
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.color.a * (0.55 - index * 0.12))
        }
    }
}
