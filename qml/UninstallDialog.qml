// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Gimbot

// Remove Gimbot, optionally with its settings, logs and saved SDK.
Sheet {
    id: root
    title: Updater.installState === "running" && Updater.installAction === "uninstall" ? qsTr("Uninstalling…")
         : Updater.installState === "done" && Updater.installAction === "uninstall" ? qsTr("Gimbot is uninstalled")
         : qsTr("Uninstall Gimbot?")
    iconName: "alert"
    maxWidth: 480
    closePolicy: busy ? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside
    readonly property bool busy: Updater.installState === "running" && Updater.installAction === "uninstall"
    readonly property bool finished: Updater.installState === "done" && Updater.installAction === "uninstall"
    readonly property bool failed: Updater.installState === "failed" && Updater.installAction === "uninstall"

    Text {
        Layout.fillWidth: true
        visible: !root.busy && !root.finished
        wrapMode: Text.WordWrap
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        lineHeight: 1.2
        text: qsTr("This removes the Gimbot app. You'll be asked for your password. The camera keeps its own settings and presets.")
    }
    CheckBox {
        id: purge
        visible: !root.busy && !root.finished
        text: qsTr("Also delete my Gimbot settings, logs and the saved OBSBOT SDK")
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        contentItem: Text { leftPadding: purge.indicator.width + 6; text: purge.text; font: purge.font; color: Theme.text; wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter }
        Layout.fillWidth: true
    }
    Text {
        Layout.fillWidth: true
        visible: !Updater.canInstall && !root.busy && !root.finished
        wrapMode: Text.WordWrap
        color: Theme.warning
        font.family: Theme.font
        font.pixelSize: Theme.small + 1
        text: qsTr("This copy of Gimbot wasn't installed with the installer, so remove it from a terminal: sudo pacman -R gimbot")
    }
    ProgressBar {
        visible: root.busy
        Layout.fillWidth: true
        from: 0; to: 100
        value: Updater.installProgress
    }
    Text {
        Layout.fillWidth: true
        visible: root.busy || root.finished || root.failed
        wrapMode: Text.WordWrap
        color: root.failed ? Theme.danger : Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        text: root.failed ? Updater.installError : root.finished ? qsTr("Gimbot will close now. Thanks for trying it.") : Updater.installStatus
    }

    buttons: [
        Item { Layout.fillWidth: true },
        Btn { text: qsTr("Cancel"); variant: "ghost"; visible: !root.busy && !root.finished; onClicked: root.close() },
        Btn { text: qsTr("Uninstall"); variant: "danger"; visible: !root.busy && !root.finished; enabled: Updater.canInstall
              onClicked: Updater.uninstall(purge.checked) },
        Btn { text: qsTr("Close Gimbot"); variant: "primary"; visible: root.finished; onClicked: Qt.quit() }
    ]
}
