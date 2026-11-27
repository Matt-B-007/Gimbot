// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Hover hint: a one-line explanation and, if there is one, the shortcut.
ToolTip {
    id: tip
    property string shortcut: ""
    delay: 450
    timeout: 8000
    padding: 8
    contentItem: RowLayout {
        spacing: 8
        Text {
            text: tip.text
            visible: tip.text.length > 0
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.small
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 300
        }
        Kbd { visible: tip.shortcut.length > 0; text: tip.shortcut }
    }
    background: Rectangle { color: Theme.surface2; radius: 8; border.color: Theme.borderStrong }
}
