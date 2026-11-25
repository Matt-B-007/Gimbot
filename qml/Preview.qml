import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Window
import QtQml.Models

// Live video with click-to-aim, drag-to-steer, scroll-to-zoom, the framing
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
    readonly property size videoSize: videoRunning ? qcam.cameraFormat.resolution : Qt.size(0, 0)
    readonly property real videoFps: videoRunning ? qcam.cameraFormat.maxFrameRate : 0

    // Pick the sharpest smooth format for the preview's size on screen (or
    // the user's choice). Debounced so resizing the window doesn't restart
    // the video on every pixel.
    readonly property int targetHeight: Math.round(height * Screen.devicePixelRatio)
    onTargetHeightChanged: formatTimer.restart()
    onDeviceChanged: formatTimer.restart()
    Connections {
        target: cam
        function onValuesChanged() { if (cam.values.previewQuality !== root.appliedQuality) formatTimer.restart() }
    }
    property int appliedQuality: -1
    function chooseFormat() {
        if (root.device === null) return
        appliedQuality = cam.values.previewQuality
        const f = platform.previewFormat(root.device, root.targetHeight, cam.values.previewQuality)
        if (f.resolution.width <= 0) return
        const cur = qcam.cameraFormat
        if (cur.resolution.width === f.resolution.width && cur.resolution.height === f.resolution.height
                && cur.maxFrameRate === f.maxFrameRate && cur.pixelFormat === f.pixelFormat) return
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
        qcam.active = Qt.binding(() => root.device !== null && cam.values.previewEnabled && !cam.values.asleep && root.windowVisible)
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
            active: root.device !== null && cam.values.previewEnabled && !cam.values.asleep && root.windowVisible
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

    // Shown when there is no picture.
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        spacing: 10
        visible: !root.videoRunning && !cam.values.asleep
        Icon {
            Layout.alignment: Qt.AlignHCenter
            name: root.error.length > 0 ? "alert" : !cam.values.previewEnabled ? "eye-off" : "camera"
            color: "#6f757d"
            size: 28
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#c9ccd1"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            text: root.error.length > 0 ? qsTr("Preview unavailable")
                : !cam.values.previewEnabled ? qsTr("Preview is off")
                : cam.simulated ? qsTr("Simulated camera, no video")
                : root.device === null ? qsTr("Looking for the camera's video…")
                : qsTr("Starting preview…")
        }
        Text {
            Layout.fillWidth: true
            visible: root.error.length > 0 || !cam.values.previewEnabled || cam.simulated
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#8a9099"
            font.family: Theme.font
            font.pixelSize: Theme.small + 1
            text: root.error.length > 0
                ? qsTr("Another app such as Zoom or OBS may be using the camera. The controls still work.")
                : !cam.values.previewEnabled ? qsTr("Turn it back on to see the camera here.")
                : qsTr("Every control works; settings are kept in memory.")
        }
        Btn {
            Layout.alignment: Qt.AlignHCenter
            visible: root.error.length > 0 || !cam.values.previewEnabled
            text: root.error.length > 0 ? qsTr("Try again") : qsTr("Turn preview on")
            iconName: root.error.length > 0 ? "refresh" : "eye"
            compact: true
            onClicked: {
                if (!cam.values.previewEnabled) { cam.set("previewEnabled", true); return }
                root.retry()
            }
        }
    }

    // Rule-of-thirds guide.
    Item {
        anchors.fill: parent
        visible: cam.values.showGrid && !cam.values.asleep
        Repeater {
            model: 2
            Rectangle { required property int index; x: root.width * (index + 1) / 3; width: 1; height: root.height; color: Qt.rgba(1, 1, 1, 0.07) }
        }
        Repeater {
            model: 2
            Rectangle { required property int index; y: root.height * (index + 1) / 3; height: 1; width: root.width; color: Qt.rgba(1, 1, 1, 0.07) }
        }
    }

    // Click to aim; press and drag to steer like a joystick (the further
    // you drag, the faster it moves); scroll to zoom.
    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: cam.connected && !cam.values.asleep
        hoverEnabled: true
        cursorShape: !enabled ? Qt.ArrowCursor : steering ? Qt.SizeAllCursor : Qt.CrossCursor
        acceptedButtons: Qt.LeftButton
        property real pressX: 0
        property real pressY: 0
        property bool steering: false
        readonly property real reach: Math.min(width, height) * 0.35 // drag this far for full speed
        onPressed: (mouse) => { pressX = mouse.x; pressY = mouse.y; steering = false; root.clickedOnce = true }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            const dx = mouse.x - pressX, dy = mouse.y - pressY
            if (!steering && Math.hypot(dx, dy) < 8) return
            steering = true
            const ease = (v) => Math.sign(v) * Math.min(1, Math.pow(Math.abs(v), 1.5)) // gentle near the start
            cam.move(ease(-dy / reach), ease(dx / reach))
        }
        onReleased: (mouse) => {
            if (steering) { steering = false; cam.stopMove(); return }
            // Map to the picture itself, not the letterboxed area around it.
            const r = root.videoRunning ? output.contentRect : Qt.rect(0, 0, width, height)
            const x = (mouse.x - r.x) / r.width, y = (mouse.y - r.y) / r.height
            if (x < 0 || x > 1 || y < 0 || y > 1) return
            root.aimX = mouse.x
            root.aimY = mouse.y
            reticle.opacity = 1
            fade.restart()
            cam.aimAt(x, y)
        }
        onCanceled: if (steering) { steering = false; cam.stopMove() }
        onWheel: (wheel) => cam.zoomBy(wheel.angleDelta.y > 0 ? 5 : -5)
    }

    // Drag-to-steer: a line from where you pressed to the pointer.
    Canvas {
        anchors.fill: parent
        visible: pointer.steering
        onVisibleChanged: requestPaint()
        Connections { target: pointer; function onMouseXChanged() { if (pointer.steering) parent.requestPaint() } function onMouseYChanged() { if (pointer.steering) parent.requestPaint() } }
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
        visible: !root.clickedOnce && pointer.containsMouse && !pointer.pressed && cam.connected && !cam.values.asleep && !bar.hovered
        text: qsTr("Click to point the camera here · drag to steer · scroll to zoom")
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

    // Top row: tracking state on the left, the preview bar on the right.
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 8
        visible: !cam.values.asleep
        Chip {
            showDot: true
            dotColor: cam.values.mode !== 0 ? Theme.accent : cam.trackingPaused ? Theme.warning : "#6f757d"
            text: cam.values.mode !== 0
                  ? qsTr("Tracking: %1").arg(["", qsTr("Group"), qsTr("Person"), qsTr("Hand"), qsTr("Whiteboard"), qsTr("Desk")][cam.values.mode] || "")
                  : cam.trackingPaused ? qsTr("Tracking paused") : qsTr("Tracking off")
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
                    Tip { visible: qualityBtn.hovered && !qualityMenu.visible; text: qsTr("Quality of this preview only. Zoom, OBS and other apps choose their own.") }
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
                            text: {
                                const label = [qsTr("Auto"), "720p", "1080p", "4K"][cam.values.previewQuality] || qsTr("Auto")
                                if (root.videoSize.width <= 0) return label
                                return root.videoSize.width + "×" + root.videoSize.height + " · " + Math.round(root.videoFps) + " fps"
                            }
                            color: "#e6e8eb"
                            font.family: Theme.font
                            font.pixelSize: Theme.small
                            font.weight: Font.Medium
                        }
                        Icon { name: "chevron-down"; size: 12; color: "#c9ccd1" }
                    }
                }
                BarIcon {
                    iconName: "grid"
                    active: cam.values.showGrid
                    tip: cam.values.showGrid ? qsTr("Hide the framing grid") : qsTr("Show a rule-of-thirds grid")
                    onClicked: cam.set("showGrid", !cam.values.showGrid)
                }
                BarIcon {
                    iconName: cam.values.previewEnabled ? "eye" : "eye-off"
                    active: !cam.values.previewEnabled
                    tip: cam.values.previewEnabled ? qsTr("Turn the preview off (frees the camera's video for other apps)") : qsTr("Turn the preview on")
                    onClicked: cam.set("previewEnabled", !cam.values.previewEnabled)
                }
            }
        }
    }

    StyledMenu {
        id: qualityMenu
        Instantiator {
            model: [qsTr("Auto (sharpest for this window)"), qsTr("720p"), qsTr("1080p"), qsTr("4K")]
            delegate: MenuEntry {
                required property int index
                required property string modelData
                text: (cam.values.previewQuality === index ? "✓  " : "     ") + modelData
                onTriggered: cam.set("previewQuality", index)
            }
            onObjectAdded: (index, object) => qualityMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => qualityMenu.removeItem(object)
        }
    }

    // Asleep.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.025, 0.92)
        visible: opacity > 0
        opacity: cam.values.asleep ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12
            Icon { Layout.alignment: Qt.AlignHCenter; name: "moon"; size: 30; color: "#9aa0a8"; stroke: 1.8 }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Camera is asleep")
                color: "#f2f3f5"
                font.family: Theme.font
                font.pixelSize: Theme.large
                font.weight: Font.DemiBold
            }
            Btn {
                Layout.alignment: Qt.AlignHCenter
                variant: "primary"
                pill: true
                text: qsTr("Wake up")
                onClicked: cam.set("asleep", false)
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
        visible: !cam.values.asleep && !pointer.steering
        onVideo: true
        pill: true
        itemHeight: 38
        readonly property var modes: [2, 1, 3, 5, 4]
        readonly property bool on: cam.values.mode !== 0
        options: [qsTr("Person"), qsTr("Group"), qsTr("Hand"), qsTr("Desk"), qsTr("Whiteboard")]
        tips: [qsTr("Follow one person"), qsTr("Keep everyone in the picture"), qsTr("Follow your raised hand"),
               qsTr("Look down at your desk"), qsTr("Frame a whiteboard")]
        accessibleName: qsTr("Tracking mode")
        currentIndex: modes.indexOf(on ? cam.values.mode : cam.values.lastTrackingMode)
        opacity: on ? 1 : 0.72
        onActivated: (i) => cam.set("mode", modes[i])
        enabled: cam.connected
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
        contentItem: Item { Icon { anchors.centerIn: parent; name: bi.iconName; size: 15; color: "#e6e8eb" } }
    }

    component Chip: Rectangle {
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
            Rectangle { visible: chipRow.parent.showDot; width: 8; height: 8; radius: 4; color: chipRow.parent.dotColor }
            Text { id: label; color: "#e6e8eb"; font.family: Theme.font; font.pixelSize: Theme.small; font.weight: Font.Medium }
        }
    }
}
