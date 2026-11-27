import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Gathers details for a bug report. Nothing leaves the computer unless the
// user saves or copies it, or opens a GitHub issue (summary and header only,
// after a warning; the saved file is attached by hand).
Sheet {
    id: root
    title: qsTr("Report a problem")
    iconName: "bug"
    maxWidth: 680
    signal done(string message)
    property bool warnOnOpen: false // screenshots
    function showGithubWarning() { warnOnOpen = true; githubWarning.visible = true }

    onOpened: { summary.text = ""; what.text = ""; githubWarning.visible = warnOnOpen; warnOnOpen = false; details.text = platform.diagnostics(serialBox.checked) }

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
        // Long log lines scroll sideways instead of widening the dialog.
        implicitWidth: 200
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

    // The warning before anything goes to GitHub.
    Rectangle {
        id: githubWarning
        visible: false
        Layout.fillWidth: true
        implicitHeight: warnCol.implicitHeight + 24
        radius: Theme.radiusSm + 2
        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
        border.color: Theme.warning
        ColumnLayout {
            id: warnCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: platform.repoPublic
                      ? qsTr("This creates a PUBLIC issue that anyone can read.")
                      : qsTr("This creates an issue that only the owner of the repository can see.")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Only your summary and the first lines of the details (versions, system and camera) go into the issue. The full report is saved as a file in your Downloads folder; please attach it to the issue.")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.small
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Btn { text: qsTr("Cancel"); variant: "ghost"; compact: true; onClicked: githubWarning.visible = false }
                Btn {
                    text: qsTr("Save the report and open GitHub")
                    iconName: "external"
                    compact: true
                    onClicked: {
                        if (platform.openIssue(summary.text, what.text, serialBox.checked)) {
                            root.done(qsTr("Report saved. Attach %1 to the issue.").arg(platform.lastReport.split("/").pop()))
                            platform.showSavedReport()
                            root.close()
                        }
                    }
                }
            }
        }
    }

    buttons: [
        Btn { text: qsTr("Open log folder"); iconName: "folder"; variant: "ghost"; onClicked: platform.openLogFolder() },
        Btn {
            visible: platform.issuesConfigured
            text: qsTr("Open on GitHub…")
            iconName: "external"
            variant: "ghost"
            onClicked: githubWarning.visible = true
        },
        Item { Layout.fillWidth: true },
        Btn {
            text: qsTr("Copy report")
            iconName: "copy"
            onClicked: {
                platform.copyToClipboard(platform.reportText(summary.text, what.text, serialBox.checked))
                root.done(qsTr("Report copied"))
            }
        },
        Btn {
            text: qsTr("Save to file")
            iconName: "download"
            variant: "primary"
            onClicked: {
                const path = platform.saveReport(summary.text, what.text, serialBox.checked)
                if (path.length > 0) {
                    root.done(qsTr("Report saved to %1").arg(path.replace(/^.*\/(Downloads|[^/]+)\//, "$1/")))
                    platform.showSavedReport()
                    root.close()
                }
            }
        }
    ]
}
