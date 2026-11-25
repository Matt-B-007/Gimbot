import QtQuick
import QtQuick.Controls

// Single-line text input.
TextField {
    id: control
    Accessible.name: placeholderText
    implicitHeight: 40
    leftPadding: 12
    rightPadding: 12
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    color: Theme.text
    placeholderTextColor: Theme.textFaint
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentInk
    background: Rectangle {
        radius: Theme.radiusSm + 2
        color: Theme.surface2
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.border
    }
}
