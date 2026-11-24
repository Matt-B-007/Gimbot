import QtQuick
import QtQuick.Layouts

// One line in a settings list: label and description on the left, a control
// on the right, and a divider underneath.
Item {
    id: root
    property string label: ""
    property string description: ""
    property bool divider: true
    property bool dim: false
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(56, text.implicitHeight + 20, slot.implicitHeight + 16)
    opacity: dim ? 0.45 : 1

    RowLayout {
        anchors.fill: parent
        spacing: 16
        ColumnLayout {
            id: text
            spacing: 2
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Text {
                text: root.label
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                visible: root.description.length > 0
                text: root.description
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.small + 1
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        Row {
            id: slot
            spacing: 8
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
    }
    Rectangle {
        visible: root.divider
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }
}
