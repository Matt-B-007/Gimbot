// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Gimbot

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

    readonly property alias preview: previewView
    readonly property bool wide: width >= 1080
    property int compactTab: 0 // which card shows in a narrow window
    property bool zoneEditing: false // drawing the tracking zone on the picture
    // Nothing to draw on without a picture: asleep or unplugged ends it.
    readonly property bool canEditZone: Cam.connected && !Cam.values.asleep
    onCanEditZoneChanged: if (!canEditZone) zoneEditing = false
    onZoneEditingChanged: if (zoneEditing && !canEditZone) zoneEditing = false
    property bool readmePicture: false // screenshots for the README: no pending update shown
    property alias previewError: previewView.error // screenshots of the "busy" state

    readonly property alias tourTargets: tourTargets
    QtObject {
        id: tourTargets
        property Item tracking: trackingCard
        property Item preview: previewView
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
            const level = Math.max(0, Math.min(3, Cam.values.smoothness))
            const up = [1, 0.25, 0.12, 0.07][level]   // share of full speed added per tick
            const down = [1, 0.34, 0.18, 0.1][level]
            root.curTilt = approach(root.curTilt, root.heldTilt, up, down)
            root.curPan = approach(root.curPan, root.heldPan, up, down)
            if (root.curTilt === 0 && root.curPan === 0) {
                stop()
                Cam.stopMove()
            } else {
                Cam.move(root.curTilt, root.curPan)
            }
        }
    }
    // The scrolling areas would otherwise take the arrow keys for themselves
    // once a button inside them has been clicked, so each of them hands its
    // keys here first (see "Keys.priority" below).
    Keys.onPressed: (e) => root.keyDown(e)
    Keys.onReleased: (e) => root.keyUp(e)
    function keyDown(e) {
        if (e.isAutoRepeat) { e.accepted = [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].includes(e.key); return }
        switch (e.key) {
        case Qt.Key_Up: heldTilt = 1; break
        case Qt.Key_Down: heldTilt = -1; break
        case Qt.Key_Left: heldPan = -1; break
        case Qt.Key_Right: heldPan = 1; break
        case Qt.Key_Home: Cam.recenter(); e.accepted = true; return
        case Qt.Key_Plus: case Qt.Key_Equal: Cam.zoomBy(10); e.accepted = true; return
        case Qt.Key_Minus: Cam.zoomBy(-10); e.accepted = true; return
        case Qt.Key_Question: root.openShortcuts(); e.accepted = true; return
        default: return
        }
        e.accepted = true
        updateMove()
    }
    function keyUp(e) {
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
            hideUpdate: root.readmePicture
            onOpenPalette: root.openPalette()
            onOpenSettings: root.openSettings()
            onOpenProfiles: root.openSection("profiles")
            onSaveProfile: root.saveProfile()
            onOpenTour: root.openTour()
            onOpenReport: root.openReport()
            onOpenAbout: root.openAbout()
            onOpenShortcuts: root.openShortcuts()
            onOpenUpdate: root.openUpdate()
        }


        Banner {
            Layout.fillWidth: true
            visible: Platform.previousSessionCrashed
            iconName: "alert"
            tint: Theme.warning
            text: qsTr("Gimbot closed unexpectedly last time. A report helps get it fixed.")
            actionText: qsTr("Report the problem")
            onAction: { root.openReport(); Platform.dismissCrash() }
            onDismissed: Platform.dismissCrash()
        }
        Banner { // once after an update
            Layout.fillWidth: true
            visible: root.updatedFrom.length > 0
            iconName: "check"
            tint: Theme.success
            text: qsTr("Gimbot was updated to %1.").arg(Platform.version)
            actionText: Platform.repoUrl ? qsTr("What's new") : ""
            onAction: Platform.openUrl(Platform.repoUrl + "/releases/tag/v" + Platform.version)
            secondaryText: qsTr("Show the tour")
            onSecondary: { root.updatedFrom = ""; root.openTour() }
            onDismissed: root.updatedFrom = ""
        }
        Banner {
            Layout.fillWidth: true
            visible: Updater.installState !== "idle" // "available" is the top bar's Update ready button
            readonly property string install: Updater.installState
            tint: install === "done" ? Theme.success : install === "failed" ? Theme.danger : Theme.accent
            iconName: "download"
            text: {
                if (install === "running") return qsTr("Updating to Gimbot %1… %2%").arg(Updater.latestVersion).arg(Updater.installProgress)
                if (install === "done") return qsTr("Gimbot %1 is installed. Restart to start using it.").arg(Updater.latestVersion)
                if (install === "failed") return qsTr("The update didn't finish: %1").arg(Updater.installError)
                const name = Updater.latestIsBeta ? qsTr("Gimbot %1 (beta)").arg(Updater.latestVersion) : qsTr("Gimbot %1").arg(Updater.latestVersion)
                if (Updater.isSwitch) return qsTr("%1, the newest normal version, is available.").arg(name)
                return Updater.canInstall ? qsTr("%1 is available.").arg(name)
                                          : qsTr("%1 is available. Update it with your package manager.").arg(name)
            }
            secondaryText: install === "idle" && Updater.canInstall ? qsTr("What's new") : ""
            onSecondary: root.openUpdate()
            actionText: install === "running" ? qsTr("Show")
                      : install === "done" ? qsTr("Restart Gimbot")
                      : install === "failed" ? qsTr("Details")
                      : Updater.canInstall ? (Updater.isSwitch ? qsTr("Switch now") : qsTr("Update now")) : qsTr("What's new")
            onAction: {
                if (install === "done") Updater.restartApp()
                else if (Updater.canInstall) root.openUpdate()
                else Platform.openUrl(Updater.latestUrl)
            }
            onDismissed: root.updateDismissed = true
        }
        Banner { // a newer OBSBOT SDK was found in Downloads
            Layout.fillWidth: true
            visible: Platform.newSdkPath.length > 0 && !root.sdkDismissed && Updater.installState === "idle"
            iconName: "download"
            tint: Theme.accent
            text: qsTr("A newer OBSBOT SDK (%1) is in your Downloads. Move it into Gimbot's folder and rebuild Gimbot with it?").arg(Platform.newSdkVersion)
            actionText: Updater.canInstall ? qsTr("Move and rebuild") : qsTr("Move it")
            onAction: {
                if (Platform.adoptSdk(Platform.newSdkPath) && Updater.canInstall) Updater.rebuild()
            }
            onDismissed: root.sdkDismissed = true
        }

        // Wide window: the picture's column and the cards' column scroll
        // on their own, so the picture stays put while you change a card.
        // Narrow window: one column, and the whole page scrolls.
        ScrollView {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: (e) => root.keyDown(e)
            Keys.onReleased: (e) => root.keyUp(e)

            GridLayout {
                width: scroller.availableWidth
                columns: root.wide ? 2 : 1
                columnSpacing: 16
                rowSpacing: 16

                ScrollView {
                    id: leftScroll
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: root.wide ? scroller.availableHeight : leftColumn.implicitHeight
                    contentWidth: availableWidth
                    clip: root.wide
                    rightPadding: root.wide && leftColumn.implicitHeight > height ? 12 : 0 // room for the scroll bar
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: (e) => root.keyDown(e)
                    Keys.onReleased: (e) => root.keyUp(e)
                    ColumnLayout {
                        id: leftColumn
                        width: leftScroll.availableWidth
                        spacing: 16
                        Preview {
                            id: previewView
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            windowVisible: root.windowVisible && root.visible
                            zoneEditing: root.zoneEditing
                        }
                        ZoneRangeBar {
                            Layout.fillWidth: true
                            visible: root.zoneEditing
                        }
                        PresetStrip {
                            id: presetStrip
                            Layout.fillWidth: true
                            onSaveRequested: root.savePreset()
                            onRenameRequested: (id, name) => root.renamePreset(id, name)
                            onDeleteRequested: (id, name) => root.deletePreset(id, name)
                        }
                        StatusStrip {
                            Layout.fillWidth: true
                            previewError: previewView.error
                            videoSize: previewView.videoSize
                            videoFps: previewView.videoFps
                            onRetryPreview: previewView.retry()
                            onOpenArea: root.zoneEditing = true
                        }
                    }
                }

                ScrollView {
                    id: rightScroll
                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: !root.wide
                    Layout.preferredWidth: root.wide ? 340 + rightPadding : -1
                    Layout.preferredHeight: root.wide ? scroller.availableHeight : rightColumn.implicitHeight
                    contentWidth: availableWidth
                    clip: root.wide
                    rightPadding: root.wide && rightColumn.implicitHeight > height ? 12 : 0
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: (e) => root.keyDown(e)
                    Keys.onReleased: (e) => root.keyUp(e)
                    ColumnLayout {
                        id: rightColumn
                        width: rightScroll.availableWidth
                        spacing: 12
                        // In a narrow window the cards share the space as tabs.
                        Segmented {
                            id: cardTabs
                            Layout.fillWidth: true
                            visible: !root.wide && !root.zoneEditing
                            options: [qsTr("Tracking"), qsTr("Aim"), qsTr("Image")]
                            accessibleName: qsTr("Controls")
                            currentIndex: root.compactTab
                            onActivated: (i) => root.compactTab = i
                        }
                        ZonePanel {
                            Layout.fillWidth: true
                            visible: root.zoneEditing
                            onDone: root.zoneEditing = false
                            onMoreSettings: { root.zoneEditing = false; root.openSection("area") }
                        }
                        TrackingCard {
                            id: trackingCard
                            visible: !root.zoneEditing && (root.wide || root.compactTab === 0)
                            Layout.fillWidth: true
                            onOpenArea: root.zoneEditing = true
                            onOpenVoice: root.openSection("voice")
                        }
                        AimCard { Layout.fillWidth: true; visible: !root.zoneEditing && (root.wide || root.compactTab === 1) }
                        ImageCard { Layout.fillWidth: true; visible: !root.zoneEditing && (root.wide || root.compactTab === 2) }
                        StatusLightCard { Layout.fillWidth: true; visible: !root.zoneEditing && (root.wide || root.compactTab === 2) }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 6
                            Layout.rightMargin: 6
                            Text {
                                text: Cam.connected ? qsTr("Firmware %1").arg(Cam.firmware) : ""
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
}
