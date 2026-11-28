// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Window
import QtQml.Models
import Gimbot

// Live video with double-click-to-aim, drag-to-steer, scroll-to-zoom, the framing
// grid, the preview bar (quality, grid, preview on/off) and the floating
// tracking-mode dock.
Rectangle {
    id: root
    property bool windowVisible: true
    readonly property bool videoRunning: qcam.active && error.length === 0 && device !== null
    property string error: ""
    property real aimX: -1
    property real aimY: -1
    property bool clickedOnce: false // the hover hint stops once you've used the preview
    property bool zoneEditing: false // the zone is drawn on the picture to edit
    readonly property size videoSize: videoRunning ? qcam.cameraFormat.resolution : Qt.size(0, 0)
    readonly property real videoFps: videoRunning ? qcam.cameraFormat.maxFrameRate : 0

    // Pick the format: the user's resolution and frame rate if they chose one
    // the camera offers, otherwise the sharpest smooth one for the preview's
    // size on screen. Debounced so resizing doesn't restart the video on
    // every pixel.
    readonly property string choice: Cam.values.previewChoice || ""
    readonly property bool autoQuality: choice.length === 0
    // What the camera really offers, for the menu.
    readonly property var formatChoices: root.device !== null ? Platform.previewChoices(root.device) : []
    readonly property string currentLabel: videoRunning && videoSize.width > 0
        ? Platform.formatLabel(videoSize.width, videoSize.height, Math.round(videoFps)) : ""
    readonly property int targetHeight: Math.round(height * Screen.devicePixelRatio)
    onTargetHeightChanged: formatTimer.restart()
    onDeviceChanged: formatTimer.restart()
    Connections {
        target: Cam
        function onValuesChanged() { if (root.choice !== root.appliedFor) formatTimer.restart() }
    }
    property var appliedDevice: null
    property string appliedFor: "-" // the choice last applied ("-": none yet)
    function chooseFormat() {
        if (root.device === null) return
        const f = Platform.previewFormat(root.device, root.targetHeight, root.choice)
        if (f.resolution.width <= 0) return
        const cur = qcam.cameraFormat
        if (cur.resolution.width === f.resolution.width && cur.resolution.height === f.resolution.height
                && cur.maxFrameRate === f.maxFrameRate && cur.pixelFormat === f.pixelFormat) return
        // Changing format restarts the video, so in Auto only step up when the
        // window grows; a sharper picture in a smaller window is fine.
        const sameChoice = appliedDevice === root.device && appliedFor === root.choice
        appliedDevice = root.device
        appliedFor = root.choice
        if (root.autoQuality && sameChoice && cur.resolution.height >= f.resolution.height) return
        qcam.cameraFormat = f
    }
    Timer { id: formatTimer; interval: 500; onTriggered: root.chooseFormat() }
    Component.onCompleted: formatTimer.start()

    color: Theme.video
    radius: 20
    clip: true
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)

    function retry() {
        root.error = ""
        qcam.active = false
        qcam.active = Qt.binding(() => root.device !== null && Cam.values.previewEnabled && !Cam.values.asleep && root.windowVisible)
    }

    function grabThumbnail(path, callback) {
        if (!videoRunning) { callback(false); return }
        output.grabToImage(function (result) { callback(result.saveToFile(path)) }, Qt.size(480, 270))
    }

    MediaDevices { id: devices }
    readonly property var device: {
        const inputs = devices.videoInputs
        for (let i = 0; i < inputs.length; ++i)
            if (/obsbot|tiny/i.test(inputs[i].description)) return inputs[i]
        return null
    }

    CaptureSession {
        camera: Camera {
            id: qcam
            cameraDevice: root.device !== null ? root.device : devices.defaultVideoInput
            active: root.device !== null && Cam.values.previewEnabled && !Cam.values.asleep && root.windowVisible
            onErrorOccurred: (code, message) => {
                root.error = message.length > 0 ? message : qsTr("The camera couldn't start")
                console.warn("Preview error:", message)
            }
            onActiveChanged: if (active) root.error = ""
        }
        videoOutput: output
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        visible: root.videoRunning
    }

    // A faint dot grid behind the empty preview (the family detail); off with
    // "Plain background" or when animations are off.
    Canvas {
        anchors.fill: parent
        visible: !root.videoRunning && !Cam.values.plainBackground && !Platform.reduceMotion
        opacity: 0.045
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "#ffffff"
            const step = 18
            for (let y = step / 2; y < height; y += step)
                for (let x = step / 2; x < width; x += step)
                    ctx.fillRect(x - 1, y - 1, 2, 2)
        }
    }

    // Shown when there is no picture: what's going on, and what to do.
    ColumnLayout {
        id: statePanel
        z: 3 // above the picture's click area, so its buttons can be pressed
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 480)
        spacing: 12
        visible: !root.videoRunning && !Cam.values.asleep
        readonly property bool busy: root.error.length > 0
        readonly property bool off: !Cam.values.previewEnabled
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 60
            implicitHeight: 60
            radius: 30
            color: statePanel.busy ? Qt.rgba(0.984, 0.749, 0.141, 0.10) : "#1a212c"
            border.color: statePanel.busy ? Qt.rgba(0.984, 0.749, 0.141, 0.45) : "#364459"
            Icon {
                anchors.centerIn: parent
                name: statePanel.busy ? "alert" : statePanel.off ? "eye-off" : "camera"
                color: statePanel.busy ? "#fbbf24" : "#9aa6b8"
                size: 28
                stroke: 1.8
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#e8edf4"
            font.family: Theme.displayFont
            font.pixelSize: 22
            text: statePanel.busy ? qsTr("Another app is using the picture")
                : statePanel.off ? qsTr("Preview is off")
                : Cam.simulated ? qsTr("Simulated camera, no video")
                : root.device === null ? qsTr("Looking for the camera's video…")
                : qsTr("Starting preview…")
        }
        Text {
            Layout.fillWidth: true
            visible: statePanel.busy || statePanel.off || Cam.simulated
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.15
            color: "#9aa6b8"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            text: statePanel.busy
                ? qsTr("A video call or recording app has the camera's video, so the preview can't show it here. Tracking, aiming, zoom and presets still work.")
                : statePanel.off ? qsTr("The camera carries on as it was: tracking, aiming, zoom and presets all still work. With the preview off, Gimbot uses less power and leaves the video free for other apps.")
                : qsTr("Every control works; settings are kept in memory.")
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 10
            visible: statePanel.busy || statePanel.off
            Btn {
                variant: "primary"
                glow: true
                text: statePanel.busy ? qsTr("Try the preview again") : qsTr("Turn the preview on")
                onClicked: {
                    if (statePanel.off) { Cam.set("previewEnabled", true); return }
                    root.retry()
                }
            }
            Btn {
                visible: statePanel.busy
                variant: "ghost"
                text: qsTr("Hide the preview")
                onClicked: Cam.set("previewEnabled", false)
            }
        }
        Text {
            Layout.fillWidth: true
            visible: statePanel.busy
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#9aa6b8"
            font.family: Theme.font
            font.pixelSize: Theme.small
            text: qsTr("The preview comes back by itself when the other app lets go of the camera.")
        }
    }

    // Rule-of-thirds guide.
    Item {
        anchors.fill: parent
        visible: Cam.values.showGrid && !Cam.values.asleep
        Repeater {
            model: 2
            Rectangle { required property int index; x: root.width * (index + 1) / 3; width: 1; height: root.height; color: Qt.rgba(1, 1, 1, 0.07) }
        }
        Repeater {
            model: 2
            Rectangle { required property int index; y: root.height * (index + 1) / 3; height: 1; width: root.width; color: Qt.rgba(1, 1, 1, 0.07) }
        }
    }

    // Double-click to aim; press and drag to steer like a joystick (the further
    // you drag, the faster it moves); scroll to zoom.
    MouseArea {
        id: pointer
        anchors.fill: parent
        preventStealing: true // or the page's scrolling takes an up-and-down drag
        enabled: Cam.connected && !Cam.values.asleep && !root.zoneEditing
        hoverEnabled: true
        cursorShape: !enabled ? Qt.ArrowCursor : steering ? Qt.SizeAllCursor : Qt.CrossCursor
        acceptedButtons: Qt.LeftButton
        property real pressX: 0
        property real pressY: 0
        property bool steering: false
        readonly property real reach: Math.min(width, height) * 0.35 // drag this far for full speed
        onPressed: (mouse) => { pressX = mouse.x; pressY = mouse.y; steering = false }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            const dx = mouse.x - pressX, dy = mouse.y - pressY
            if (!steering && Math.hypot(dx, dy) < 8) return
            steering = true
            const ease = (v) => Math.sign(v) * Math.min(1, Math.pow(Math.abs(v), 1.5)) // gentle near the start
            Cam.move(ease(-dy / reach), ease(dx / reach))
        }
        onReleased: (mouse) => { if (steering) { steering = false; Cam.stopMove() } }
        // Double-click to point the camera there (a single click is too easy
        // to make by accident while reaching for something else).
        onDoubleClicked: (mouse) => {
            root.clickedOnce = true
            // Map to the picture itself, not the letterboxed area around it.
            const r = root.videoRunning ? output.contentRect : Qt.rect(0, 0, width, height)
            const x = (mouse.x - r.x) / r.width, y = (mouse.y - r.y) / r.height
            if (x < 0 || x > 1 || y < 0 || y > 1) return
            root.aimX = mouse.x
            root.aimY = mouse.y
            reticle.opacity = 1
            fade.restart()
            Cam.aimAt(x, y)
        }
        onCanceled: if (steering) { steering = false; Cam.stopMove() }
        onWheel: (wheel) => Cam.zoomBy(wheel.angleDelta.y > 0 ? 5 : -5)
    }

    // Drag-to-steer: a line from where you pressed to the pointer.
    Canvas {
        id: steerLine
        anchors.fill: parent
        visible: pointer.steering
        onVisibleChanged: requestPaint()
        Connections {
            target: pointer
            function onMouseXChanged() { if (pointer.steering) steerLine.requestPaint() }
            function onMouseYChanged() { if (pointer.steering) steerLine.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (!pointer.steering) return
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 2
            ctx.globalAlpha = 0.9
            ctx.beginPath(); ctx.arc(pointer.pressX, pointer.pressY, 6, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(pointer.pressX, pointer.pressY); ctx.lineTo(pointer.mouseX, pointer.mouseY); ctx.stroke()
        }
    }

    Tip {
        visible: !root.clickedOnce && pointer.containsMouse && !pointer.pressed && Cam.connected && !Cam.values.asleep && !bar.hovered
        // Inside the picture, bottom left: its usual place above would cover the top bar.
        x: 16
        y: root.height - height - 70
        text: qsTr("Double-click to point the camera here · drag to steer · scroll to zoom")
    }

    Item {
        id: reticle
        x: root.aimX - 22
        y: root.aimY - 22
        width: 44
        height: 44
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Rectangle { anchors.fill: parent; radius: 22; color: "transparent"; border.width: 2; border.color: Theme.accent }
        Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: Theme.accent }
        Timer { id: fade; interval: 900; onTriggered: reticle.opacity = 0 }
    }

    ZoneOverlay {
        // Over the video itself, not the black bars beside a picture that
        // isn't 16:9.
        readonly property rect picture: root.videoRunning ? output.contentRect : Qt.rect(0, 0, root.width, root.height)
        x: picture.x
        y: picture.y
        width: picture.width
        height: picture.height
        visible: root.zoneEditing && !Cam.values.asleep
        z: 5
    }
    // While tracking, blue corner brackets frame the picture, matching the
    // camera's status light.
    Brackets {
        anchors.fill: parent
        anchors.margins: 10
        arm: 26
        thickness: 2.5
        inset: 0
        color: Theme.ledBlue
        opacity: Cam.values.mode !== 0 && !Cam.trackingPaused && !Cam.values.asleep ? 0.9 : 0
    }
    Text { // the double-click hint, while there's room for it
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18
        visible: root.width > 900 && Cam.connected && !Cam.values.asleep && !pointer.steering && !root.clickedOnce
        text: qsTr("Double-click to point the camera there")
        color: "#9aa6b8"
        font.family: Theme.font
        font.pixelSize: Theme.small
    }

    // Top row: tracking state on the left, the preview bar on the right.
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 8
        visible: !Cam.values.asleep
        Chip {
            showDot: true
            dotColor: Cam.values.mode !== 0 ? Theme.ledBlue : Cam.trackingPaused ? Theme.warning : "#6b7a8f"
            readonly property string view: qsTr("%1° · %2×").arg([86, 78, 65][Math.max(0, Math.min(2, Cam.values.fov))])
                                                           .arg((1 + ((Cam.ranges.zoomMax || 4) - 1) * Cam.values.zoom / 100).toFixed(1))
            text: (Cam.values.mode !== 0
                  ? qsTr("Tracking: %1").arg(["", qsTr("Group"), qsTr("Person"), qsTr("Hand"), qsTr("Whiteboard"), qsTr("Desk")][Cam.values.mode] || "")
                  : Cam.trackingPaused ? qsTr("Tracking paused") : qsTr("Tracking off")) + "  ·  " + view
        }
        Item { Layout.fillWidth: true }
        Rectangle { // preview bar
            id: bar
            readonly property bool hovered: barHover.hovered
            HoverHandler { id: barHover }
            implicitHeight: 34
            implicitWidth: barRow.implicitWidth + 8
            radius: 17
            color: Theme.overlay
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            RowLayout {
                id: barRow
                anchors.centerIn: parent
                spacing: 2
                AbstractButton {
                    id: qualityBtn
                    implicitHeight: 28
                    implicitWidth: qRow.implicitWidth + 20
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: qsTr("Preview quality: %1").arg(qText.text)
                    onClicked: qualityMenu.popup(qualityBtn, 0, qualityBtn.height + 6)
                    Tip { visible: qualityBtn.hovered && !qualityMenu.visible; text: qsTr("Resolution and frame rate of this preview only; Zoom, OBS and other apps choose their own. 30 fps can look brighter in a dim room.") }
                    background: Rectangle {
                        radius: 14
                        color: qualityBtn.hovered || qualityMenu.visible ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        border.width: qualityBtn.visualFocus ? 2 : 0
                        border.color: Theme.accentText
                    }
                    contentItem: RowLayout {
                        id: qRow
                        spacing: 6
                        Text {
                            id: qText
                            text: root.currentLabel.length === 0 ? qsTr("Auto")
                                : root.autoQuality ? qsTr("Auto · %1").arg(root.currentLabel) : root.currentLabel
                            color: "#e8edf4"
                            font.family: Theme.font
                            font.pixelSize: Theme.small
                            font.weight: Font.Medium
                        }
                        Icon { name: "chevron-down"; size: 12; color: "#d5dce6" }
                    }
                }
                BarIcon {
                    iconName: "grid"
                    active: Cam.values.showGrid
                    tip: Cam.values.showGrid ? qsTr("Hide the framing grid") : qsTr("Show a rule-of-thirds grid")
                    onClicked: Cam.set("showGrid", !Cam.values.showGrid)
                }
                BarIcon {
                    iconName: Cam.values.previewEnabled ? "eye" : "eye-off"
                    active: !Cam.values.previewEnabled
                    tip: Cam.values.previewEnabled ? qsTr("Turn the preview off (frees the camera's video for other apps)") : qsTr("Turn the preview on")
                    onClicked: Cam.set("previewEnabled", !Cam.values.previewEnabled)
                }
            }
        }
    }

    StyledMenu {
        id: qualityMenu
        // Auto first, then every resolution and frame rate the camera offers.
        Instantiator {
            model: [{ key: "", label: root.autoQuality && root.currentLabel.length > 0
                                     ? qsTr("Auto (now %1)").arg(root.currentLabel)
                                     : qsTr("Auto (sharpest for this window)") }].concat(root.formatChoices)
            delegate: MenuEntry {
                required property int index
                required property var modelData
                text: (root.choice === modelData.key ? "✓  " : "     ") + modelData.label
                onTriggered: Cam.set("previewChoice", modelData.key)
            }
            onObjectAdded: (index, object) => qualityMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => qualityMenu.removeItem(object)
        }
        MenuEntry {
            visible: root.formatChoices.length === 0
            text: qsTr("     More choices appear when the camera's video is available")
            enabled: false
        }
    }

    // Asleep: wake it, and choose what the camera shows meanwhile.
    Rectangle {
        z: 4 // covers everything else on the picture
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.03, 0.04, 0.94)
        visible: opacity > 0
        opacity: Cam.values.asleep ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 480)
            spacing: 12
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 60
                implicitHeight: 60
                radius: 30
                color: Qt.rgba(0.753, 0.518, 0.988, 0.14)
                border.color: Qt.rgba(0.753, 0.518, 0.988, 0.35)
                Icon { anchors.centerIn: parent; name: "moon"; size: 28; color: "#c084fc"; stroke: 1.8 }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("The camera is asleep")
                color: "#e8edf4"
                font.family: Theme.displayFont
                font.pixelSize: 22
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("It has turned away and stopped tracking. Wake it to get the picture and tracking back. Shortcut: Ctrl+L.")
                color: "#9aa6b8"
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
            Btn {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                variant: "primary"
                glow: true
                text: qsTr("Wake camera")
                onClicked: Cam.set("asleep", false)
            }
            SleepPicturePicker {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                onVideo: true
                visible: Cam.values.hasSleepPicture // only when the camera is set to show a picture
            }
        }
    }
    // Floating tracking-mode dock. Choosing a mode turns tracking on; the
    // Tracking switch turns it off. While off, the mode it will use is shown
    // faded.
    Segmented {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        visible: !Cam.values.asleep && !pointer.steering && !root.zoneEditing
        onVideo: true
        pill: true
        itemHeight: 38
        readonly property var modes: [2, 1, 3, 5, 4]
        readonly property bool on: Cam.values.mode !== 0
        options: [qsTr("Person"), qsTr("Group"), qsTr("Hand"), qsTr("Desk"), qsTr("Whiteboard")]
        tips: [qsTr("Follow one person"), qsTr("Keep everyone in the picture"), qsTr("Follow your raised hand"),
               qsTr("Look down at your desk"), qsTr("Frame a whiteboard")]
        accessibleName: qsTr("Tracking mode")
        currentIndex: modes.indexOf(on ? Cam.values.mode : Cam.values.lastTrackingMode)
        opacity: on ? 1 : 0.72
        onActivated: (i) => Cam.set("mode", modes[i])
        enabled: Cam.connected
    }

    component BarIcon: AbstractButton {
        id: bi
        property string iconName: ""
        property string tip: ""
        property bool active: false
        implicitWidth: 28
        implicitHeight: 28
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: tip
        Tip { visible: bi.hovered; text: bi.tip }
        background: Rectangle {
            radius: 14
            color: bi.active ? Qt.rgba(1, 1, 1, 0.16) : bi.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            border.width: bi.visualFocus ? 2 : 0
            border.color: Theme.accentText
        }
        contentItem: Item { Icon { anchors.centerIn: parent; name: bi.iconName; size: 15; color: "#e8edf4" } }
    }

    component Chip: Rectangle {
        id: chip
        property alias text: label.text
        property color dotColor: "transparent"
        property bool showDot: false
        implicitHeight: 30
        implicitWidth: chipRow.implicitWidth + 24
        radius: 15
        color: Theme.overlay
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle { visible: chip.showDot; implicitWidth: 8; implicitHeight: 8; radius: 4; color: chip.dotColor }
            Text { id: label; color: "#e8edf4"; font.family: Theme.font; font.pixelSize: Theme.small; font.weight: Font.Medium }
        }
    }
}
