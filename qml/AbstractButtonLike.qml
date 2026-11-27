// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls

// A plain clickable surface (used for the search field and list rows).
AbstractButton {
    id: control
    property bool selected: false
    property int corner: Theme.radiusSm + 2
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    background: Rectangle {
        radius: control.corner
        color: control.selected ? Theme.accentSoft : control.down ? Theme.sunken : control.hovered ? Theme.hover : Theme.surface
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus || control.selected ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
}
