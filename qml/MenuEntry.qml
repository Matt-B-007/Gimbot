import QtQuick
import QtQuick.Controls

// A menu item in the app's style, for menus built from a list.
MenuItem {
    id: item
    implicitHeight: visible ? 34 : 0
    implicitWidth: 240
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    contentItem: Text {
        leftPadding: 8
        text: item.text
        font: item.font
        color: item.enabled ? Theme.text : Theme.textFaint
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle { radius: 6; color: item.highlighted ? Theme.hover : "transparent" }
}
