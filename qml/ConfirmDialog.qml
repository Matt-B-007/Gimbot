import QtQuick
import QtQuick.Layouts

// "Are you sure?" for actions that can't be undone.
Sheet {
    id: root
    property string message: ""
    property string confirmText: qsTr("Delete")
    property var onConfirm: null
    iconName: "alert"
    maxWidth: 440

    Text {
        Layout.fillWidth: true
        text: root.message
        wrapMode: Text.WordWrap
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        lineHeight: 1.2
    }

    buttons: [
        Item { Layout.fillWidth: true },
        Btn { text: qsTr("Cancel"); variant: "ghost"; onClicked: root.close() },
        Btn {
            text: root.confirmText
            variant: "danger"
            onClicked: { if (root.onConfirm) root.onConfirm(); root.close() }
        }
    ]
}
