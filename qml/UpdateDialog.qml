// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Gimbot

// What's new, then one click to install the update.
Sheet {
    id: root
    maxWidth: 560
    iconName: "download"
    readonly property bool rebuilding: Updater.installAction === "rebuild"
    readonly property bool goingBack: Updater.installAction === "rollback"
    title: goingBack ? (Updater.installState === "done" ? qsTr("Went back to the previous version")
                        : Updater.installState === "failed" ? qsTr("Going back didn't finish")
                        : qsTr("Going back to the previous version"))
         : rebuilding ? (Updater.installState === "done" ? qsTr("Rebuilt with the new SDK")
                         : Updater.installState === "failed" ? qsTr("The rebuild didn't finish")
                         : qsTr("Rebuilding Gimbot with the new OBSBOT SDK"))
         : Updater.installState === "done" ? qsTr("Update installed")
         : Updater.installState === "failed" ? qsTr("The update didn't finish")
         : Updater.installState === "running" ? qsTr("Updating to Gimbot %1").arg(Updater.latestVersion)
         : Updater.isSwitch ? qsTr("Switch to Gimbot %1").arg(Updater.latestVersion)
         : qsTr("Gimbot %1 is available").arg(Updater.latestVersion)
    closePolicy: Updater.installState === "running" ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    signal reportRequested()

    readonly property bool idle: Updater.installState === "idle"
    readonly property bool running: Updater.installState === "running"

    // Release notes, before installing.
    RowLayout {
        visible: root.idle
        spacing: 8
        Rectangle {
            visible: Updater.latestIsBeta
            implicitWidth: betaLabel.implicitWidth + 16
            implicitHeight: 24
            radius: 12
            color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.15)
            Text { id: betaLabel; anchors.centerIn: parent; text: qsTr("Beta"); color: Theme.warning; font.family: Theme.font; font.pixelSize: Theme.small; font.weight: Font.DemiBold }
        }
        Text {
            text: Updater.isSwitch ? qsTr("You're on beta %1. This installs the newest normal version.").arg(Platform.version)
                                   : qsTr("You have %1.").arg(Platform.version)
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
    ScrollView {
        visible: root.idle
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(notes.implicitHeight + 24, 260)
        clip: true
        background: Rectangle { radius: Theme.radius; color: Theme.sunken; border.color: Theme.border }
        Text {
            id: notes
            width: root.availableWidth - 24
            x: 12; y: 12
            text: Updater.latestNotes.length > 0 ? Updater.latestNotes : qsTr("No release notes were published for this version.")
            textFormat: Text.MarkdownText
            wrapMode: Text.WordWrap
            color: Theme.text
            linkColor: Theme.accentText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            onLinkActivated: (link) => Platform.openUrl(link)
        }
    }
    Text {
        visible: root.idle
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Gimbot builds the new version with your saved OBSBOT SDK and installs it. It takes a minute or two, and you'll be asked for your password once.")
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.small + 1
    }

    // Progress.
    ColumnLayout {
        visible: !root.idle
        Layout.fillWidth: true
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: Updater.installState === "failed" ? Updater.installError : Updater.installStatus
                color: Updater.installState === "failed" ? Theme.danger : Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                visible: root.running
                text: Updater.installProgress + "%"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
        }
        Rectangle { // progress bar
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.sunken
            Rectangle {
                width: parent.width * Math.max(0.02, Updater.installProgress / 100)
                height: parent.height
                radius: 3
                color: Updater.installState === "failed" ? Theme.danger : Updater.installState === "done" ? Theme.success : Theme.accent
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            visible: Updater.installState === "done"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Restart Gimbot to start using the new version.")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
        }
        Btn {
            id: logToggle
            property bool open: Updater.installState === "failed"
            text: open ? qsTr("Hide details") : qsTr("Show details")
            iconName: open ? "chevron-up" : "chevron-down"
            variant: "ghost"
            compact: true
            onClicked: open = !open
        }
        ScrollView {
            id: logView
            visible: logToggle.open
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            clip: true
            background: Rectangle { radius: Theme.radiusSm + 2; color: Theme.sunken; border.color: Theme.border }
            TextArea {
                readOnly: true
                text: Updater.installLog
                wrapMode: TextArea.NoWrap
                color: Theme.textMuted
                font.family: "monospace"
                font.pixelSize: 11
                padding: 10
                background: Item {}
                onTextChanged: cursorPosition = length // follow the end
            }
        }
    }

    buttons: [
        Btn {
            visible: root.idle
            text: qsTr("Release page")
            iconName: "external"
            variant: "ghost"
            onClicked: Platform.openUrl(Updater.latestUrl)
        },
        Btn {
            visible: Updater.installState === "failed"
            text: qsTr("Report the problem")
            iconName: "bug"
            variant: "ghost"
            onClicked: { root.close(); root.reportRequested() }
        },
        Item { Layout.fillWidth: true },
        Btn {
            visible: root.idle || Updater.installState === "failed"
            text: qsTr("Later")
            variant: "ghost"
            onClicked: root.close()
        },
        Btn {
            visible: root.running
            text: qsTr("Cancel")
            variant: "ghost"
            onClicked: Updater.cancelInstall()
        },
        Btn {
            visible: root.idle || Updater.installState === "failed"
            text: Updater.installState === "failed" ? qsTr("Try again") : Updater.isSwitch ? qsTr("Switch now") : qsTr("Update now")
            iconName: "download"
            variant: "primary"
            glow: true // the screen's one main action
            onClicked: root.rebuilding ? Updater.rebuild() : Updater.install()
        },
        Btn {
            visible: Updater.installState === "done"
            text: qsTr("Restart Gimbot")
            iconName: "refresh"
            variant: "primary"
            glow: true // the screen's one main action
            onClicked: Updater.restartApp()
        }
    ]
}
