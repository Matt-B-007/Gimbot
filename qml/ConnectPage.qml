// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts

// Shown while no camera is connected. The app switches to the camera on its
// own as soon as one is plugged in.
Rectangle {
    id: root
    color: Theme.bg
    signal openSettings()
    signal openReport()

    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 20
        anchors.topMargin: 14
        spacing: 10
        Image { source: "icons/gimbot.svg"; sourceSize: Qt.size(34, 34) }
        Text { text: "Gimbot"; color: Theme.text; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
        Item { Layout.fillWidth: true }
        IconBtn { iconName: "gear"; tip: qsTr("Settings"); onClicked: root.openSettings() }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 520)
        spacing: 24

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 132
            implicitHeight: 132
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: 132; height: 132; radius: 66
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    visible: cam.usbAvailable
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: root.visible
                        PauseAnimation { duration: index * 900 }
                        ParallelAnimation {
                            NumberAnimation { from: 0.55; to: 1.15; duration: 1800; easing.type: Easing.OutCubic }
                        }
                    }
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.visible
                        PauseAnimation { duration: index * 900 }
                        NumberAnimation { from: 0.8; to: 0; duration: 1800; easing.type: Easing.OutCubic }
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 76; height: 76; radius: 24
                color: Theme.surface
                border.color: Theme.border
                Icon { anchors.centerIn: parent; name: cam.usbAvailable ? "camera" : "alert"; size: 34; stroke: 1.6; color: cam.usbAvailable ? Theme.accent : Theme.warning }
            }
        }

        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: cam.usbAvailable ? qsTr("Plug in your OBSBOT camera") : qsTr("Can't look for cameras")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 26
                font.weight: Font.Bold
                font.letterSpacing: -0.4
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: cam.usbAvailable ? qsTr("Gimbot finds it on its own as soon as it's connected. No setup needed.")
                    : platform.sdkVersion === "none" ? qsTr("This copy of Gimbot was built without the OBSBOT SDK, so it can only run the simulated camera (start it with --fake).")
                    : qsTr("This system has no USB device list (/sys/bus/usb/devices), so cameras can't be detected.")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: help.implicitHeight + 32
            radius: Theme.radius + 2
            color: Theme.surface
            border.color: Theme.cardEdge
            ColumnLayout {
                id: help
                x: 16; y: 16
                width: parent.width - 32
                spacing: 6
                Text { text: qsTr("Not showing up?"); color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.small + 1
                    lineHeight: 1.25
                    text: qsTr("Try another USB port or cable. If the camera works in other apps but not here, Gimbot's permission rule may be missing: reinstall the package, or run “sudo udevadm control --reload && sudo udevadm trigger” and replug the camera.")
                }
                Btn {
                    Layout.topMargin: 4
                    text: qsTr("Report a problem")
                    iconName: "bug"
                    variant: "ghost"
                    compact: true
                    onClicked: root.openReport()
                }
            }
        }
    }
}
