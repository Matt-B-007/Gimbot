// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Remove Gimbot, optionally with its settings, logs and saved SDK.
Sheet {
    id: root
    title: updater.installState === "running" && updater.installAction === "uninstall" ? qsTr("Uninstalling…")
         : updater.installState === "done" && updater.installAction === "uninstall" ? qsTr("Gimbot is uninstalled")
         : qsTr("Uninstall Gimbot?")
    iconName: "alert"
    maxWidth: 480
    closePolicy: busy ? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside
    readonly property bool busy: updater.installState === "running" && updater.installAction === "uninstall"
    readonly property bool finished: updater.installState === "done" && updater.installAction === "uninstall"
    readonly property bool failed: updater.installState === "failed" && updater.installAction === "uninstall"

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
        visible: !updater.canInstall && !root.busy && !root.finished
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
        value: updater.installProgress
    }
    Text {
        Layout.fillWidth: true
        visible: root.busy || root.finished || root.failed
        wrapMode: Text.WordWrap
        color: root.failed ? Theme.danger : Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        text: root.failed ? updater.installError : root.finished ? qsTr("Gimbot will close now. Thanks for trying it.") : updater.installStatus
    }

    buttons: [
        Item { Layout.fillWidth: true },
        Btn { text: qsTr("Cancel"); variant: "ghost"; visible: !root.busy && !root.finished; onClicked: root.close() },
        Btn { text: qsTr("Uninstall"); variant: "danger"; visible: !root.busy && !root.finished; enabled: updater.canInstall
              onClicked: updater.uninstall(purge.checked) },
        Btn { text: qsTr("Close Gimbot"); variant: "primary"; visible: root.finished; onClicked: Qt.quit() }
    ]
}
