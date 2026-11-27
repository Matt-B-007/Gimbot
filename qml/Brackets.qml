// SPDX-License-Identifier: MIT
import QtQuick

// Small accent corner brackets that mark the focused or active card (the
// family detail, after Stream Preflight). Fill the card with it.
Item {
    id: root
    property real arm: 12
    property real thickness: 2
    property real inset: 5
    property color color: Theme.accent
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool atRight: index === 1 || index === 3
            readonly property bool atBottom: index >= 2
            x: atRight ? root.width - root.inset - root.arm : root.inset
            y: atBottom ? root.height - root.inset - root.arm : root.inset
            width: root.arm
            height: root.arm
            Rectangle { // across
                width: root.arm; height: root.thickness; radius: root.thickness / 2
                y: parent.atBottom ? root.arm - root.thickness : 0
                color: root.color
            }
            Rectangle { // down
                width: root.thickness; height: root.arm; radius: root.thickness / 2
                x: parent.atRight ? root.arm - root.thickness : 0
                color: root.color
            }
        }
    }
}
