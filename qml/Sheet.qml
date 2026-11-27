// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Centered modal dialog with a title, body and button row.
Popup {
    id: root
    property string title: ""
    property string iconName: ""
    default property alias body: bodyColumn.data
    property alias buttons: buttonRow.data
    property int maxWidth: 520

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(maxWidth, parent ? parent.width - 48 : maxWidth)
    modal: true
    focus: true
    padding: 24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle {
        color: Theme.scrim
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast } }

    background: Rectangle {
        radius: Theme.radiusLg + 2
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong
    }

    contentItem: ColumnLayout {
        spacing: 18
        RowLayout {
            spacing: 12
            visible: root.title.length > 0
            Layout.fillWidth: true
            Rectangle {
                visible: root.iconName.length > 0
                implicitWidth: 36
                implicitHeight: 36
                radius: 10
                color: Theme.accentSoft
                Icon { anchors.centerIn: parent; name: root.iconName; color: Theme.accentText; size: 18 }
            }
            Text {
                text: root.title
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.large + 2
                font.weight: Font.Bold
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            IconBtn { iconName: "x"; tip: qsTr("Close"); onClicked: root.close(); implicitWidth: 32; implicitHeight: 32 }
        }
        ColumnLayout {
            id: bodyColumn
            spacing: 14
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        RowLayout {
            id: buttonRow
            spacing: 8
            Layout.fillWidth: true
            visible: children.length > 0
        }
    }
}
