// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Gimbot

// The camera's whole left-right turning range, for a zone wider than the
// picture: the purple bar is the zone (drag its ends), the dashed box is what
// the camera sees now. Left and right match the picture, mirroring included.
Card {
    id: root
    title: qsTr("Whole turning range")
    subtitle: qsTr("For an area wider than the picture, drag the ends of the purple bar")
    readonly property real span: 120 // degrees each way the zone may reach

    function frac(yaw) { return (Cam.screenFromYaw(yaw) + span) / (2 * span) }
    // Zone ends as fractions of the bar, left to right.
    readonly property real za: { void (Cam.values.mirrored); return frac(Cam.values.zoneYawMin) }
    readonly property real zb: { void (Cam.values.mirrored); return frac(Cam.values.zoneYawMax) }
    readonly property real zl: dragging ? dragL : Math.min(za, zb)
    readonly property real zr: dragging ? dragR : Math.max(za, zb)
    // What the camera sees now.
    readonly property real vl: {
        void (Cam.rawYaw + Cam.values.fov + Cam.values.zoom + Cam.values.mirrored)
        return frac(Cam.anglesFromPicture(0, 0.5).yaw)
    }
    readonly property real vr: {
        void (Cam.rawYaw + Cam.values.fov + Cam.values.zoom + Cam.values.mirrored)
        return frac(Cam.anglesFromPicture(1, 0.5).yaw)
    }
    property bool dragging: false
    property real dragL: 0
    property real dragR: 1

    function commit() {
        const yawAt = (f) => Math.round(Math.max(-span, Math.min(span, Cam.yawFromScreen(f * 2 * span - span))))
        const a = yawAt(dragL), b = yawAt(dragR)
        Cam.setZoneEdges(Math.min(a, b), Math.max(a, b), Cam.values.zonePitchMin, Cam.values.zonePitchMax)
        dragging = false
    }
    // One degree with the keyboard; dx is on screen, right is positive.
    function nudge(end, dx) {
        const grows = Cam.yawFromScreen(1) > 0 // does the camera's angle grow to the right?
        let lo = Cam.values.zoneYawMin, hi = Cam.values.zoneYawMax
        const d = grows ? dx : -dx
        if ((end === "l") === grows) lo = Math.min(lo + d, hi - 5); else hi = Math.max(hi + d, lo + 5)
        Cam.setZoneEdges(lo, hi, Cam.values.zonePitchMin, Cam.values.zonePitchMax)
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: qsTr("Left −120°"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
        Item { Layout.fillWidth: true }
        Text { text: qsTr("Straight ahead"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
        Item { Layout.fillWidth: true }
        Text { text: qsTr("Right +120°"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
    }
    Rectangle {
        id: track
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 8
        color: Theme.surface2
        Accessible.role: Accessible.Slider
        Accessible.name: qsTr("Zone, left to right")
        Rectangle { x: parent.width / 2; y: 5; width: 1; height: parent.height - 10; color: Theme.borderStrong }
        Rectangle { // the zone
            x: root.zl * track.width
            width: Math.max(8, (root.zr - root.zl) * track.width)
            height: parent.height
            radius: 8
            color: Theme.accentSoft
            border.width: 2
            border.color: Theme.accent
        }
        Rectangle { // what the camera sees now
            x: Math.max(0, root.vl) * track.width
            width: Math.max(4, (Math.min(1, root.vr) - Math.max(0, root.vl)) * track.width)
            y: 7
            height: parent.height - 14
            radius: 4
            color: "transparent"
            border.width: 1.5
            border.color: Theme.text
            opacity: 0.8
        }
        Repeater { // the zone's two ends
            model: ["l", "r"]
            delegate: Rectangle {
                id: end
                required property string modelData
                x: (end.modelData === "l" ? root.zl : root.zr) * track.width - width / 2
                y: 5
                width: 12
                height: track.height - 10
                radius: 3
                color: "#ffffff"
                border.width: activeFocus ? 4 : 2
                border.color: Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: end.modelData === "l" ? qsTr("Zone's left edge") : qsTr("Zone's right edge")
                Accessible.description: qsTr("Drag to move, or use the left and right arrow keys")
                Keys.onPressed: (e) => {
                    if (e.key !== Qt.Key_Left && e.key !== Qt.Key_Right) return
                    root.nudge(end.modelData, e.key === Qt.Key_Left ? -1 : 1)
                    e.accepted = true
                }
                Keys.onReleased: (e) => { if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) e.accepted = true }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    preventStealing: true
                    cursorShape: Qt.SizeHorCursor
                    onPressed: { end.forceActiveFocus(); root.dragL = Math.min(root.za, root.zb); root.dragR = Math.max(root.za, root.zb); root.dragging = true }
                    onPositionChanged: (m) => {
                        if (!root.dragging) return
                        const f = Math.max(0, Math.min(1, mapToItem(track, m.x, m.y).x / track.width))
                        if (end.modelData === "l") root.dragL = Math.min(f, root.dragR - 0.02)
                        else root.dragR = Math.max(f, root.dragL + 0.02)
                    }
                    onReleased: root.commit()
                    onCanceled: root.dragging = false
                }
            }
        }
    }
    RowLayout {
        spacing: 18
        Row {
            spacing: 6
            Rectangle { width: 16; height: 11; radius: 3; color: Theme.accentSoft; border.width: 2; border.color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Text { text: qsTr("The zone"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
        }
        Row {
            spacing: 6
            Rectangle { width: 16; height: 11; radius: 3; color: "transparent"; border.width: 1.5; border.color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: qsTr("What the camera sees now"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
        }
    }
}
