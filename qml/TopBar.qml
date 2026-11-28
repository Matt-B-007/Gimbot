// SPDX-License-Identifier: MIT
import QtQuick
import QtQml.Models
import QtQuick.Layouts
import Gimbot

// App bar: logo, camera chip, profile switcher, command search, sleep, help
// and settings.
RowLayout {
    id: root
    property bool hideUpdate: false // the README pictures show no pending update
    signal openPalette()
    signal openSettings()
    signal openProfiles()
    signal saveProfile()
    signal openTour()
    signal openReport()
    signal openAbout()
    signal openShortcuts()
    signal openUpdate()
    spacing: 10
    readonly property bool compactBar: width < 980

    Text { // the logo lives in the strip on the left now
        text: qsTr("Studio")
        color: Theme.text
        font.family: Theme.displayFont
        font.pixelSize: 24
        font.letterSpacing: -0.2
        Accessible.role: Accessible.Heading
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
                implicitWidth: 8; implicitHeight: 8; radius: 4
                color: !Cam.connected ? Theme.textFaint : Cam.values.asleep ? Theme.warning : Theme.success
            }
            Text {
                text: Cam.connected ? Cam.model : qsTr("No camera")
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
        Accessible.name: Cam.activeProfile.length > 0 ? qsTr("Profile: %1. Switch profile").arg(Cam.activeProfile) : qsTr("Switch profile")
        onClicked: profileMenu.popup(profileBtn, 0, profileBtn.height + 6)
        Tip { visible: profileBtn.hovered && !profileMenu.visible; text: qsTr("Switch your whole setup at once, like “Meetings” or “Streaming”") }
        RowLayout {
            id: profileRow
            anchors.centerIn: parent
            spacing: 7
            Icon { name: "layers"; size: 15; color: Cam.activeProfile.length > 0 ? Theme.accentText : Theme.textMuted }
            Text {
                text: Cam.activeProfile.length > 0 ? Cam.activeProfile : qsTr("Profiles")
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
            model: Cam.profiles
            delegate: MenuEntry {
                required property string modelData
                text: (Cam.activeProfile === modelData ? "✓  " : "     ") + modelData
                enabled: Cam.connected
                onTriggered: Cam.applyProfile(modelData)
            }
            onObjectAdded: (index, object) => profileMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => profileMenu.removeItem(object)
        }
        MenuEntry { text: Cam.profiles.length === 0 ? qsTr("No profiles yet") : ""; enabled: false; visible: Cam.profiles.length === 0; height: visible ? implicitHeight : 0 }
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
        text: root.compactBar ? "" : Cam.values.asleep ? qsTr("Wake") : qsTr("Sleep")
        iconName: "moon"
        compact: false
        implicitHeight: 36
        enabled: Cam.connected
        tip: Cam.values.asleep ? qsTr("Wake the camera") : qsTr("Put the camera to sleep. Other apps see a privacy screen.")
        shortcut: "Ctrl L"
        onClicked: Cam.set("asleep", !Cam.values.asleep)
    }
    IconBtn { // sleep timer
        id: sleepMenuBtn
        iconName: "chevron-down"
        tip: sleepMenu.visible ? "" // the menu says it itself
           : Cam.values.sleepTimer > 0 ? qsTr("Sleeps after %1 minutes without use").arg(Math.round(Cam.values.sleepTimer / 60))
                                       : qsTr("Sleep timer: off")
        implicitWidth: 28
        implicitHeight: 36
        Layout.leftMargin: -8
        enabled: Cam.connected
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
                text: (Cam.values.sleepTimer === [0, 300, 600, 1800, 3600][index] ? "✓  " : "     ") + modelData
                onTriggered: Cam.set("sleepTimer", [0, 300, 600, 1800, 3600][index])
            }
            onObjectAdded: (index, object) => sleepMenu.insertItem(index + 1, object)
            onObjectRemoved: (index, object) => sleepMenu.removeItem(object)
        }
    }
    Btn { // shown while an update is ready; opens the update dialog
        visible: !root.hideUpdate && Updater.state === "available" && Updater.installState === "idle"
        text: root.compactBar ? "" : qsTr("Update ready")
        iconName: "download"
        variant: "secondary"
        tip: qsTr("Gimbot %1 is ready to install").arg(Updater.latestVersion)
        onClicked: root.openUpdate()
        Rectangle { // amber dot: needs attention
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
            width: 8
            height: 8
            radius: 4
            color: Theme.warning
        }
    }
}
