// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Labeled slider. `moved(value)` fires live while dragging.
ColumnLayout {
    id: root
    property string label: ""
    property string valueText: Math.round(slider.value)
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property real value: 0
    property bool dim: false
    property string tip: ""
    signal moved(real value)

    spacing: 8
    opacity: dim ? 0.45 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: root.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            Layout.fillWidth: true
        }
        Text {
            text: root.valueText
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: 22
        padding: 0
        live: true
        value: root.value
        focusPolicy: Qt.StrongFocus
        Accessible.name: root.label
        Accessible.description: root.tip
        hoverEnabled: true
        Tip { visible: slider.hovered && root.tip.length > 0 && !slider.pressed; text: root.tip }
        onMoved: root.moved(value)
        // Keep following the model unless the user is dragging.
        Binding on value { value: root.value; when: !slider.pressed }

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Theme.dark ? "#2a3444" : "#cdd5df"
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.pressed ? 20 : 18
            height: width
            radius: width / 2
            color: Theme.dark ? "#e8edf4" : "#ffffff"
            border.width: Theme.dark ? 0 : 1
            border.color: Theme.borderStrong
            Behavior on width { NumberAnimation { duration: Theme.fast } }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: width / 2
                color: "transparent"
                border.width: slider.visualFocus ? 2 : 4
                border.color: slider.visualFocus ? Theme.accentText : Theme.accentSoft
                visible: slider.visualFocus || slider.pressed || slider.hovered
            }
        }
    }
}
