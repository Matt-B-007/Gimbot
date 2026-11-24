import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Quick image toggles and the two most used sliders.
Card {
    title: qsTr("Image")
    headerExtras: Btn {
        text: qsTr("Reset")
        variant: "ghost"
        compact: true
        enabled: cam.connected
        onClicked: cam.resetImage()
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: [{ key: "hdr", label: qsTr("HDR") }, { key: "mirrored", label: qsTr("Mirror") },
                    { key: "faceFocus", label: qsTr("Face focus") }, { key: "faceExposure", label: qsTr("Face exposure") }]
            delegate: AbstractButton {
                id: tile
                required property var modelData
                readonly property bool on: cam.values[modelData.key] === true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 62
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                enabled: cam.connected
                checkable: true
                checked: on
                Accessible.name: modelData.label
                onClicked: cam.set(modelData.key, !on)
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
        value: cam.values.brightness
        enabled: cam.connected
        onMoved: (v) => cam.set("brightness", Math.round(v))
    }
    SliderRow {
        Layout.fillWidth: true
        label: qsTr("Warmth")
        from: cam.ranges.wb.min; to: cam.ranges.wb.max; stepSize: 100
        value: cam.values.wbKelvin
        valueText: cam.values.wbMode === 0 ? qsTr("Auto") : cam.values.wbMode === 5 ? cam.values.wbKelvin + " K" : qsTr("Preset")
        enabled: cam.connected
        onMoved: (v) => cam.set("wbKelvin", Math.round(v / 100) * 100)
    }
    Btn {
        visible: cam.values.wbMode !== 0
        text: qsTr("Back to automatic white balance")
        variant: "ghost"
        compact: true
        onClicked: cam.set("wbMode", 0)
    }
}
