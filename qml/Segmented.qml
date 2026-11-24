import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A row of mutually exclusive options with a sliding highlight.
Rectangle {
    id: root
    property var options: []      // strings
    property int currentIndex: 0
    property bool pill: false
    property bool onVideo: false  // floating over the preview
    property int itemHeight: 34
    property bool stretch: false   // share extra width between the options
    signal activated(int index)

    implicitHeight: itemHeight + 8
    implicitWidth: row.implicitWidth + 8
    radius: pill ? height / 2 : Theme.radius
    color: onVideo ? Theme.overlay : Theme.sunken
    border.width: onVideo ? 1 : 0
    border.color: Qt.rgba(1, 1, 1, 0.1)
    Accessible.role: Accessible.PageTabList

    Rectangle {
        id: highlight
        readonly property Item target: repeater.count > root.currentIndex && root.currentIndex >= 0 ? repeater.itemAt(root.currentIndex) : null
        visible: target !== null
        x: target ? target.x + row.x : 0
        y: 4
        width: target ? target.width : 0
        height: root.itemHeight
        radius: root.pill ? height / 2 : Theme.radius - 3
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: row
        x: 4
        y: 4
        spacing: 2
        width: root.width - 8
        Repeater {
            id: repeater
            model: root.options
            delegate: AbstractButton {
                id: btn
                required property int index
                required property string modelData
                readonly property bool selected: index === root.currentIndex
                Layout.preferredHeight: root.itemHeight
                Layout.preferredWidth: label.implicitWidth + (root.pill ? 32 : 24)
                Layout.fillWidth: root.stretch
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                checkable: true
                checked: selected
                Accessible.name: modelData
                onClicked: { root.currentIndex = index; root.activated(index) }
                background: Rectangle {
                    radius: root.pill ? height / 2 : Theme.radius - 3
                    color: !btn.selected && btn.hovered ? (root.onVideo ? Qt.rgba(1, 1, 1, 0.08) : Theme.hover) : "transparent"
                    border.width: btn.visualFocus ? 2 : 0
                    border.color: Theme.accentText
                }
                contentItem: Text {
                    id: label
                    text: btn.modelData
                    font.family: Theme.font
                    font.pixelSize: root.pill ? Theme.fontSize - 1 : Theme.small + 1
                    font.weight: btn.selected ? Font.DemiBold : Font.Medium
                    color: btn.selected ? Theme.accentInk : root.onVideo ? "#f2f3f5" : Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
            }
        }
    }
}
