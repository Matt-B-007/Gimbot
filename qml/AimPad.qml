// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import Gimbot

// The circle aim pad: drag the knob any way and the camera moves that way,
// slowly near the middle and fast at the edge. Let go and it springs back
// and stops. The arrow keys are the page's own (the same eased movement
// wherever the focus is); Home recentres.
Control {
    id: root
    property bool usable: true
    readonly property real radius: width / 2
    readonly property real knobSize: 44
    property real knobX: 0 // knob offset from the centre, pixels
    property real knobY: 0
    property bool dragging: false

    implicitWidth: 140
    implicitHeight: 140
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.role: Accessible.Dial
    Accessible.name: qsTr("Aim the camera: drag in any direction, or hold the arrow keys")

    function steer() {
        // Past the edge the knob stays on the rim; the speed is full anyway.
        const len = Math.hypot(knobX, knobY), max = radius - knobSize / 2
        if (len > max) { knobX = knobX / len * max; knobY = knobY / len * max }
        if (usable) Cam.movePad(knobX, knobY, max)
    }
    function release() {
        dragging = false
        knobX = 0
        knobY = 0
        Cam.stopMove()
    }

    background: Rectangle {
        radius: width / 2
        color: Theme.surface2
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? Theme.accent : Theme.border
        Rectangle { // guide ring
            anchors.centerIn: parent
            width: parent.width - 44
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Theme.borderStrong
            opacity: 0.7
        }
        Repeater { // a small arrow on each side
            model: [{ x: 0.5, y: 0.06, r: 0 }, { x: 0.94, y: 0.5, r: 90 }, { x: 0.5, y: 0.94, r: 180 }, { x: 0.06, y: 0.5, r: 270 }]
            delegate: Icon {
                required property var modelData
                x: parent.width * modelData.x - 6
                y: parent.height * modelData.y - 6
                name: "chevron-up"
                size: 12
                rotation: modelData.r
                color: Theme.textMuted
            }
        }
        Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.borderStrong }
    }

    contentItem: Item {
        Rectangle { // which way it's pulling
            visible: root.dragging
            x: parent.width / 2
            y: parent.height / 2 - 1
            width: Math.hypot(root.knobX, root.knobY)
            height: 2
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
            transformOrigin: Item.Left
            rotation: Math.atan2(root.knobY, root.knobX) * 180 / Math.PI
        }
        Rectangle { // the knob
            width: root.knobSize
            height: root.knobSize
            radius: width / 2
            x: parent.width / 2 + root.knobX - width / 2
            y: parent.height / 2 + root.knobY - height / 2
            color: root.usable ? Theme.accent : Theme.borderStrong
            Glow { radius: parent.radius; on: root.dragging }
            Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            Behavior on y { enabled: !root.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.usable
        preventStealing: true // or the page's scrolling takes an up-and-down drag
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (m) => { root.forceActiveFocus(); root.dragging = true; root.knobX = m.x - width / 2; root.knobY = m.y - height / 2; root.steer() }
        onPositionChanged: (m) => { if (!root.dragging) return; root.knobX = m.x - width / 2; root.knobY = m.y - height / 2; root.steer() }
        onReleased: root.release()
        onCanceled: root.release()
    }

    Keys.onPressed: (e) => {
        if (root.usable && e.key === Qt.Key_Home) { Cam.recenter(); e.accepted = true }
    }
}
