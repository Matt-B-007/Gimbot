// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Gimbot

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

    readonly property var v: Cam.values
    readonly property var modeNames: ["", qsTr("Group"), qsTr("Person"), qsTr("Hand"), qsTr("Whiteboard"), qsTr("Desk")]
    readonly property var wbNames: [qsTr("Auto"), qsTr("Daylight"), qsTr("Cloudy"), qsTr("Indoor"), qsTr("Fluorescent"), qsTr("Manual")]

    // The most important thing to say, in order.
    readonly property var current: { // what the strip shows now
        if (!Cam.connected) return { tone: "muted", text: qsTr("No camera connected"), action: "" }
        if (v.asleep) return { tone: "warning", text: qsTr("The camera is asleep. Other apps see a privacy screen."), action: qsTr("Wake"), run: () => Cam.set("asleep", false) }
        if (previewError.length > 0) return { tone: "warning", text: qsTr("No preview: another app such as Zoom or OBS may be using the camera's video. The controls still work."), action: qsTr("Try again"), run: () => root.retryPreview() }
        if (Cam.trackingPaused) return { tone: "warning", text: qsTr("Tracking is paused because you moved the camera."), action: qsTr("Resume tracking"), run: () => Cam.resumeTracking() }
        if (!v.previewEnabled) return { tone: "muted", text: qsTr("Preview is off, so other apps can use the camera's video."), action: qsTr("Turn preview on"), run: () => Cam.set("previewEnabled", true) }
        let parts = [v.mode !== 0 ? qsTr("Tracking %1").arg(modeNames[v.mode]) : qsTr("Tracking off")]
        if (videoSize.width > 0) parts.push(qsTr("Preview %1×%2 at %3 fps").arg(videoSize.width).arg(videoSize.height).arg(Math.round(videoFps)))
        return { tone: "ok", text: qsTr("Ready") + " · " + parts.join(" · "), action: "" }
    }
    readonly property color toneColor: current.tone === "ok" ? Theme.success : current.tone === "warning" ? Theme.warning : Theme.textFaint

    // Settings that are off their automatic or usual value.
    // One chip per kind, in a fixed list: each chip shows or hides itself.
    // (A list rebuilt on every camera update would remake the chips while
    // the row is being laid out, which can crash Qt's layouts.)
    readonly property var chipKinds: ["profile", "focus", "exposure", "wb", "mirror", "zone", "flip"]
    function chipInfo(kind) {
        if (!Cam.connected) return { on: false, text: "", tip: "", run: null }
        switch (kind) {
        case "profile": return { on: Cam.activeProfile.length > 0, text: qsTr("Profile: %1").arg(Cam.activeProfile), tip: qsTr("Change any setting to leave the profile"), run: null }
        case "focus": return { on: !v.autoFocus, text: qsTr("Manual focus"), tip: qsTr("Click to go back to autofocus"), run: () => Cam.set("autoFocus", true) }
        case "exposure": return { on: !v.exposureAuto, text: qsTr("Manual exposure"), tip: qsTr("Click to go back to automatic exposure"), run: () => Cam.set("exposureAuto", true) }
        case "wb": return { on: v.wbMode !== 0, text: qsTr("White balance: %1").arg(wbNames[v.wbMode] || ""), tip: qsTr("Click to go back to automatic white balance"), run: () => Cam.set("wbMode", 0) }
        case "mirror": return { on: !!v.mirrored, text: qsTr("Mirrored"), tip: qsTr("Other apps see the mirrored picture too. Click to stop mirroring."), run: () => Cam.set("mirrored", false) }
        case "zone": return { on: !!v.zoneEnabled, text: qsTr("Tracking area on"), tip: qsTr("Tracking stays inside the area you set. Click to edit it."), run: () => root.openArea() }
        case "flip": return { on: v.invertPan || v.invertTilt, text: qsTr("Directions flipped"), tip: qsTr("You flipped the movement directions in Settings. Click to undo."), run: () => { Cam.set("invertPan", false); Cam.set("invertTilt", false) } }
        }
        return { on: false, text: "", tip: "", run: null }
    }
    readonly property var activeChips: chipKinds.filter(k => chipInfo(k).on)
    readonly property int maxChips: width > 1100 ? chipKinds.length : width > 820 ? 2 : 0

    implicitHeight: Math.max(40, row.implicitHeight + 12)
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: current.tone === "warning" ? Qt.rgba(toneColor.r, toneColor.g, toneColor.b, 0.5) : Theme.border
    Accessible.role: Accessible.StatusBar
    Accessible.name: current.text

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 6
        spacing: 10
        Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: root.toneColor }
        Text {
            text: root.current.text
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
            model: root.chipKinds
            AbstractButton {
                id: chip
                required property string modelData // the kind
                readonly property var info: root.chipInfo(modelData)
                visible: info.on && root.activeChips.indexOf(modelData) < root.maxChips
                implicitHeight: 26
                implicitWidth: chipText.implicitWidth + 20
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: info.text
                Accessible.description: info.tip
                onClicked: if (info.run) info.run()
                HoverHandler { id: chipHover }
                Tip { visible: chipHover.hovered; text: chip.info.tip }
                background: Rectangle {
                    radius: 13
                    color: chip.hovered ? Theme.hover : Theme.surface2
                    border.width: chip.visualFocus ? 2 : 1
                    border.color: chip.visualFocus ? Theme.accent : Theme.border
                }
                contentItem: Text {
                    id: chipText
                    text: chip.info.text
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
            visible: root.current.action.length > 0
            text: root.current.action
            variant: "outline"
            compact: true
            onClicked: root.current.run()
        }
    }
}
