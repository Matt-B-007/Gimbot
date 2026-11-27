// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls

// Drop-down list.
ComboBox {
    id: control
    // Inside a SettingRow, screen readers use the row's label.
    property string accessibleName: ""
    Accessible.name: accessibleName.length > 0 ? accessibleName
                   : (parent && parent.parent && parent.parent.label !== undefined ? parent.parent.label : displayText) // qmllint disable missing-property
    implicitHeight: 38
    implicitWidth: 220
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    hoverEnabled: true

    contentItem: Text {
        leftPadding: 12
        rightPadding: 32
        text: control.displayText
        font: control.font
        color: control.enabled ? Theme.text : Theme.textFaint
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Icon {
        x: control.width - width - 12
        y: (control.height - height) / 2
        name: "chevron-down"
        size: 15
        color: Theme.textMuted
    }
    background: Rectangle {
        radius: Theme.radiusSm + 2
        color: control.hovered ? Qt.lighter(Theme.surface2, Theme.dark ? 1.12 : 0.98) : Theme.surface2
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.accent : Theme.border
    }
    delegate: ItemDelegate {
        id: item
        required property int index
        required property var modelData
        width: ListView.view ? ListView.view.width : control.width
        height: 36
        hoverEnabled: true
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: typeof item.modelData === "object" && item.modelData !== null ? item.modelData[control.textRole] : item.modelData
            color: item.index === control.currentIndex ? Theme.accentText : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.weight: item.index === control.currentIndex ? Font.DemiBold : Font.Normal
            verticalAlignment: Text.AlignVCenter
            leftPadding: 4
        }
        background: Rectangle {
            radius: 6
            color: item.highlighted ? Theme.hover : "transparent"
        }
    }
    popup: Popup {
        y: control.height + 4
        width: control.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle {
            radius: Theme.radius
            color: Theme.surface2
            border.color: Theme.borderStrong
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast } }
    }
}
