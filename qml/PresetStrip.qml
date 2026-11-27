// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Preset cards with thumbnails, plus "Save this view". Drag a card (or use
// its menu) to reorder; the drop-down picks where the camera starts.
ColumnLayout {
    id: root
    signal saveRequested()
    signal renameRequested(int id, string name)
    signal deleteRequested(int id, string name)
    spacing: 12
    // Card size from the strip's width, so the layout never waits on itself.
    readonly property real cardWidth: (width - 3 * 12) / 4
    readonly property real cardHeight: (cardWidth - 16) * 9 / 16 + 60

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: qsTr("Presets")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.large - 1
            font.weight: Font.DemiBold
        }
        Text {
            text: qsTr("Click to go · drag to reorder · right-click for options")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.small
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.leftMargin: 8
        }
        Text {
            text: qsTr("Camera starts at")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
        }
        Select {
            id: startSelect
            implicitWidth: 170
            readonly property var ids: [-1].concat(cam.presets.map((p) => p.id))
            model: [qsTr("Straight ahead")].concat(cam.presets.map((p) => p.name))
            currentIndex: ids.indexOf(cam.values.startupPreset)
            displayText: currentIndex < 0 ? qsTr("Where it was set") : currentText
            enabled: cam.connected
            accessibleName: qsTr("Where the camera points when it turns on")
            onActivated: (i) => cam.setStartupPreset(ids[i])
            Tip {
                visible: startSelect.hovered && !startSelect.popup.visible
                text: qsTr("Where the camera points when it turns on. Choosing a preset moves the camera there to save it.")
            }
        }
    }

    GridLayout {
        id: grid
        Layout.fillWidth: true
        columns: 4
        // Which slot a point (in grid coordinates) falls in.
        function slotAt(x, y) {
            const col = Math.max(0, Math.min(3, Math.floor(x / (root.cardWidth + columnSpacing))))
            const row = Math.max(0, Math.floor(y / (root.cardHeight + rowSpacing)))
            return Math.min(cam.presets.length - 1, row * 4 + col)
        }
        property int dropSlot: -1
        columnSpacing: 12
        rowSpacing: 12

        Repeater {
            model: cam.presets
            delegate: AbstractButtonLike {
                id: card
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: root.cardHeight
                corner: 14
                Accessible.name: qsTr("Go to preset %1").arg(modelData.name)
                onClicked: cam.goToPreset(modelData.id)
                // Drag to reorder.
                z: drag.active ? 10 : 0
                opacity: drag.active ? 0.85 : 1
                transform: Translate { x: drag.active ? drag.activeTranslation.x : 0; y: drag.active ? drag.activeTranslation.y : 0 }
                DragHandler {
                    id: drag
                    target: null
                    enabled: cam.presets.length > 1
                    onCentroidChanged: if (active) {
                        const p = grid.mapFromItem(card, centroid.position.x, centroid.position.y)
                        grid.dropSlot = grid.slotAt(p.x, p.y)
                    }
                    onActiveChanged: {
                        if (!active && grid.dropSlot >= 0) cam.movePreset(card.modelData.id, grid.dropSlot)
                        grid.dropSlot = -1
                    }
                }
                Rectangle { // where it will land
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    visible: grid.dropSlot === card.modelData.index && !drag.active
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: menu.popup()
                }
                Rectangle {
                    id: thumb
                    x: 8; y: 8
                    width: parent.width - 16
                    height: width * 9 / 16
                    radius: 10
                    color: Theme.video
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: card.modelData.thumbnail
                        fillMode: Image.PreserveAspectCrop
                        visible: source.toString().length > 0
                        asynchronous: true
                        cache: false
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: card.modelData.thumbnail.length === 0
                        name: "camera"
                        color: "#4b586b"
                        size: 22
                    }
                }
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    anchors.bottomMargin: 12
                    spacing: 6
                    Text {
                        text: card.modelData.name
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Kbd { text: "Ctrl " + (card.modelData.index + 1); visible: card.modelData.index < 9 }
                    IconBtn {
                        iconName: "dots"
                        tip: qsTr("Preset options")
                        implicitWidth: 26
                        implicitHeight: 26
                        iconSize: 15
                        onClicked: menu.popup()
                    }
                }
                StyledMenu {
                    id: menu
                    Action { text: qsTr("Update to current view"); onTriggered: cam.updatePreset(card.modelData.id) }
                    Action { text: qsTr("Rename…"); onTriggered: root.renameRequested(card.modelData.id, card.modelData.name) }
                    Action { text: qsTr("Move left"); enabled: card.modelData.index > 0; onTriggered: cam.movePreset(card.modelData.id, card.modelData.index - 1) }
                    Action { text: qsTr("Move right"); enabled: card.modelData.index < cam.presets.length - 1; onTriggered: cam.movePreset(card.modelData.id, card.modelData.index + 1) }
                    Action { text: qsTr("Start here when the camera turns on"); onTriggered: cam.setStartupPreset(card.modelData.id) }
                    Action { text: qsTr("Delete"); onTriggered: root.deleteRequested(card.modelData.id, card.modelData.name) }
                }
            }
        }

        AbstractButtonLike {
            id: saveTile
            visible: cam.presets.length < cam.maxPresets
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            Layout.preferredHeight: root.cardHeight
            corner: 14
            enabled: cam.connected
            onClicked: root.saveRequested()
            background: Rectangle {
                radius: 14
                color: saveTile.hovered ? Theme.hover : "transparent"
                border.width: 1.5
                border.color: saveTile.hovered ? Theme.accent : Theme.borderStrong
                // Dashed look without images: a second inset border.
                Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 11; color: "transparent"; border.width: 1; border.color: Theme.border }
            }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                Icon { Layout.alignment: Qt.AlignHCenter; name: "plus"; color: Theme.textMuted; size: 20 }
                Text {
                    text: qsTr("Save this view")
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }

        Repeater { // keep cards a steady size when there are few
            model: Math.max(0, 4 - cam.presets.length - (cam.presets.length < cam.maxPresets ? 1 : 0))
            Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }
        }
    }
}
