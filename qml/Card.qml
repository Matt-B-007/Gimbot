import QtQuick
import QtQuick.Layouts

// A rounded surface with an optional title row, an optional "More" section
// that expands in place, and an optional note that explains why controls are
// unavailable (with a button that fixes it).
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    default property alias content: column.data
    property alias headerExtras: extras.data
    property alias more: moreColumn.data
    property int padding: Theme.pad + 2

    // "More" section. moreKey names the app setting that remembers whether
    // it is open; leave it empty for no "More" section.
    property string moreKey: ""
    property string moreLabel: qsTr("More")
    readonly property bool expanded: moreKey.length > 0 && cam.values[moreKey] === true

    // Shown above the content when set, e.g. "The camera is asleep".
    property string note: ""
    property string noteAction: ""
    signal noteActivated()

    color: Theme.surface
    radius: Theme.radiusLg
    border.width: 1
    border.color: Theme.border
    implicitHeight: outer.implicitHeight + padding * 2
    implicitWidth: 320
    Accessible.role: Accessible.Grouping
    Accessible.name: title

    ColumnLayout {
        id: outer
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: 14

        RowLayout {
            visible: root.title.length > 0
            Layout.fillWidth: true
            spacing: 8
            ColumnLayout {
                spacing: 3
                Layout.fillWidth: true
                Text {
                    text: root.title
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.large
                    font.weight: Font.DemiBold
                    Accessible.role: Accessible.Heading
                }
                Text {
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.small + 1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            Row { id: extras; spacing: 8; Layout.alignment: Qt.AlignVCenter }
        }

        Rectangle { // why controls are unavailable
            visible: root.note.length > 0
            Layout.fillWidth: true
            implicitHeight: noteRow.implicitHeight + 16
            radius: Theme.radius
            color: Theme.surface2
            RowLayout {
                id: noteRow
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 10
                Icon { name: "info"; size: 15; color: Theme.textMuted }
                Text {
                    text: root.note
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.small + 1
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Btn {
                    visible: root.noteAction.length > 0
                    text: root.noteAction
                    variant: "outline"
                    compact: true
                    onClicked: root.noteActivated()
                }
            }
        }

        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: 14
        }

        ColumnLayout {
            id: moreColumn
            Layout.fillWidth: true
            visible: root.expanded
            spacing: 14
        }

        AbstractButtonLike { // More / Less
            visible: root.moreKey.length > 0
            Layout.fillWidth: true
            implicitHeight: 30
            corner: Theme.radiusSm
            background: Rectangle {
                radius: Theme.radiusSm
                color: parent.hovered ? Theme.hover : "transparent"
                border.width: parent.visualFocus ? 2 : 0
                border.color: Theme.accent
            }
            Accessible.name: root.expanded ? qsTr("Show fewer %1 settings").arg(root.title) : qsTr("Show more %1 settings").arg(root.title)
            onClicked: cam.set(root.moreKey, !root.expanded)
            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: root.expanded ? qsTr("Less") : root.moreLabel
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.small + 1
                    font.weight: Font.Medium
                }
                Icon {
                    name: "chevron-down"
                    size: 14
                    color: Theme.textMuted
                    rotation: root.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.fast } }
                }
            }
        }
    }
}
