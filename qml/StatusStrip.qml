// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One line that always says what the camera is doing, with a button that
// fixes whatever needs attention, plus chips for anything that isn't on its
// automatic setting (click a chip to switch it back).
Rectangle {
    id: root
    property string previewError: ""
    property size videoSize: Qt.size(0, 0)
    property real videoFps: 0
    signal retryPreview()
    signal openArea()

    readonly property var v: cam.values
    readonly property var modeNames: ["", qsTr("Group"), qsTr("Person"), qsTr("Hand"), qsTr("Whiteboard"), qsTr("Desk")]
    readonly property var wbNames: [qsTr("Auto"), qsTr("Daylight"), qsTr("Cloudy"), qsTr("Indoor"), qsTr("Fluorescent"), qsTr("Manual")]

    // The most important thing to say, in order.
    readonly property var state: {
        if (!cam.connected) return { tone: "muted", text: qsTr("No camera connected"), action: "" }
        if (v.asleep) return { tone: "warning", text: qsTr("The camera is asleep. Other apps see a privacy screen."), action: qsTr("Wake"), run: () => cam.set("asleep", false) }
        if (previewError.length > 0) return { tone: "warning", text: qsTr("No preview: another app such as Zoom or OBS may be using the camera's video. The controls still work."), action: qsTr("Try again"), run: () => root.retryPreview() }
        if (cam.trackingPaused) return { tone: "warning", text: qsTr("Tracking is paused because you moved the camera."), action: qsTr("Resume tracking"), run: () => cam.resumeTracking() }
        if (!v.previewEnabled) return { tone: "muted", text: qsTr("Preview is off, so other apps can use the camera's video."), action: qsTr("Turn preview on"), run: () => cam.set("previewEnabled", true) }
        let parts = [v.mode !== 0 ? qsTr("Tracking %1").arg(modeNames[v.mode]) : qsTr("Tracking off")]
        if (videoSize.width > 0) parts.push(qsTr("Preview %1×%2 at %3 fps").arg(videoSize.width).arg(videoSize.height).arg(Math.round(videoFps)))
        return { tone: "ok", text: qsTr("Ready") + " · " + parts.join(" · "), action: "" }
    }
    readonly property color toneColor: state.tone === "ok" ? Theme.success : state.tone === "warning" ? Theme.warning : Theme.textFaint

    // Settings that are off their automatic or usual value.
    readonly property var chips: {
        if (!cam.connected) return []
        let c = []
        if (cam.activeProfile.length > 0)
            c.push({ text: qsTr("Profile: %1").arg(cam.activeProfile), tip: qsTr("Change any setting to leave the profile"), run: null })
        if (!v.autoFocus) c.push({ text: qsTr("Manual focus"), tip: qsTr("Click to go back to autofocus"), run: () => cam.set("autoFocus", true) })
        if (!v.exposureAuto) c.push({ text: qsTr("Manual exposure"), tip: qsTr("Click to go back to automatic exposure"), run: () => cam.set("exposureAuto", true) })
        if (v.wbMode !== 0) c.push({ text: qsTr("White balance: %1").arg(wbNames[v.wbMode] || ""), tip: qsTr("Click to go back to automatic white balance"), run: () => cam.set("wbMode", 0) })
        if (v.mirrored) c.push({ text: qsTr("Mirrored"), tip: qsTr("Other apps see the mirrored picture too. Click to stop mirroring."), run: () => cam.set("mirrored", false) })
        if (v.zoneEnabled) c.push({ text: qsTr("Tracking area on"), tip: qsTr("Tracking stays inside the area you set. Click to edit it."), run: () => root.openArea() })
        if (v.invertPan || v.invertTilt) c.push({ text: qsTr("Directions flipped"), tip: qsTr("You flipped the movement directions in Settings. Click to undo."), run: () => { cam.set("invertPan", false); cam.set("invertTilt", false) } })
        return c
    }

    implicitHeight: Math.max(40, row.implicitHeight + 12)
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: state.tone === "warning" ? Qt.rgba(toneColor.r, toneColor.g, toneColor.b, 0.5) : Theme.border
    Accessible.role: Accessible.StatusBar
    Accessible.name: state.text

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 6
        spacing: 10
        Rectangle { width: 8; height: 8; radius: 4; color: root.toneColor }
        Text {
            text: root.state.text
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
            elide: Text.ElideRight
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            Layout.fillWidth: true
            Layout.minimumWidth: 120
        }
        Repeater {
            model: root.width > 1100 ? root.chips : root.chips.slice(0, root.width > 820 ? 2 : 0)
            AbstractButton {
                id: chip
                required property var modelData
                implicitHeight: 26
                implicitWidth: chipText.implicitWidth + 20
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: modelData.text
                Accessible.description: modelData.tip
                onClicked: if (modelData.run) modelData.run()
                HoverHandler { id: chipHover }
                Tip { visible: chipHover.hovered; text: chip.modelData.tip }
                background: Rectangle {
                    radius: 13
                    color: chip.hovered ? Theme.hover : Theme.surface2
                    border.width: chip.visualFocus ? 2 : 1
                    border.color: chip.visualFocus ? Theme.accent : Theme.border
                }
                contentItem: Text {
                    id: chipText
                    text: chip.modelData.text
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.small
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        Btn {
            visible: root.state.action.length > 0
            text: root.state.action
            variant: "outline"
            compact: true
            onClicked: root.state.run()
        }
    }
}
