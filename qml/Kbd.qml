import QtQuick

// A small key cap, e.g. "Ctrl K".
Rectangle {
    property alias text: label.text
    property bool onVideo: false
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 20
    radius: 5
    color: "transparent"
    border.width: 1
    border.color: onVideo ? Qt.rgba(1, 1, 1, 0.2) : Theme.borderStrong
    Text {
        id: label
        anchors.centerIn: parent
        color: onVideo ? "#d4d7dc" : Theme.textMuted
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
