// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import Gimbot

// Zone tracking, drawn on the picture: the area is a purple box with corner
// handles, and everything outside it is dimmed. Dragging a corner moves the
// two edges that meet there; they are sent to the camera when you let go, and
// the other edges are left exactly as they were. A corner that lies outside
// the picture waits at the picture's edge, so an edge can always be pulled
// into view. With the keyboard: Tab to a corner, arrow keys move it a degree
// at a time. The zone is kept in the camera's own angles, so the box follows
// the picture as the camera turns and zooms.
Item {
    id: root
    // Where the zone is in the picture (0..1; may be beyond the edges).
    readonly property rect zone: {
        // Mention what the mapping depends on so this updates with it.
        void (Cam.rawYaw + Cam.rawPitch + Cam.values.fov + Cam.values.zoom + Cam.values.mirrored)
        const a = Cam.pictureFromAngles(Cam.values.zoneYawMin, Cam.values.zonePitchMin)
        const b = Cam.pictureFromAngles(Cam.values.zoneYawMax, Cam.values.zonePitchMax)
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y))
    }
    property bool dragging: false
    property real dl: 0 // the box while dragging
    property real dt: 0
    property real dr: 1
    property real db: 1
    readonly property real l: dragging ? dl : zone.x
    readonly property real t: dragging ? dt : zone.y
    readonly property real r: dragging ? dr : zone.x + zone.width
    readonly property real b: dragging ? db : zone.y + zone.height

    // Which sides the drag has moved; only those are sent.
    property bool movedL: false
    property bool movedT: false
    property bool movedR: false
    property bool movedB: false
    function commit() {
        if (movedL || movedT || movedR || movedB) Cam.setZoneFromPicture(dl, dt, dr, db, movedL, movedT, movedR, movedB)
        dragging = false
    }
    // One degree with the keyboard. dx and dy are on screen: right and down
    // are positive. Which camera angle that is depends on mirroring and flips.
    function nudge(h, v, dx, dy) {
        const yawGrows = Cam.anglesFromPicture(0.6, 0.5).yaw > Cam.anglesFromPicture(0.4, 0.5).yaw
        const pitchGrows = Cam.anglesFromPicture(0.5, 0.6).pitch > Cam.anglesFromPicture(0.5, 0.4).pitch
        let yawMin = Cam.values.zoneYawMin, yawMax = Cam.values.zoneYawMax
        let pitchMin = Cam.values.zonePitchMin, pitchMax = Cam.values.zonePitchMax
        const dYaw = yawGrows ? dx : -dx, dPitch = pitchGrows ? dy : -dy
        if ((h === "l") === yawGrows) yawMin = Math.min(yawMin + dYaw, yawMax - 5); else yawMax = Math.max(yawMax + dYaw, yawMin + 5)
        if ((v === "t") === pitchGrows) pitchMin = Math.min(pitchMin + dPitch, pitchMax - 5); else pitchMax = Math.max(pitchMax + dPitch, pitchMin + 5)
        Cam.setZoneEdges(yawMin, yawMax, pitchMin, pitchMax)
    }

    // Dim everything outside the zone.
    readonly property real px: Math.max(0, Math.min(width, l * width))
    readonly property real py: Math.max(0, Math.min(height, t * height))
    readonly property real pr: Math.max(0, Math.min(width, r * width))
    readonly property real pb: Math.max(0, Math.min(height, b * height))
    Rectangle { x: 0; y: 0; width: root.px; height: root.height; color: Qt.rgba(0.02, 0.03, 0.04, 0.62) }
    Rectangle { x: root.pr; y: 0; width: root.width - root.pr; height: root.height; color: Qt.rgba(0.02, 0.03, 0.04, 0.62) }
    Rectangle { x: root.px; y: 0; width: root.pr - root.px; height: root.py; color: Qt.rgba(0.02, 0.03, 0.04, 0.62) }
    Rectangle { x: root.px; y: root.pb; width: root.pr - root.px; height: root.height - root.pb; color: Qt.rgba(0.02, 0.03, 0.04, 0.62) }

    Rectangle { // the zone
        x: root.l * root.width
        y: root.t * root.height
        width: (root.r - root.l) * root.width
        height: (root.b - root.t) * root.height
        color: "transparent"
        radius: 6
        border.width: 2
        border.color: Theme.accent
        Glow { radius: parent.radius }
        Rectangle { // label
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -height / 2
            visible: parent.y > 4 && parent.width > label.implicitWidth + 24
            implicitWidth: label.implicitWidth + 20
            implicitHeight: 26
            radius: 8
            color: Theme.accent
            Text {
                id: label
                anchors.centerIn: parent
                text: qsTr("Tracking stays in here")
                color: Theme.accentInk
                font.family: Theme.font
                font.pixelSize: Theme.small
                font.weight: Font.DemiBold
            }
        }
    }

    // The four corner handles. Each stays inside the picture even when its
    // corner of the zone doesn't.
    Repeater {
        model: [{ h: "l", v: "t", name: qsTr("Top left corner of the zone") }, { h: "r", v: "t", name: qsTr("Top right corner of the zone") },
                { h: "l", v: "b", name: qsTr("Bottom left corner of the zone") }, { h: "r", v: "b", name: qsTr("Bottom right corner of the zone") }]
        delegate: Rectangle {
            id: handle
            required property var modelData
            readonly property real inset: 12
            readonly property real cx: Math.max(inset, Math.min(root.width - inset, (handle.modelData.h === "l" ? root.l : root.r) * root.width))
            readonly property real cy: Math.max(inset, Math.min(root.height - inset, (handle.modelData.v === "t" ? root.t : root.b) * root.height))
            x: cx - width / 2
            y: cy - height / 2
            width: 20
            height: 20
            radius: 5
            color: "#ffffff"
            border.width: activeFocus ? 4 : 2
            border.color: Theme.accent
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: handle.modelData.name
            Accessible.description: qsTr("Drag to move, or use the arrow keys")
            Keys.onPressed: (e) => {
                const dx = e.key === Qt.Key_Left ? -1 : e.key === Qt.Key_Right ? 1 : 0
                const dy = e.key === Qt.Key_Up ? -1 : e.key === Qt.Key_Down ? 1 : 0
                if (dx === 0 && dy === 0) return
                root.nudge(handle.modelData.h, handle.modelData.v, dx, dy)
                e.accepted = true
            }
            Keys.onReleased: (e) => { if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(e.key)) e.accepted = true }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -10 // easier to grab
                cursorShape: Qt.SizeAllCursor
                preventStealing: true // or the page's scrolling takes an up-and-down drag
                property real pressX: 0
                property real pressY: 0
                onPressed: (m) => {
                    handle.forceActiveFocus()
                    const p = mapToItem(root, m.x, m.y)
                    pressX = p.x; pressY = p.y
                    root.dl = root.zone.x; root.dt = root.zone.y
                    root.dr = root.zone.x + root.zone.width; root.db = root.zone.y + root.zone.height
                    root.movedL = root.movedT = root.movedR = root.movedB = false
                    root.dragging = true
                }
                onPositionChanged: (m) => {
                    if (!root.dragging) return
                    const p = mapToItem(root, m.x, m.y)
                    const fx = Math.max(0, Math.min(1, p.x / root.width)), fy = Math.max(0, Math.min(1, p.y / root.height))
                    // A side starts to follow once the pointer has moved along
                    // its direction, so a sideways drag leaves top and bottom alone.
                    const left = handle.modelData.h === "l", top = handle.modelData.v === "t"
                    if (Math.abs(p.x - pressX) > 4) { if (left) root.movedL = true; else root.movedR = true }
                    if (Math.abs(p.y - pressY) > 4) { if (top) root.movedT = true; else root.movedB = true }
                    if (left && root.movedL) root.dl = Math.min(fx, root.dr - 0.05)
                    if (!left && root.movedR) root.dr = Math.max(fx, root.dl + 0.05)
                    if (top && root.movedT) root.dt = Math.min(fy, root.db - 0.05)
                    if (!top && root.movedB) root.db = Math.max(fy, root.dt + 0.05)
                }
                onReleased: root.commit()
                onCanceled: root.dragging = false
            }
        }
    }

    Rectangle { // how to use it
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 14
        implicitWidth: hint.implicitWidth + 20
        implicitHeight: 30
        radius: 8
        color: Theme.overlay
        Text {
            id: hint
            anchors.centerIn: parent
            text: qsTr("Drag a corner to move its two edges · wider than the picture: use the bar below")
            color: "#e8edf4"
            font.family: Theme.font
            font.pixelSize: Theme.small
            font.weight: Font.Medium
        }
    }
}
