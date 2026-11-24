import QtQuick
import QtQuick.Layouts

// App bar: logo, camera chip, command search, sleep and settings.
RowLayout {
    id: root
    signal openPalette()
    signal openSettings()
    spacing: 10

    Image {
        source: "icons/gimbot.svg"
        sourceSize: Qt.size(34, 34)
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
    }
    Text {
        text: "Gimbot"
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 17
        font.weight: Font.Bold
        font.letterSpacing: -0.2
    }

    Rectangle { // camera chip
        Layout.leftMargin: 6
        implicitHeight: 34
        implicitWidth: chip.implicitWidth + 24
        radius: 17
        color: Theme.surface
        border.color: Theme.border
        RowLayout {
            id: chip
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: !cam.connected ? Theme.textFaint : cam.values.asleep ? Theme.warning : Theme.success
            }
            Text {
                text: cam.connected ? cam.model : qsTr("No camera")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.small + 1
                font.weight: Font.Medium
            }
        }
    }

    Item { Layout.fillWidth: true }

    AbstractButtonLike { // command search
        id: search
        Layout.preferredWidth: 240
        Layout.minimumWidth: 140
        implicitHeight: 36
        onClicked: root.openPalette()
        Accessible.name: qsTr("Search commands")
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 10
            Icon { name: "search"; size: 15; color: Theme.textMuted }
            Text {
                text: qsTr("Search commands")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.small + 1
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Kbd { text: "Ctrl K" }
        }
    }

    Btn {
        text: cam.values.asleep ? qsTr("Wake") : qsTr("Sleep")
        iconName: "moon"
        compact: false
        implicitHeight: 36
        enabled: cam.connected
        onClicked: cam.set("asleep", !cam.values.asleep)
    }
    IconBtn {
        iconName: "gear"
        tip: qsTr("Settings (Ctrl+,)")
        implicitWidth: 36
        implicitHeight: 36
        onClicked: root.openSettings()
    }
}
