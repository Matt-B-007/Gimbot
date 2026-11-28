// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Short messages that slide up from the bottom and fade away. A toast can
// carry one button, e.g. Undo or Report. Hovering keeps it on screen.
Item {
    id: root
    property var actions: ({}) // id -> function
    property int nextId: 1

    function show(message, kind, actionText, action) {
        const id = nextId++
        if (action) actions[id] = action
        toastModel.append({ message: message, kind: kind || "info", actionText: actionText || "", tid: id })
        if (toastModel.count > 3) forget(0)
    }
    function forget(i) {
        delete actions[toastModel.get(i).tid]
        toastModel.remove(i)
    }

    ListModel { id: toastModel }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 8
        Repeater {
            model: toastModel
            delegate: Rectangle {
                id: toast
                required property int index
                required property string message
                required property string kind
                required property string actionText
                required property int tid
                readonly property int lifetime: actionText.length > 0 ? 7000 : kind === "error" ? 6000 : 2800
                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                width: Math.min(row.implicitWidth + 32, root.width - 48)
                height: 44
                radius: 22
                color: Theme.surface2
                border.width: 1
                border.color: kind === "error" ? Theme.danger : Theme.borderStrong
                opacity: 0
                Accessible.role: Accessible.AlertMessage
                Accessible.name: message
                Component.onCompleted: { opacity = 1; life.start() }
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                onOpacityChanged: if (opacity === 0 && !life.running) remove.start()
                HoverHandler { id: hover; onHoveredChanged: if (hovered) life.stop(); else life.restart() }
                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 10
                    Icon {
                        name: toast.kind === "error" ? "alert" : toast.actionText.length > 0 ? "info" : "check"
                        color: toast.kind === "error" ? Theme.danger : toast.actionText.length > 0 ? Theme.textMuted : Theme.success
                        size: 16
                    }
                    Text {
                        text: toast.message
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                        Layout.maximumWidth: root.width - 220
                    }
                    Btn {
                        visible: toast.actionText.length > 0
                        text: toast.actionText
                        variant: "ghost"
                        compact: true
                        onClicked: {
                            const fn = root.actions[toast.tid]
                            life.stop()
                            toast.opacity = 0
                            if (fn) fn()
                        }
                    }
                }
                Timer {
                    id: life
                    interval: toast.lifetime
                    onTriggered: toast.opacity = 0
                }
                Timer {
                    id: remove
                    interval: Theme.normal + 50
                    onTriggered: {
                        for (let i = 0; i < toastModel.count; ++i)
                            if (toastModel.get(i).tid === toast.tid) { root.forget(i); break }
                    }
                }
            }
        }
    }
}
