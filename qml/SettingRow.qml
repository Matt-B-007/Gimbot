import QtQuick
import QtQuick.Layouts

// One line in a settings list: label and description on the left, a control
// on the right, and a divider underneath. Positioned with anchors (not a
// layout) so wrapping text can never make it resize in a loop.
Item {
    id: root
    property string label: ""
    property string description: ""
    property bool divider: true
    property bool dim: false
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(56, labels.implicitHeight + 20, slot.implicitHeight + 16)
    opacity: dim ? 0.45 : 1

    Column {
        id: labels
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: slot.width > 0 ? 16 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: root.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: root.description.length > 0
            text: root.description
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
            wrapMode: Text.WordWrap
        }
    }
    Row {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
    Rectangle {
        visible: root.divider
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }
}
