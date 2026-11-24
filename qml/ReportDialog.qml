import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Gathers details for a bug report. Nothing leaves the computer unless the
// user copies it or opens the pre-filled GitHub issue.
Sheet {
    id: root
    title: qsTr("Report a problem")
    iconName: "bug"
    maxWidth: 640
    signal done(string message)

    onOpened: { summary.text = ""; what.text = ""; details.text = platform.diagnostics(serialBox.checked) }

    Field { id: summary; Layout.fillWidth: true; placeholderText: qsTr("Short summary, e.g. “Zoom slider does nothing”") }

    TextArea {
        id: what
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        placeholderText: qsTr("What happened, and what did you expect?")
        placeholderTextColor: Theme.textFaint
        wrapMode: TextArea.Wrap
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        padding: 12
        background: Rectangle {
            radius: Theme.radiusSm + 2
            color: Theme.surface2
            border.width: what.activeFocus ? 2 : 1
            border.color: what.activeFocus ? Theme.accent : Theme.border
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: qsTr("Details that will be included")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.small
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        CheckBox {
            id: serialBox
            text: qsTr("Include serial number")
            checked: false
            font.family: Theme.font
            font.pixelSize: Theme.small
            onToggled: details.text = platform.diagnostics(checked)
            contentItem: Text { leftPadding: parent.indicator.width + 6; text: parent.text; font: parent.font; color: Theme.textMuted; verticalAlignment: Text.AlignVCenter }
        }
    }

    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 190
        clip: true
        background: Rectangle { radius: Theme.radiusSm + 2; color: Theme.sunken; border.color: Theme.border }
        TextArea {
            id: details
            readOnly: true
            wrapMode: TextArea.NoWrap
            color: Theme.textMuted
            font.family: "monospace"
            font.pixelSize: 11
            padding: 10
            selectByMouse: true
            background: Item {}
        }
    }

    Text {
        visible: !platform.issuesConfigured
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("This build has no project page set, so copy the report and send it to whoever gave you Gimbot.")
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.small
    }

    buttons: [
        Btn { text: qsTr("Open log folder"); iconName: "folder"; variant: "ghost"; onClicked: platform.openLogFolder() },
        Item { Layout.fillWidth: true },
        Btn {
            text: qsTr("Copy report")
            iconName: "copy"
            onClicked: {
                platform.copyToClipboard((summary.text.length ? summary.text + "\n\n" : "") + (what.text.length ? what.text + "\n\n" : "") + details.text)
                root.done(qsTr("Report copied to the clipboard"))
            }
        },
        Btn {
            visible: platform.issuesConfigured
            text: qsTr("Open on GitHub")
            iconName: "external"
            variant: "primary"
            onClicked: {
                platform.openIssue(summary.text, what.text, serialBox.checked)
                root.close()
            }
        }
    ]
}
