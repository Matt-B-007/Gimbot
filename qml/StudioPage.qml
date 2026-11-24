import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The main screen: preview, presets and the control cards.
FocusScope {
    id: root
    property bool windowVisible: true
    property bool updateDismissed: false
    signal openPalette()
    signal openSettings()
    signal openReport()
    signal savePreset()
    signal renamePreset(int id, string name)
    signal deletePreset(int id, string name)

    readonly property alias preview: preview
    readonly property bool wide: width >= 1080

    // Hold an arrow key to move the gimbal; let go to stop.
    property int heldTilt: 0
    property int heldPan: 0
    function updateMove() {
        if (heldTilt === 0 && heldPan === 0) cam.stopMove()
        else cam.move(heldTilt, heldPan)
    }
    Keys.onPressed: (e) => {
        if (e.isAutoRepeat) { e.accepted = [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].includes(e.key); return }
        switch (e.key) {
        case Qt.Key_Up: heldTilt = 1; break
        case Qt.Key_Down: heldTilt = -1; break
        case Qt.Key_Left: heldPan = -1; break
        case Qt.Key_Right: heldPan = 1; break
        case Qt.Key_Home: cam.recenter(); e.accepted = true; return
        case Qt.Key_Plus: case Qt.Key_Equal: cam.zoomBy(10); e.accepted = true; return
        case Qt.Key_Minus: cam.zoomBy(-10); e.accepted = true; return
        default: return
        }
        e.accepted = true
        updateMove()
    }
    Keys.onReleased: (e) => {
        if (e.isAutoRepeat) return
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) heldTilt = 0
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) heldPan = 0
        else return
        e.accepted = true
        updateMove()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 14
        spacing: 14

        TopBar {
            Layout.fillWidth: true
            onOpenPalette: root.openPalette()
            onOpenSettings: root.openSettings()
        }

        Banner {
            Layout.fillWidth: true
            visible: platform.previousSessionCrashed
            iconName: "alert"
            tint: Theme.warning
            text: qsTr("Gimbot closed unexpectedly last time. A report helps get it fixed.")
            actionText: qsTr("Report the problem")
            onAction: { root.openReport(); platform.dismissCrash() }
            onDismissed: platform.dismissCrash()
        }
        Banner {
            Layout.fillWidth: true
            visible: updater.state === "available" && !root.updateDismissed
            iconName: "download"
            text: updater.latestIsBeta ? qsTr("Gimbot %1 (beta) is available. Update it with your package manager.").arg(updater.latestVersion)
                                       : qsTr("Gimbot %1 is available. Update it with your package manager.").arg(updater.latestVersion)
            actionText: qsTr("What's new")
            onAction: platform.openUrl(updater.latestUrl)
            onDismissed: root.updateDismissed = true
        }

        ScrollView {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            GridLayout {
                width: scroller.availableWidth
                columns: root.wide ? 2 : 1
                columnSpacing: 16
                rowSpacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 16
                    Preview {
                        id: preview
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 9 / 16
                        windowVisible: root.windowVisible && root.visible
                    }
                    PresetStrip {
                        Layout.fillWidth: true
                        onSaveRequested: root.savePreset()
                        onRenameRequested: (id, name) => root.renamePreset(id, name)
                        onDeleteRequested: (id, name) => root.deletePreset(id, name)
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: !root.wide
                    Layout.preferredWidth: root.wide ? 340 : -1
                    Layout.maximumWidth: root.wide ? 360 : 100000
                    spacing: 12
                    AimCard { Layout.fillWidth: true }
                    TrackingCard { Layout.fillWidth: true }
                    ImageCard { Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        Text {
                            text: cam.connected ? qsTr("Firmware %1").arg(cam.firmware) : ""
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.small
                            Layout.fillWidth: true
                        }
                        Text {
                            text: qsTr("Firmware updates via OBSBOT Center")
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.small
                        }
                    }
                }
            }
        }
    }
}
