import QtQuick
import QtQuick.Layouts

// Pan/tilt dial (click or drag to aim), live angles, recenter, zoom and how
// smoothly the camera moves.
Card {
    id: root
    title: qsTr("Aim")
    moreKey: "moreAim"
    readonly property bool usable: cam.connected && !cam.values.asleep
    note: cam.values.asleep ? qsTr("The camera is asleep. Wake it to move it.") : ""
    noteAction: cam.values.asleep ? qsTr("Wake") : ""
    onNoteActivated: cam.set("asleep", false)
    headerExtras: Btn {
        text: qsTr("Recenter")
        iconName: "target"
        compact: true
        pill: true
        enabled: root.usable
        tip: qsTr("Point the camera straight ahead")
        shortcut: "Home"
        onClicked: cam.recenter()
    }

    readonly property real panRange: 140
    readonly property real tiltRange: 90
    property bool dragging: false
    property real dragPan: 0
    property real dragTilt: 0
    readonly property real shownPan: dragging ? dragPan : cam.pan
    readonly property real shownTilt: dragging ? dragTilt : cam.tilt

    function fmt(v) { return (v > 0.05 ? "+" : "") + v.toFixed(1) + "°" }

    RowLayout {
        spacing: 18
        Layout.fillWidth: true

        Rectangle {
            id: dial
            implicitWidth: 136
            implicitHeight: 136
            radius: width / 2
            color: Theme.sunken
            border.color: Theme.border
            Accessible.role: Accessible.Dial
            Accessible.name: qsTr("Aim dial. Pan %1, tilt %2. Click or drag to aim.").arg(root.fmt(root.shownPan)).arg(root.fmt(root.shownTilt))
            HoverHandler { id: dialHover }
            Tip { visible: dialHover.hovered && !root.dragging; text: qsTr("Click or drag to point the camera. Up is up, right is right.") }

            Rectangle { x: parent.width / 2; y: 10; width: 1; height: parent.height - 20; color: Theme.border }
            Rectangle { y: parent.height / 2; x: 10; height: 1; width: parent.width - 20; color: Theme.border }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.5; height: width; radius: width / 2; color: "transparent"; border.color: Theme.border }

            Rectangle { // current direction
                readonly property real r: dial.width / 2 - 14
                width: 16; height: 16; radius: 8
                color: Theme.accent
                x: dial.width / 2 + (root.shownPan / root.panRange) * r - width / 2
                y: dial.height / 2 - (root.shownTilt / root.tiltRange) * r - height / 2
                Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !root.dragging; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Rectangle { anchors.centerIn: parent; width: 28; height: 28; radius: 14; color: Theme.accentSoft; z: -1 }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.usable
                cursorShape: Qt.CrossCursor
                function toAngles(mx, my) {
                    const r = dial.width / 2 - 14
                    root.dragPan = Math.max(-root.panRange, Math.min(root.panRange, (mx - dial.width / 2) / r * root.panRange))
                    root.dragTilt = Math.max(-root.tiltRange, Math.min(root.tiltRange, -(my - dial.height / 2) / r * root.tiltRange))
                }
                onPressed: (m) => { root.dragging = true; toAngles(m.x, m.y) }
                onPositionChanged: (m) => toAngles(m.x, m.y)
                onReleased: { cam.aimAbsolute(root.dragPan, root.dragTilt); root.dragging = false }
                onCanceled: root.dragging = false
            }
        }

        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            Repeater {
                model: [{ label: qsTr("Pan (right +)"), value: root.shownPan }, { label: qsTr("Tilt (up +)"), value: root.shownTilt }]
                ColumnLayout {
                    required property var modelData
                    spacing: 0
                    Text { text: parent.modelData.label; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
                    Text {
                        text: root.fmt(parent.modelData.value)
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                }
            }
            Text {
                text: qsTr("Arrow keys move · Home recenters · drag the picture to steer")
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.small - 1
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    SliderRow {
        Layout.fillWidth: true
        label: qsTr("Zoom")
        from: 0; to: 100; stepSize: 1
        value: cam.values.zoom
        valueText: cam.values.zoom + "%"
        tip: qsTr("Also: + and − keys, or scroll on the picture")
        enabled: root.usable
        onMoved: (v) => cam.set("zoom", Math.round(v))
    }

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true
        Text { text: qsTr("Movement"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
        Segmented {
            Layout.fillWidth: true
            stretch: true
            options: [qsTr("Fast"), qsTr("Normal"), qsTr("Smooth"), qsTr("Cinematic")]
            tips: [qsTr("Jump straight to the new spot"), qsTr("Quick glide"), qsTr("Slow, gentle glide"),
                   qsTr("Very slow glide, good for live streams")]
            accessibleName: qsTr("Movement smoothness")
            currentIndex: cam.values.smoothness
            onActivated: (i) => cam.set("smoothness", i)
        }
        Text {
            text: qsTr("For click-to-aim, the dial, presets and the arrow keys.")
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.small
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    more: [
        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Arrow key and drag speed")
            from: 10; to: 120; stepSize: 5
            value: cam.values.gimbalSpeed
            valueText: cam.values.gimbalSpeed + "°/s"
            onMoved: (x) => cam.set("gimbalSpeed", Math.round(x))
        },
        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Zoom speed")
            from: 0; to: 10; stepSize: 1
            value: cam.values.zoomSpeed
            valueText: cam.values.zoomSpeed === 0 ? qsTr("Camera default") : cam.values.zoomSpeed + " / 10"
            onMoved: (x) => cam.set("zoomSpeed", Math.round(x))
        }
    ]
}
