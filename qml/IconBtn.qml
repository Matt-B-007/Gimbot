import QtQuick
import QtQuick.Controls

// Square icon-only button with a tooltip.
Button {
    id: control
    property string iconName: ""
    property string tip: ""
    property bool active: false
    property real iconSize: 17

    implicitWidth: 38
    implicitHeight: 38
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: tip
    scale: down ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast } }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: control.iconName
            size: control.iconSize
            color: control.active ? Theme.accentText : control.enabled ? Theme.text : Theme.textFaint
        }
    }
    background: Rectangle {
        radius: Theme.radiusSm + 2
        color: control.active ? Theme.accentSoft : control.down ? Theme.sunken : control.hovered ? Theme.hover : Theme.surface
        border.width: 1
        border.color: control.active ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            visible: control.visualFocus
        }
    }

    ToolTip {
        visible: control.hovered && control.tip.length > 0
        delay: 500
        text: control.tip
        contentItem: Text { text: control.tip; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.small }
        background: Rectangle { color: Theme.surface2; radius: 6; border.color: Theme.border }
    }
}
