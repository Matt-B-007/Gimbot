// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls

// On/off switch.
Switch {
    id: control
    implicitWidth: 44
    implicitHeight: 26
    padding: 0
    spacing: 0
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    property string tip: ""
    property string accessibleName: ""
    // Inside a SettingRow, screen readers use the row's label.
    Accessible.name: accessibleName.length > 0 ? accessibleName : text.length > 0 ? text
                   : (parent && parent.parent && parent.parent.label !== undefined ? parent.parent.label : "") // qmllint disable missing-property
    Accessible.description: tip

    Tip { visible: control.hovered && control.tip.length > 0; text: control.tip }

    indicator: Rectangle {
        width: 44
        height: 26
        radius: 13
        color: control.checked ? Theme.accent : (Theme.dark ? "#2a3444" : "#cdd5df")
        opacity: control.enabled ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            y: 3
            width: 20
            height: 20
            radius: 10
            color: control.checked ? Theme.accentInk : (Theme.dark ? "#d5dce6" : "#ffffff")
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.accentText
            visible: control.visualFocus
        }
    }
    contentItem: Item {}
}
