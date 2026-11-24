import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

// Live video with click-to-aim, scroll-to-zoom, the framing grid, status
// chips and the floating tracking dock.
Rectangle {
    id: root
    property bool windowVisible: true
    readonly property bool videoRunning: qcam.active && error.length === 0 && device !== null
    property string error: ""
    property real aimX: -1
    property real aimY: -1

    color: Theme.video
    radius: 20
    clip: true
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)

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
                root.error = ""
                qcam.active = false
                qcam.active = Qt.binding(() => root.device !== null && cam.values.previewEnabled && !cam.values.asleep && root.windowVisible)
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

    MouseArea {
        anchors.fill: parent
        enabled: cam.connected && !cam.values.asleep
        cursorShape: enabled ? Qt.CrossCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: (mouse) => {
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
        onWheel: (wheel) => cam.zoomBy(wheel.angleDelta.y > 0 ? 5 : -5)
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

    // Status chips.
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 8
        Chip {
            showDot: true
            dotColor: cam.values.mode !== 0 ? Theme.accent : "#6f757d"
            text: [qsTr("Tracking off"), qsTr("Tracking group"), qsTr("Tracking person"), qsTr("Following hand"),
                   qsTr("Whiteboard view"), qsTr("Desk view")][cam.values.mode] || ""
        }
        Item { Layout.fillWidth: true }
        Chip {
            text: {
                let parts = []
                if (root.videoRunning && qcam.cameraFormat.resolution.width > 0)
                    parts.push(qcam.cameraFormat.resolution.width + "×" + qcam.cameraFormat.resolution.height)
                parts.push(qsTr("Zoom %1%").arg(cam.values.zoom))
                return parts.join(" · ")
            }
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

    // Floating tracking dock.
    Segmented {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        visible: !cam.values.asleep
        onVideo: true
        pill: true
        itemHeight: 38
        readonly property var modes: [0, 2, 1, 3, 5, 4]
        options: [qsTr("Off"), qsTr("Person"), qsTr("Group"), qsTr("Hand"), qsTr("Desk"), qsTr("Whiteboard")]
        currentIndex: modes.indexOf(cam.values.mode)
        onActivated: (i) => cam.set("mode", modes[i])
        enabled: cam.connected
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
