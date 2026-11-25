import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// What's new, then one click to install the update.
Sheet {
    id: root
    maxWidth: 560
    iconName: "download"
    readonly property bool rebuilding: updater.installAction === "rebuild"
    title: rebuilding ? (updater.installState === "done" ? qsTr("Rebuilt with the new SDK")
                         : updater.installState === "failed" ? qsTr("The rebuild didn't finish")
                         : qsTr("Rebuilding Gimbot with the new OBSBOT SDK"))
         : updater.installState === "done" ? qsTr("Update installed")
         : updater.installState === "failed" ? qsTr("The update didn't finish")
         : updater.installState === "running" ? qsTr("Updating to Gimbot %1").arg(updater.latestVersion)
         : updater.isSwitch ? qsTr("Switch to Gimbot %1").arg(updater.latestVersion)
         : qsTr("Gimbot %1 is available").arg(updater.latestVersion)
    closePolicy: updater.installState === "running" ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    signal reportRequested()

    readonly property bool idle: updater.installState === "idle"
    readonly property bool running: updater.installState === "running"

    // Release notes, before installing.
    RowLayout {
        visible: root.idle
        spacing: 8
        Rectangle {
            visible: updater.latestIsBeta
            implicitWidth: betaLabel.implicitWidth + 16
            implicitHeight: 24
            radius: 12
            color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.15)
            Text { id: betaLabel; anchors.centerIn: parent; text: qsTr("Beta"); color: Theme.warning; font.family: Theme.font; font.pixelSize: Theme.small; font.weight: Font.DemiBold }
        }
        Text {
            text: updater.isSwitch ? qsTr("You're on beta %1. This installs the newest normal version.").arg(platform.version)
                                   : qsTr("You have %1.").arg(platform.version)
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
            text: updater.latestNotes.length > 0 ? updater.latestNotes : qsTr("No release notes were published for this version.")
            textFormat: Text.MarkdownText
            wrapMode: Text.WordWrap
            color: Theme.text
            linkColor: Theme.accentText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            onLinkActivated: (link) => platform.openUrl(link)
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
                text: updater.installState === "failed" ? updater.installError : updater.installStatus
                color: updater.installState === "failed" ? Theme.danger : Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                visible: root.running
                text: updater.installProgress + "%"
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
                width: parent.width * Math.max(0.02, updater.installProgress / 100)
                height: parent.height
                radius: 3
                color: updater.installState === "failed" ? Theme.danger : updater.installState === "done" ? Theme.success : Theme.accent
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            visible: updater.installState === "done"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Restart Gimbot to start using the new version.")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
        }
        Btn {
            id: logToggle
            property bool open: updater.installState === "failed"
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
                text: updater.installLog
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
            onClicked: platform.openUrl(updater.latestUrl)
        },
        Btn {
            visible: updater.installState === "failed"
            text: qsTr("Report the problem")
            iconName: "bug"
            variant: "ghost"
            onClicked: { root.close(); root.reportRequested() }
        },
        Item { Layout.fillWidth: true },
        Btn {
            visible: root.idle || updater.installState === "failed"
            text: qsTr("Later")
            variant: "ghost"
            onClicked: root.close()
        },
        Btn {
            visible: root.running
            text: qsTr("Cancel")
            variant: "ghost"
            onClicked: updater.cancelInstall()
        },
        Btn {
            visible: root.idle || updater.installState === "failed"
            text: updater.installState === "failed" ? qsTr("Try again") : updater.isSwitch ? qsTr("Switch now") : qsTr("Update now")
            iconName: "download"
            variant: "primary"
            onClicked: root.rebuilding ? updater.rebuild() : updater.install()
        },
        Btn {
            visible: updater.installState === "done"
            text: qsTr("Restart Gimbot")
            iconName: "refresh"
            variant: "primary"
            onClicked: updater.restartApp()
        }
    ]
}
