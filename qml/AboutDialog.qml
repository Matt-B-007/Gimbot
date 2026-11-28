// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import Gimbot

Sheet {
    id: root
    maxWidth: 460

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "icons/gimbot.svg"
            sourceSize: Qt.size(84, 84)
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "gimbot"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 34
            font.weight: Font.Bold
            font.letterSpacing: -1
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Version %1").arg(Platform.version)
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("An unofficial Linux control app for OBSBOT cameras. Not affiliated with OBSBOT or Remo Tech.")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            lineHeight: 1.2
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            columns: 2
            columnSpacing: 16
            rowSpacing: 6
            Repeater {
                model: [qsTr("OBSBOT SDK"), Platform.sdkVersion, qsTr("Qt"), Platform.qtVersion,
                        qsTr("KDE integration"), Platform.kdeIntegration ? qsTr("Yes") : qsTr("No"),
                        qsTr("Camera firmware"), Cam.connected ? Cam.firmware : "—", qsTr("License"), "MIT"]
                Text {
                    required property int index
                    required property string modelData
                    text: modelData
                    color: index % 2 === 0 ? Theme.textMuted : Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.small + 1
                    Layout.fillWidth: index % 2 === 1
                    elide: Text.ElideRight
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            wrapMode: Text.WordWrap
            text: qsTr("Uses the Inter and Space Grotesk typefaces (SIL Open Font License) and the OBSBOT SDK, which is © Remo Tech and not covered by Gimbot's license.")
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.small - 1
        }
    }

    buttons: [
        Btn { visible: Platform.repoUrl.length > 0; text: qsTr("Project page"); iconName: "external"; variant: "ghost"; onClicked: Platform.openUrl(Platform.repoUrl) },
        Item { Layout.fillWidth: true },
        Btn { text: qsTr("Close"); variant: "primary"; onClicked: root.close() }
    ]
}
