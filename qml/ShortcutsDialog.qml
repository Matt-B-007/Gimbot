// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Every keyboard shortcut on one page. Opens with ? or Help › Keyboard shortcuts.
Sheet {
    id: root
    title: qsTr("Keyboard shortcuts")
    iconName: "help"
    maxWidth: 560
    readonly property var groups: [
        { name: qsTr("Camera"), keys: [
            ["↑ ↓ ← →", qsTr("Move the camera (hold)")],
            ["Home", qsTr("Point straight ahead")],
            ["+  −", qsTr("Zoom in and out")],
            ["Ctrl T", qsTr("Tracking on or off")],
            ["Ctrl L", qsTr("Sleep or wake")],
            ["Ctrl 1–3", qsTr("Go to a preset")] ] },
        { name: qsTr("Mouse"), keys: [
            [qsTr("Double-click"), qsTr("Point the camera at that spot")],
            [qsTr("Drag"), qsTr("Steer; the further you drag, the faster")],
            [qsTr("Scroll"), qsTr("Zoom")],
            [qsTr("Right-click a preset"), qsTr("Rename, move or delete it")] ] },
        { name: qsTr("App"), keys: [
            ["Ctrl K", qsTr("Search all commands")],
            ["Ctrl ,", qsTr("Settings")],
            ["?", qsTr("This list")],
            ["Esc", qsTr("Close / back")],
            ["Ctrl Q", qsTr("Quit")] ] }
    ]

    Repeater {
        model: root.groups
        ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: group.modelData.name
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.small
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                Layout.topMargin: 4
            }
            Repeater {
                model: group.modelData.keys
                RowLayout {
                    id: keyRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        text: keyRow.modelData[1]
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    Kbd { text: keyRow.modelData[0] }
                }
            }
        }
    }

    buttons: [
        Item { Layout.fillWidth: true },
        Btn { text: qsTr("Close"); variant: "primary"; onClicked: root.close() }
    ]
}
