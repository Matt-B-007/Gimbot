import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// First-run tour: four short tips, each pointing at the part of the screen
// it's about. Skippable; replay it from Help › Show the tour.
Popup {
    id: root
    property var targets: null // StudioPage.tourTargets
    property int step: 0
    readonly property var steps: [
        { target: "tracking", title: qsTr("Tracking"),
          text: qsTr("This switch turns tracking on and off. Pick what to track (Person, Group, Hand…) on the bar at the bottom of the picture.") },
        { target: "preview", title: qsTr("Point the camera"),
          text: qsTr("Click anywhere in the picture to point the camera there. Press and drag to steer, scroll to zoom. The arrow keys work too.") },
        { target: "presets", title: qsTr("Presets"),
          text: qsTr("Save the current view and come back to it with one click, or with Ctrl+1, 2, 3.") },
        { target: "bar", title: qsTr("Find anything"),
          text: qsTr("Press Ctrl+K to search every command. Help (?) has this tour, shortcuts and bug reports.") }
    ]
    readonly property Item target: targets ? targets[steps[step].target] : null
    readonly property rect hole: {
        if (!target || !visible) return Qt.rect(0, 0, 0, 0)
        const p = target.mapToItem(Overlay.overlay, 0, 0)
        return Qt.rect(p.x - 6, p.y - 6, target.width + 12, Math.min(target.height, parent ? parent.height : 9999) + 12)
    }
    signal finished()

    parent: Overlay.overlay
    x: 0; y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape
    onOpened: step = 0
    onClosed: finished()
    Overlay.modal: Item {}
    background: Item {}

    function next() { if (step < steps.length - 1) step++; else close() }

    contentItem: Item {
        // Dim everything except the highlighted part.
        Rectangle { x: 0; y: 0; width: parent.width; height: root.hole.y; color: Theme.scrim }
        Rectangle { x: 0; y: root.hole.y + root.hole.height; width: parent.width; height: parent.height - y; color: Theme.scrim }
        Rectangle { x: 0; y: root.hole.y; width: root.hole.x; height: root.hole.height; color: Theme.scrim }
        Rectangle { x: root.hole.x + root.hole.width; y: root.hole.y; width: parent.width - x; height: root.hole.height; color: Theme.scrim }
        Rectangle {
            x: root.hole.x; y: root.hole.y; width: root.hole.width; height: root.hole.height
            color: "transparent"; radius: Theme.radiusLg; border.width: 2; border.color: Theme.accent
        }

        Rectangle { // the tip
            id: bubble
            width: Math.min(360, parent.width - 32)
            height: col.implicitHeight + 36
            radius: Theme.radiusLg
            color: Theme.surface
            border.width: 1
            border.color: Theme.borderStrong
            // Beside the highlight if there's room, otherwise above or below it.
            x: {
                const right = root.hole.x + root.hole.width + 16
                if (right + width < parent.width - 16) return right
                if (root.hole.x - width - 16 > 16) return root.hole.x - width - 16
                return Math.max(16, Math.min(parent.width - width - 16, root.hole.x + root.hole.width / 2 - width / 2))
            }
            y: {
                const besides = x >= root.hole.x + root.hole.width || x + width <= root.hole.x
                if (besides) return Math.max(16, Math.min(parent.height - height - 16, root.hole.y + 8))
                const below = root.hole.y + root.hole.height + 16
                return below + height < parent.height - 16 ? below : Math.max(16, root.hole.y - height - 16)
            }
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10
                Text {
                    text: qsTr("%1 of %2").arg(root.step + 1).arg(root.steps.length)
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.small
                }
                Text {
                    text: root.steps[root.step].title
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.large
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.steps[root.step].text
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Btn { text: qsTr("Skip tour"); variant: "ghost"; compact: true; visible: root.step < root.steps.length - 1; onClicked: root.close() }
                    Item { Layout.fillWidth: true }
                    Btn { text: qsTr("Back"); variant: "ghost"; compact: true; visible: root.step > 0; onClicked: root.step-- }
                    Btn {
                        text: root.step < root.steps.length - 1 ? qsTr("Next") : qsTr("Done")
                        variant: "primary"
                        compact: true
                        focus: true
                        onClicked: root.next()
                    }
                }
            }
        }
        Keys.onRightPressed: root.next()
        Keys.onLeftPressed: if (root.step > 0) root.step--
    }
}
