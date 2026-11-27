// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts

// Asks for a name (new preset, rename, new profile).
Sheet {
    id: root
    property string placeholder: ""
    property string acceptText: qsTr("Save")
    property alias value: field.text
    signal accepted(string name)
    maxWidth: 420

    onOpened: { field.forceActiveFocus(); field.selectAll() }

    Field {
        id: field
        Layout.fillWidth: true
        placeholderText: root.placeholder
        maximumLength: 31
        onAccepted: if (text.trim().length > 0) { root.accepted(text.trim()); root.close() }
    }

    buttons: [
        Item { Layout.fillWidth: true },
        Btn { text: qsTr("Cancel"); variant: "ghost"; onClicked: root.close() },
        Btn {
            text: root.acceptText
            variant: "primary"
            enabled: field.text.trim().length > 0
            onClicked: { root.accepted(field.text.trim()); root.close() }
        }
    ]
}
