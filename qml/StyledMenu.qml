// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls

// Context menu in the app's style.
Menu {
    id: menu
    padding: 4
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    delegate: MenuItem {
        id: item
        implicitHeight: 34
        implicitWidth: 220
        contentItem: Text {
            leftPadding: 8
            text: item.text
            font: item.font
            color: item.text === qsTr("Delete") ? Theme.danger : Theme.text
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { radius: 6; color: item.highlighted ? Theme.hover : "transparent" }
    }
    background: Rectangle {
        implicitWidth: 220
        radius: Theme.radius
        color: Theme.surface2
        border.color: Theme.borderStrong
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast } }
}
