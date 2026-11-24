import QtQuick
import QtQuick.Layouts

// Short messages that slide up from the bottom and fade away.
Item {
    id: root
    function show(message, kind) {
        model.append({ message: message, kind: kind || "info" })
        if (model.count > 3) model.remove(0)
    }

    ListModel { id: model }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 8
        Repeater {
            model: model
            delegate: Rectangle {
                id: toast
                required property int index
                required property string message
                required property string kind
                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                width: Math.min(row.implicitWidth + 32, root.width - 48)
                height: 44
                radius: 22
                color: Theme.surface2
                border.width: 1
                border.color: kind === "error" ? Theme.danger : Theme.borderStrong
                opacity: 0
                Component.onCompleted: { opacity = 1; life.start() }
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 10
                    Icon {
                        name: toast.kind === "error" ? "alert" : "check"
                        color: toast.kind === "error" ? Theme.danger : Theme.success
                        size: 16
                    }
                    Text {
                        text: toast.message
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                        Layout.maximumWidth: root.width - 120
                    }
                }
                Timer {
                    id: life
                    interval: toast.kind === "error" ? 5000 : 2800
                    onTriggered: toast.opacity = 0
                }
                Timer {
                    interval: (toast.kind === "error" ? 5000 : 2800) + Theme.normal + 50
                    running: true
                    onTriggered: if (toast.index >= 0 && toast.index < model.count) model.remove(toast.index)
                }
            }
        }
    }
}
