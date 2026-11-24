import QtQuick
import QtQuick.Layouts

Card {
    title: qsTr("Tracking")

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true
        Text { text: qsTr("Framing"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
        Segmented {
            Layout.fillWidth: true
            stretch: true
            options: [qsTr("Full body"), qsTr("Upper body"), qsTr("Close-up")]
            currentIndex: cam.values.mode === 2 ? cam.values.framing : -1
            enabled: cam.connected
            onActivated: (i) => cam.set("framing", i)
        }
    }
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true
        Text { text: qsTr("Style"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
        Segmented {
            Layout.fillWidth: true
            stretch: true
            options: [qsTr("Standard"), qsTr("Headroom"), qsTr("Motion")]
            currentIndex: cam.values.trackStyle
            enabled: cam.connected
            onActivated: (i) => cam.set("trackStyle", i)
        }
    }
}
