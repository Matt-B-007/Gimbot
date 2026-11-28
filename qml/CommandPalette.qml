// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ctrl+K: type to find any action.
Popup {
    id: root
    property var actions: []   // { title, hint, run }
    parent: Overlay.overlay
    x: (parent.width - width) / 2
    y: Math.max(48, parent.height * 0.14)
    width: Math.min(560, parent.width - 48)
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    readonly property var filtered: {
        const q = field.text.trim().toLowerCase()
        if (q.length === 0) return actions
        return actions.filter(a => a.title.toLowerCase().indexOf(q) >= 0 || (a.keywords || "").indexOf(q) >= 0)
    }
    function runAt(i) {
        if (i < 0 || i >= filtered.length) return
        const a = filtered[i]
        close()
        a.run()
    }
    onOpened: { field.text = ""; list.currentIndex = 0; field.forceActiveFocus() }

    Overlay.modal: Rectangle { color: Theme.scrim }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast }
            NumberAnimation { property: "y"; from: root.y - 8; to: root.y; duration: Theme.normal; easing.type: Easing.OutCubic }
        }
    }
    background: Rectangle { radius: Theme.radiusLg; color: Theme.surface; border.color: Theme.borderStrong }

    contentItem: ColumnLayout {
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 6
            spacing: 0
            Icon { name: "search"; color: Theme.textMuted; size: 17; Layout.leftMargin: 12 }
            TextField {
                id: field
                Layout.fillWidth: true
                implicitHeight: 46
                placeholderText: qsTr("Type a command…")
                placeholderTextColor: Theme.textFaint
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.large
                background: Item {}
                Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
                Keys.onReturnPressed: root.runAt(list.currentIndex)
                Keys.onEnterPressed: root.runAt(list.currentIndex)
                onTextChanged: list.currentIndex = 0
            }
            Kbd { text: "Esc"; Layout.rightMargin: 10 }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
            Layout.margins: 6
            clip: true
            model: root.filtered
            highlightMoveDuration: 0
            delegate: AbstractButtonLike {
                id: row
                required property int index
                required property var modelData
                width: list.width
                implicitHeight: 40
                background: Rectangle { radius: Theme.radiusSm; color: row.ListView.isCurrentItem ? Theme.accentSoft : row.hovered ? Theme.hover : "transparent" }
                onClicked: root.runAt(index)
                onHoveredChanged: if (hovered) list.currentIndex = index
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    Icon { name: row.modelData.icon || "chevron-right"; size: 15; color: row.ListView.isCurrentItem ? Theme.accentText : Theme.textMuted }
                    Text {
                        text: row.modelData.title
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        elide: Text.ElideRight
                    }
                    Kbd { visible: (row.modelData.hint || "").length > 0; text: row.modelData.hint || "" }
                }
            }
        }
        Text {
            visible: root.filtered.length === 0
            Layout.margins: 18
            text: qsTr("No matching commands")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
