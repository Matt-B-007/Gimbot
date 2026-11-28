// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Gimbot

// The camera's status light: blue while it tracks you. Its brightness is
// shown as Off / 1 / 2 / 3. The OBSBOT SDK reports the level but has no call
// to change it, so the control shows the camera's setting and says where to
// change it; it becomes a working control if a future SDK allows that.
Card {
    id: root
    title: qsTr("Status light")
    subtitle: qsTr("Blue while the camera is tracking you")
    readonly property int level: Cam.values.ledLevel
    readonly property bool known: Cam.connected && level >= 0
    // The dot beside the title is lit only while the camera's own light is: tracking, and not switched off.
    readonly property bool lit: known && level > 0 && Cam.values.mode !== 0 && !Cam.trackingPaused && !Cam.values.asleep

    headerExtras: Rectangle { // the light itself
        implicitWidth: 14
        implicitHeight: 14
        radius: 7
        color: root.lit ? Theme.ledBlue : Theme.borderStrong
        opacity: root.lit ? 0.5 + root.level / 6 : 1
        Glow { radius: parent.radius; color: Qt.rgba(Theme.ledBlue.r, Theme.ledBlue.g, Theme.ledBlue.b, 0.5); on: root.lit }
        Accessible.ignored: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: qsTr("Brightness")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
        Rectangle {
            implicitWidth: levels.implicitWidth + 8
            implicitHeight: levels.implicitHeight + 8
            radius: Theme.radiusSm + 2
            color: Theme.surface2
            Accessible.role: Accessible.Grouping
            Accessible.name: root.known ? qsTr("Status light brightness: %1 (read only)").arg(root.level === 0 ? qsTr("off") : root.level)
                                        : qsTr("Status light brightness: not reported")
            RowLayout {
                id: levels
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: [qsTr("Off"), "1", "2", "3"]
                    delegate: Rectangle {
                        id: seg
                        required property int index
                        required property string modelData
                        readonly property bool lit: root.known && root.level === seg.index
                        implicitWidth: Math.max(40, segText.implicitWidth + 20)
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: seg.lit ? Theme.ledBlue : "transparent"
                        Text {
                            id: segText
                            anchors.centerIn: parent
                            text: seg.modelData
                            color: seg.lit ? "#0c1016" : Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: Theme.small
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: root.known
              ? qsTr("Shows the camera's setting. Changing it needs a newer OBSBOT SDK; for now use OBSBOT Center on Windows or macOS.")
              : qsTr("The camera hasn't reported its light level yet.")
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.small
    }
}
