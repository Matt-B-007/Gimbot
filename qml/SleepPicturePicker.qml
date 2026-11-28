// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Gimbot

// Which of the camera's three saved pictures it shows while asleep, and
// whether to mirror it. Used on the Asleep screen (over video, so fixed light
// colours) and in Settings (theme colours).
ColumnLayout {
    id: root
    property bool onVideo: false
    readonly property color hoverFill: onVideo ? Qt.rgba(1, 1, 1, 0.1) : Theme.hover // the video is always dark
    property bool showLabel: true // Settings puts the words in the row's label instead
    readonly property color ink: onVideo ? "#e8edf4" : Theme.text
    readonly property color muted: onVideo ? "#9aa6b8" : Theme.textMuted
    readonly property color line: onVideo ? "#364459" : Theme.border
    readonly property color fill: onVideo ? "#131922" : Theme.surface2
    spacing: 8

    Text {
        visible: root.showLabel
        Layout.alignment: root.onVideo ? Qt.AlignHCenter : Qt.AlignLeft
        text: qsTr("Shown on the camera while it sleeps")
        color: root.muted
        font.family: Theme.font
        font.pixelSize: Theme.small
    }
    RowLayout {
        Layout.alignment: root.onVideo ? Qt.AlignHCenter : Qt.AlignLeft
        spacing: 8
        Accessible.role: Accessible.Grouping
        Accessible.name: qsTr("Sleep picture")
        Repeater {
            model: 3
            delegate: AbstractButton {
                id: pic
                required property int index
                readonly property bool chosen: Cam.values.sleepPicture === pic.index
                implicitWidth: 84
                implicitHeight: 44
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                enabled: Cam.connected
                Accessible.checkable: true
                Accessible.checked: pic.chosen
                Accessible.name: qsTr("Picture %1").arg(pic.index + 1)
                onClicked: Cam.set("sleepPicture", pic.index)
                background: Rectangle {
                    radius: 8
                    color: pic.chosen ? (root.onVideo ? "#1a212c" : Theme.accentSoft) : pic.hovered ? root.hoverFill : root.fill
                    border.width: pic.chosen || pic.visualFocus ? 2 : 1
                    border.color: pic.chosen || pic.visualFocus ? Theme.accent : root.line
                }
                contentItem: Text {
                    text: qsTr("Picture %1").arg(pic.index + 1)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: pic.chosen ? root.ink : root.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.small
                    font.weight: Font.DemiBold
                }
            }
        }
        AbstractButton {
            id: mirror
            implicitWidth: mirrorText.implicitWidth + 28
            implicitHeight: 44
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            enabled: Cam.connected
            // What the camera reports, not a local switch: if the camera
            // refuses the change, the button doesn't pretend it worked.
            readonly property bool on: Cam.values.sleepPictureMirrored
            Accessible.checkable: true
            Accessible.checked: mirror.on
            Accessible.name: qsTr("Mirror the sleep picture")
            onClicked: Cam.set("sleepPictureMirrored", !Cam.values.sleepPictureMirrored)
            background: Rectangle {
                radius: 8
                color: mirror.on ? (root.onVideo ? "#1a212c" : Theme.accentSoft) : mirror.hovered ? root.hoverFill : "transparent"
                border.width: mirror.on || mirror.visualFocus ? 2 : 1
                border.color: mirror.on || mirror.visualFocus ? Theme.accent : root.line
            }
            contentItem: Text {
                id: mirrorText
                text: qsTr("Mirror")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: root.ink
                font.family: Theme.font
                font.pixelSize: Theme.small
                font.weight: Font.Medium
            }
        }
    }
}
