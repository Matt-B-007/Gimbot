import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Quick image toggles, brightness and white balance; focus, exposure and the
// remaining sliders under More.
Card {
    id: root
    title: qsTr("Image")
    moreKey: "moreImage"
    readonly property var v: cam.values
    readonly property bool usable: cam.connected && !v.asleep
    readonly property bool narrow: width < 380 // white balance becomes a drop-down
    readonly property var wbNames: [qsTr("Auto"), qsTr("Daylight"), qsTr("Cloudy"), qsTr("Indoor"), qsTr("Fluorescent"), qsTr("Manual")]
    readonly property var wbTips: [qsTr("The camera picks the color for you"), qsTr("Sunlight"), qsTr("Overcast daylight"),
                                   qsTr("Warm indoor bulbs (tungsten)"), qsTr("Office tube lights"), qsTr("Set the temperature yourself")]
    note: v.asleep ? qsTr("The camera is asleep. Wake it to adjust the picture.") : ""
    noteAction: v.asleep ? qsTr("Wake") : ""
    onNoteActivated: cam.set("asleep", false)

    headerExtras: Btn {
        text: qsTr("Reset")
        iconName: "refresh"
        variant: "ghost"
        compact: true
        enabled: cam.connected
        tip: qsTr("Back to the camera's default picture settings. You can undo this.")
        onClicked: cam.resetImage()
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: [{ key: "hdr", label: qsTr("HDR"), tip: qsTr("Better detail in bright windows and dark corners") },
                    { key: "mirrored", label: qsTr("Mirror"), tip: qsTr("Flip the picture left to right, like a mirror. Other apps see it too.") },
                    { key: "faceFocus", label: qsTr("Face focus"), tip: qsTr("Keep faces sharp") },
                    { key: "faceExposure", label: qsTr("Face exposure"), tip: qsTr("Set brightness for faces, not the background") }]
            delegate: AbstractButton {
                id: tile
                required property var modelData
                readonly property bool on: root.v[modelData.key] === true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 58
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                enabled: root.usable
                checkable: true
                checked: on
                Accessible.name: modelData.label
                Accessible.description: modelData.tip
                onClicked: cam.set(modelData.key, !on)
                Tip { visible: tile.hovered; text: tile.modelData.tip }
                background: Rectangle {
                    radius: Theme.radius
                    color: tile.on ? Theme.accentSoft : tile.hovered ? Qt.lighter(Theme.surface2, Theme.dark ? 1.12 : 0.98) : Theme.surface2
                    border.width: tile.visualFocus ? 2 : 1
                    border.color: tile.on || tile.visualFocus ? Theme.accent : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
                contentItem: ColumnLayout {
                    spacing: 2
                    Text {
                        leftPadding: 12
                        text: tile.modelData.label
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        font.weight: Font.Medium
                    }
                    Text {
                        leftPadding: 12
                        text: tile.on ? qsTr("On") : qsTr("Off")
                        color: tile.on ? Theme.accentText : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: Theme.small
                    }
                }
                opacity: enabled ? 1 : 0.5
            }
        }
    }

    SliderRow {
        Layout.fillWidth: true
        label: qsTr("Brightness")
        from: cam.ranges.brightness.min; to: cam.ranges.brightness.max; stepSize: 1
        value: root.v.brightness
        enabled: root.usable
        onMoved: (x) => cam.set("brightness", Math.round(x))
    }

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true
        Caption { text: qsTr("White balance") }
        Flow { // chips when there's room
            visible: !root.narrow
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.wbNames
                Chip {
                    required property int index
                    required property string modelData
                    text: modelData
                    selected: root.v.wbMode === index
                    enabled: root.usable
                    tip: root.wbTips[index]
                    onClicked: cam.set("wbMode", index)
                }
            }
        }
        Select { // a drop-down in a narrow window
            visible: root.narrow
            Layout.fillWidth: true
            model: root.wbNames
            currentIndex: root.v.wbMode
            enabled: root.usable
            accessibleName: qsTr("White balance")
            onActivated: (i) => cam.set("wbMode", i)
        }
        SliderRow {
            Layout.fillWidth: true
            visible: root.v.wbMode === 5
            label: qsTr("Temperature")
            tip: qsTr("Lower is warmer (orange), higher is cooler (blue)")
            from: cam.ranges.wb.min; to: cam.ranges.wb.max; stepSize: 100
            value: root.v.wbKelvin
            valueText: root.v.wbKelvin + " K"
            enabled: root.usable
            onMoved: (x) => cam.set("wbKelvin", Math.round(x / 100) * 100)
        }
    }

    more: [
        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                Caption { text: qsTr("Focus"); Layout.fillWidth: true }
                Segmented {
                    implicitWidth: 170
                    stretch: true
                    options: [qsTr("Auto"), qsTr("Manual")]
                    accessibleName: qsTr("Focus")
                    currentIndex: root.v.autoFocus ? 0 : 1
                    enabled: root.usable
                    onActivated: (i) => cam.set("autoFocus", i === 0)
                }
            }
            SliderRow {
                Layout.fillWidth: true
                visible: !root.v.autoFocus
                label: qsTr("Focus distance")
                valueText: qsTr("Near ↔ far")
                from: 0; to: 100; stepSize: 1
                value: root.v.manualFocus
                enabled: root.usable
                onMoved: (x) => cam.set("manualFocus", Math.round(x))
            }
        },
        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                Caption { text: qsTr("Exposure"); Layout.fillWidth: true }
                Segmented {
                    implicitWidth: 170
                    stretch: true
                    options: [qsTr("Auto"), qsTr("Manual")]
                    accessibleName: qsTr("Exposure")
                    currentIndex: root.v.exposureAuto ? 0 : 1
                    enabled: root.usable
                    onActivated: (i) => cam.set("exposureAuto", i === 0)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !root.v.exposureAuto
                Text {
                    text: qsTr("Shutter speed")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    Layout.fillWidth: true
                }
                Select {
                    implicitWidth: 130
                    model: cam.shutterLabels
                    currentIndex: root.v.shutter - 9
                    enabled: root.usable
                    Accessible.name: qsTr("Shutter speed")
                    onActivated: (i) => cam.set("shutter", i + 9)
                }
            }
            Text {
                visible: !root.v.exposureAuto
                text: qsTr("Faster is darker but sharper. Under room lights, 1/60 or 1/50 avoids flicker.")
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.small
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        },
        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Contrast")
            from: cam.ranges.contrast.min; to: cam.ranges.contrast.max; stepSize: 1
            value: root.v.contrast
            enabled: root.usable
            onMoved: (x) => cam.set("contrast", Math.round(x))
        },
        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Saturation")
            from: cam.ranges.saturation.min; to: cam.ranges.saturation.max; stepSize: 1
            value: root.v.saturation
            enabled: root.usable
            onMoved: (x) => cam.set("saturation", Math.round(x))
        },
        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Hue")
            tip: qsTr("Shifts all colors around the color wheel. Usually best left in the middle.")
            from: cam.ranges.hue.min; to: cam.ranges.hue.max; stepSize: 1
            value: root.v.hue
            enabled: root.usable
            onMoved: (x) => cam.set("hue", Math.round(x))
        },
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Text { text: qsTr("Anti-flicker"); color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize }
                Text {
                    text: qsTr("Fixes stripes or flicker under room lights. North America: 60 Hz, most other places: 50 Hz.")
                    color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small
                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                }
            }
            Select {
                implicitWidth: 110
                model: [qsTr("Off"), qsTr("50 Hz"), qsTr("60 Hz"), qsTr("Auto")]
                currentIndex: root.v.antiFlicker
                enabled: root.usable
                accessibleName: qsTr("Anti-flicker")
                onActivated: (i) => cam.set("antiFlicker", i)
            }
        },
        SliderRow {
            Layout.fillWidth: true
            label: qsTr("Sharpness")
            from: cam.ranges.sharpness.min; to: cam.ranges.sharpness.max; stepSize: 1
            value: root.v.sharpness
            enabled: root.usable
            onMoved: (x) => cam.set("sharpness", Math.round(x))
        }
    ]

    component Caption: Text {
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.small
    }
    component Chip: AbstractButton {
        id: chip
        property bool selected: false
        property string tip: ""
        implicitHeight: 30
        implicitWidth: chipText.implicitWidth + 24
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.RadioButton
        Accessible.checked: selected
        Accessible.name: text
        Accessible.description: tip
        opacity: enabled ? 1 : 0.5
        Tip { visible: chip.hovered && chip.tip.length > 0; text: chip.tip }
        background: Rectangle {
            radius: height / 2
            color: chip.selected ? Theme.accent : chip.hovered ? Theme.hover : Theme.surface2
            border.width: chip.visualFocus ? 2 : chip.selected ? 0 : 1
            border.color: chip.visualFocus ? Theme.accentText : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        contentItem: Text {
            id: chipText
            text: chip.text
            color: chip.selected ? Theme.accentInk : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
            font.weight: chip.selected ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
