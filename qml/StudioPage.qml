// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The main screen: preview, presets and the control cards.
FocusScope {
    id: root
    property bool windowVisible: true
    property bool updateDismissed: false
    property bool sdkDismissed: false
    property string updatedFrom: "" // set once after an update
    signal openPalette()
    signal openSettings()
    signal openReport()
    signal openUpdate()
    signal savePreset()
    signal renamePreset(int id, string name)
    signal deletePreset(int id, string name)
    signal openProfiles()
    signal saveProfile()
    signal openTour()
    signal openAbout()
    signal openSection(string section)
    signal openShortcuts()

    readonly property alias preview: preview
    readonly property bool wide: width >= 1080

    readonly property alias tourTargets: tourTargets
    QtObject {
        id: tourTargets
        property Item tracking: trackingCard
        property Item preview: preview
        property Item presets: presetStrip
        property Item bar: topBar
    }

    // Hold an arrow key to move the gimbal; let go to stop. The speed eases
    // in and out according to the Movement setting, so it doesn't jerk.
    property int heldTilt: 0
    property int heldPan: 0
    property real curTilt: 0
    property real curPan: 0
    function updateMove() { if (!easeTimer.running) { easeTimer.start(); easeTimer.triggered() } }
    onActiveFocusChanged: if (!activeFocus && (heldTilt !== 0 || heldPan !== 0)) { heldTilt = 0; heldPan = 0; updateMove() }
    Timer {
        id: easeTimer
        interval: 40
        repeat: true
        function approach(cur, target, up, down) {
            const r = target === 0 || Math.sign(target) !== Math.sign(cur) && cur !== 0 ? down : up
            return cur + Math.max(-r, Math.min(r, target - cur))
        }
        onTriggered: {
            const level = Math.max(0, Math.min(3, cam.values.smoothness))
            const up = [1, 0.25, 0.12, 0.07][level]   // share of full speed added per tick
            const down = [1, 0.34, 0.18, 0.1][level]
            root.curTilt = approach(root.curTilt, root.heldTilt, up, down)
            root.curPan = approach(root.curPan, root.heldPan, up, down)
            if (root.curTilt === 0 && root.curPan === 0) {
                stop()
                cam.stopMove()
            } else {
                cam.move(root.curTilt, root.curPan)
            }
        }
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
        case Qt.Key_Question: root.openShortcuts(); e.accepted = true; return
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
            id: topBar
            Layout.fillWidth: true
            onOpenPalette: root.openPalette()
            onOpenSettings: root.openSettings()
            onOpenProfiles: root.openSection("profiles")
            onSaveProfile: root.saveProfile()
            onOpenTour: root.openTour()
            onOpenReport: root.openReport()
            onOpenAbout: root.openAbout()
            onOpenShortcuts: root.openShortcuts()
        }

        StatusStrip {
            Layout.fillWidth: true
            previewError: preview.error
            videoSize: preview.videoSize
            videoFps: preview.videoFps
            onRetryPreview: preview.retry()
            onOpenArea: root.openSection("area")
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
        Banner { // once after an update
            Layout.fillWidth: true
            visible: root.updatedFrom.length > 0
            iconName: "check"
            tint: Theme.success
            text: qsTr("Gimbot was updated to %1.").arg(platform.version)
            actionText: platform.repoUrl ? qsTr("What's new") : ""
            onAction: platform.openUrl(platform.repoUrl + "/releases/tag/v" + platform.version)
            secondaryText: qsTr("Show the tour")
            onSecondary: { root.updatedFrom = ""; root.openTour() }
            onDismissed: root.updatedFrom = ""
        }
        Banner {
            Layout.fillWidth: true
            visible: (updater.state === "available" && !root.updateDismissed) || updater.installState !== "idle"
            readonly property string install: updater.installState
            tint: install === "done" ? Theme.success : install === "failed" ? Theme.danger : Theme.accent
            iconName: "download"
            text: {
                if (install === "running") return qsTr("Updating to Gimbot %1… %2%").arg(updater.latestVersion).arg(updater.installProgress)
                if (install === "done") return qsTr("Gimbot %1 is installed. Restart to start using it.").arg(updater.latestVersion)
                if (install === "failed") return qsTr("The update didn't finish: %1").arg(updater.installError)
                const name = updater.latestIsBeta ? qsTr("Gimbot %1 (beta)").arg(updater.latestVersion) : qsTr("Gimbot %1").arg(updater.latestVersion)
                if (updater.isSwitch) return qsTr("%1, the newest normal version, is available.").arg(name)
                return updater.canInstall ? qsTr("%1 is available.").arg(name)
                                          : qsTr("%1 is available. Update it with your package manager.").arg(name)
            }
            secondaryText: install === "idle" && updater.canInstall ? qsTr("What's new") : ""
            onSecondary: root.openUpdate()
            actionText: install === "running" ? qsTr("Show")
                      : install === "done" ? qsTr("Restart Gimbot")
                      : install === "failed" ? qsTr("Details")
                      : updater.canInstall ? (updater.isSwitch ? qsTr("Switch now") : qsTr("Update now")) : qsTr("What's new")
            onAction: {
                if (install === "done") updater.restartApp()
                else if (updater.canInstall) root.openUpdate()
                else platform.openUrl(updater.latestUrl)
            }
            onDismissed: root.updateDismissed = true
        }
        Banner { // a newer OBSBOT SDK was found in Downloads
            Layout.fillWidth: true
            visible: platform.newSdkPath.length > 0 && !root.sdkDismissed && updater.installState === "idle"
            iconName: "download"
            tint: Theme.accent
            text: qsTr("A newer OBSBOT SDK (%1) is in your Downloads. Move it into Gimbot's folder and rebuild Gimbot with it?").arg(platform.newSdkVersion)
            actionText: updater.canInstall ? qsTr("Move and rebuild") : qsTr("Move it")
            onAction: {
                if (platform.adoptSdk(platform.newSdkPath) && updater.canInstall) updater.rebuild()
            }
            onDismissed: root.sdkDismissed = true
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
                        id: presetStrip
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
                    TrackingCard {
                        id: trackingCard
                        Layout.fillWidth: true
                        onOpenArea: root.openSection("area")
                        onOpenVoice: root.openSection("voice")
                    }
                    AimCard { Layout.fillWidth: true }
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
                            text: qsTr("Firmware updates: OBSBOT Center")
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.small
                            HoverHandler { id: fwHover }
                            Tip { visible: fwHover.hovered; text: qsTr("The OBSBOT SDK can't update the camera's firmware. Use OBSBOT Center on Windows or macOS.") }
                        }
                    }
                }
            }
        }
    }
}
