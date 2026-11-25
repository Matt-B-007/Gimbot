import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Layouts

// App bar: logo, camera chip, profile switcher, command search, sleep, help
// and settings.
RowLayout {
    id: root
    signal openPalette()
    signal openSettings()
    signal openProfiles()
    signal saveProfile()
    signal openTour()
    signal openReport()
    signal openAbout()
    signal openShortcuts()
    spacing: 10
    readonly property bool compactBar: width < 980

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

    AbstractButtonLike { // profile switcher
        id: profileBtn
        implicitHeight: 34
        implicitWidth: profileRow.implicitWidth + 26
        corner: 17
        Accessible.name: cam.activeProfile.length > 0 ? qsTr("Profile: %1. Switch profile").arg(cam.activeProfile) : qsTr("Switch profile")
        onClicked: profileMenu.popup(profileBtn, 0, profileBtn.height + 6)
        Tip { visible: profileBtn.hovered && !profileMenu.visible; text: qsTr("Switch your whole setup at once, like “Meetings” or “Streaming”") }
        RowLayout {
            id: profileRow
            anchors.centerIn: parent
            spacing: 7
            Icon { name: "layers"; size: 15; color: cam.activeProfile.length > 0 ? Theme.accentText : Theme.textMuted }
            Text {
                text: cam.activeProfile.length > 0 ? cam.activeProfile : qsTr("Profiles")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.small + 1
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.maximumWidth: 140
            }
            Icon { name: "chevron-down"; size: 13; color: Theme.textMuted }
        }
    }
    StyledMenu {
        id: profileMenu
        Instantiator {
            model: cam.profiles
            delegate: MenuEntry {
                required property string modelData
                text: (cam.activeProfile === modelData ? "✓  " : "     ") + modelData
                enabled: cam.connected
                onTriggered: cam.applyProfile(modelData)
            }
            onObjectAdded: (index, object) => profileMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => profileMenu.removeItem(object)
        }
        MenuEntry { text: cam.profiles.length === 0 ? qsTr("No profiles yet") : ""; enabled: false; visible: cam.profiles.length === 0; height: visible ? implicitHeight : 0 }
        MenuLine {}
        MenuEntry { text: qsTr("Save current setup as a profile…"); onTriggered: root.saveProfile() }
        MenuEntry { text: qsTr("Manage profiles…"); onTriggered: root.openProfiles() }
    }

    Item { Layout.fillWidth: true }

    AbstractButtonLike { // command search
        id: search
        Layout.preferredWidth: root.compactBar ? 44 : 240
        Layout.minimumWidth: root.compactBar ? 44 : 140
        implicitHeight: 36
        onClicked: root.openPalette()
        Accessible.name: qsTr("Search commands")
        Tip { visible: search.hovered && root.compactBar; text: qsTr("Search commands"); shortcut: "Ctrl K" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 10
            Icon { name: "search"; size: 15; color: Theme.textMuted }
            Text {
                visible: !root.compactBar
                text: qsTr("Search commands")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.small + 1
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Kbd { text: "Ctrl K"; visible: !root.compactBar }
        }
    }

    Btn {
        text: root.compactBar ? "" : cam.values.asleep ? qsTr("Wake") : qsTr("Sleep")
        iconName: "moon"
        compact: false
        implicitHeight: 36
        enabled: cam.connected
        tip: cam.values.asleep ? qsTr("Wake the camera") : qsTr("Put the camera to sleep. Other apps see a privacy screen.")
        shortcut: "Ctrl L"
        onClicked: cam.set("asleep", !cam.values.asleep)
    }
    IconBtn { // sleep timer
        id: sleepMenuBtn
        iconName: "chevron-down"
        tip: cam.values.sleepTimer > 0 ? qsTr("Sleeps after %1 minutes without use").arg(Math.round(cam.values.sleepTimer / 60))
                                       : qsTr("Sleep timer: off")
        implicitWidth: 28
        implicitHeight: 36
        Layout.leftMargin: -8
        enabled: cam.connected
        onClicked: sleepMenu.popup(sleepMenuBtn, 0, sleepMenuBtn.height + 6)
    }
    StyledMenu {
        id: sleepMenu
        MenuEntry { text: qsTr("Sleep after the camera isn't used for…"); enabled: false }
        Instantiator {
            readonly property var seconds: [0, 300, 600, 1800, 3600]
            model: [qsTr("Never"), qsTr("5 minutes"), qsTr("10 minutes"), qsTr("30 minutes"), qsTr("1 hour")]
            delegate: MenuEntry {
                required property int index
                required property string modelData
                text: (cam.values.sleepTimer === [0, 300, 600, 1800, 3600][index] ? "✓  " : "     ") + modelData
                onTriggered: cam.set("sleepTimer", [0, 300, 600, 1800, 3600][index])
            }
            onObjectAdded: (index, object) => sleepMenu.insertItem(index + 1, object)
            onObjectRemoved: (index, object) => sleepMenu.removeItem(object)
        }
    }
    IconBtn {
        id: helpBtn
        iconName: "help"
        tip: qsTr("Help")
        implicitWidth: 36
        implicitHeight: 36
        onClicked: helpMenu.popup(helpBtn, 0, helpBtn.height + 6)
    }
    StyledMenu {
        id: helpMenu
        MenuEntry { text: qsTr("Show the tour"); onTriggered: root.openTour() }
        MenuEntry { text: qsTr("Keyboard shortcuts"); onTriggered: root.openShortcuts() }
        MenuEntry { text: qsTr("Search all commands"); onTriggered: root.openPalette() }
        MenuEntry { text: qsTr("Report a problem…"); onTriggered: root.openReport() }
        MenuEntry { text: qsTr("About Gimbot"); onTriggered: root.openAbout() }
    }
    IconBtn {
        iconName: "gear"
        tip: qsTr("Settings")
        shortcut: "Ctrl ,"
        implicitWidth: 36
        implicitHeight: 36
        onClicked: root.openSettings()
    }
}
