// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Gimbot

// The circle aim pad (drag to move, let go to stop), live angles, recenter,
// zoom and how smoothly the camera moves.
Card {
    id: root
    title: qsTr("Aim")
    moreKey: "moreAim"
    readonly property bool usable: Cam.connected && !Cam.values.asleep
    note: Cam.values.asleep ? qsTr("The camera is asleep. Wake it to move it.") : ""
    noteAction: Cam.values.asleep ? qsTr("Wake") : ""
    onNoteActivated: Cam.set("asleep", false)
    headerExtras: Btn {
        text: qsTr("Recenter")
        iconName: "target"
        compact: true
        pill: true
        enabled: root.usable
        tip: qsTr("Point the camera straight ahead")
        shortcut: "Home"
        onClicked: Cam.recenter()
    }

    readonly property real shownPan: Cam.pan
    readonly property real shownTilt: Cam.tilt

    function fmt(v) { return (v > 0.05 ? "+" : "") + v.toFixed(1) + "°" }

    RowLayout {
        spacing: 18
        Layout.fillWidth: true

        AimPad {
            usable: root.usable
        }
        ColumnLayout {
            spacing: 12
            Layout.fillWidth: true
            Repeater {
                // Fixed labels; the angle is read in the delegate, so the
                // readouts aren't remade every time the camera moves.
                model: [qsTr("Pan (right +)"), qsTr("Tilt (up +)")]
                ColumnLayout {
                    id: readout
                    required property int index
                    required property string modelData
                    spacing: 0
                    Text { text: readout.modelData; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
                    Text {
                        text: root.fmt(readout.index === 0 ? root.shownPan : root.shownTilt)
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                }
            }
            Text {
                text: qsTr("Drag the circle: a little is slow, to the edge is fast. Let go to stop.")
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
        value: Cam.values.zoom
        valueText: Cam.values.zoom + "%"
        tip: qsTr("Also: + and − keys, or scroll on the picture")
        enabled: root.usable
        onMoved: (v) => Cam.set("zoom", Math.round(v))
    }

    // One-click zoom levels, worked out from the camera's own zoom range.
    RowLayout {
        id: zoomLevels
        Layout.fillWidth: true
        spacing: 6
        readonly property real maxZoom: Cam.ranges.zoomMax > 1 ? Cam.ranges.zoomMax : 4
        function percentFor(x) { return Math.round(Math.max(0, Math.min(1, (x - 1) / (maxZoom - 1))) * 100) }
        Repeater {
            model: {
                const m = parent.maxZoom
                let levels = [1]
                if (m >= 2.5) levels.push(2)
                if (m >= 4.5) levels.push(Math.round(m / 2))
                levels.push(m)
                return levels
            }
            Btn {
                required property real modelData
                readonly property int percent: zoomLevels.percentFor(modelData)
                Layout.fillWidth: true
                text: (Math.round(modelData * 10) / 10) + "×"
                variant: Math.abs(Cam.values.zoom - percent) <= 1 ? "primary" : "outline"
                compact: true
                enabled: root.usable
                tip: modelData === 1 ? qsTr("No zoom") : qsTr("Zoom to %1×").arg(Math.round(modelData * 10) / 10)
                onClicked: Cam.set("zoom", percent)
            }
        }
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
            currentIndex: Cam.values.smoothness
            onActivated: (i) => Cam.set("smoothness", i)
        }
        Text {
            text: qsTr("For double-click aiming, presets and the arrow keys.")
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
            value: Cam.values.gimbalSpeed
            valueText: Cam.values.gimbalSpeed + "°/s"
            onMoved: (x) => Cam.set("gimbalSpeed", Math.round(x))
        },
        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Zoom speed")
            from: 0; to: 10; stepSize: 1
            value: Cam.values.zoomSpeed
            valueText: Cam.values.zoomSpeed === 0 ? qsTr("Camera default") : Cam.values.zoomSpeed + " / 10"
            onMoved: (x) => Cam.set("zoomSpeed", Math.round(x))
        }
    ]
}
