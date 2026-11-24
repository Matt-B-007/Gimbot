import QtQuick
import QtQuick.Layouts

// A dismissible message strip (update available, previous crash, ...).
Rectangle {
    id: root
    property string iconName: "info"
    property string text: ""
    property string actionText: ""
    property string secondaryText: ""
    property color tint: Theme.accent
    signal action()
    signal secondary()
    signal dismissed()

    implicitHeight: row.implicitHeight + 20
    radius: Theme.radius
    color: Qt.rgba(tint.r, tint.g, tint.b, Theme.dark ? 0.12 : 0.1)
    border.width: 1
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.45)

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 12
        Icon { name: root.iconName; color: root.tint; size: 18 }
        Text {
            text: root.text
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Btn { visible: root.secondaryText.length > 0; text: root.secondaryText; variant: "ghost"; compact: true; onClicked: root.secondary() }
        Btn { visible: root.actionText.length > 0; text: root.actionText; variant: "outline"; compact: true; onClicked: root.action() }
        IconBtn { iconName: "x"; tip: qsTr("Dismiss"); implicitWidth: 30; implicitHeight: 30; iconSize: 14; onClicked: root.dismissed() }
    }
}
