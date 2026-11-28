// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls

// Context menu in the app's style.
Menu {
    id: menu
    padding: 4
    // As wide as its longest entry, so nothing is cut off.
    width: {
        let w = 220
        for (let i = 0; i < count; ++i) {
            const it = itemAt(i)
            if (it && it.visible) w = Math.max(w, it.implicitWidth)
        }
        return w + leftPadding + rightPadding
    }
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    delegate: MenuItem {
        id: item
        implicitHeight: 34
        implicitWidth: Math.max(220, contentItem.implicitWidth + leftPadding + rightPadding + 8)
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
