// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls
import Gimbot

ApplicationWindow {
    id: window
    width: 1320
    height: 880
    minimumWidth: 760
    minimumHeight: 560
    visible: !Platform.startHidden
    title: Cam.connected ? "Gimbot · " + Cam.model : "Gimbot"
    color: Theme.bg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize

    property string page: "studio" // studio | settings
    property bool forceConnectScreen: false // screenshots only
    readonly property bool showConnect: forceConnectScreen || (!Cam.connected && page === "studio")

    Component.onCompleted: {
        Theme.mode = Qt.binding(() => Cam.values.theme)
        Theme.useSystemAccent = Qt.binding(() => Cam.values.systemAccent)
        // Once after an update: say so, with What's new and the tour.
        // (New installs get the tour by itself instead.)
        const last = Cam.values.lastRunVersion
        if (last && last !== Platform.version && !screenshotMode) studio.updatedFrom = last
        if (last !== Platform.version) Cam.set("lastRunVersion", Platform.version)
    }

    // Live gimbal angles only while someone can see them.
    Binding { target: Cam; property: "livePosition"; value: window.visible && !window.showConnect }

    function bringForward() {
        window.show()
        window.raise()
        window.requestActivate()
    }
    function openSettings(section) {
        page = "settings"
        if (section) settings.scrollTo(section)
    }
    function toast(message, kind) {
        // Errors offer a one-click report.
        if (kind === "error") toasts.show(message, kind, qsTr("Report"), () => report.open())
        else toasts.show(message, kind)
    }
    function startTour() {
        // The tour points at the Studio's cards, so they have to be showing.
        if (!Cam.connected) { toast(qsTr("Connect the camera first; the tour shows its controls.")); return }
        window.page = "studio"
        studio.zoneEditing = false
        studio.compactTab = 0
        tour.open()
    }

    // Used by --screenshots to visit each screen.
    function showScreen(name) {
        commandPalette.close(); report.close(); about.close(); shortcutsDialog.close(); tour.close(); directionCheck.close(); uninstallDialog.close()
        if (name !== "updating" && name !== "updated") updateDialog.close()
        Cam.set("theme", name.endsWith("-dark") ? 1 : name.endsWith("-light") ? 2 : 0) // same result every run
        if (name.endsWith("-dark")) name = name.replace("-dark", "")
        if (name.endsWith("-light")) name = name.replace("-light", "")
        studio.updateDismissed = name === "readme" // the README's pictures: no pretend update
        studio.readmePicture = name === "readme"
        forceConnectScreen = name === "connect"
        const parts = name.split(":")
        if (parts[0] === "settings") { page = "settings"; settings.scrollTo(parts[1] || "camera") }
        else page = "studio"
        if (name === "palette") commandPalette.open()
        if (name === "report") report.open()
        if (name === "report-github") { report.open(); report.showGithubWarning() }
        if (name === "about") about.open()
        if (name === "update") updateDialog.open()
        if (name === "updating") Updater.install()
        if (name === "update-error") { Updater.simulateCheckError(); window.openSettings("app") }
        if (name === "tour") { tour.open(); tour.step = 1 }
        if (name === "directions") directionCheck.open()
        if (name === "uninstall") uninstallDialog.open()
        if (name === "shortcuts") shortcutsDialog.open()
        // Camera states and the zone editor, set back after each screen.
        studio.zoneEditing = name === "zone"
        if (name === "zone") { // a zone smaller than the whole range, so the box shows
            Cam.set("zoneEnabled", true)
            Cam.set("zoneYawMin", -25); Cam.set("zoneYawMax", 20)
            Cam.set("zonePitchMin", -12); Cam.set("zonePitchMax", 15)
        }
        Cam.set("asleep", name === "asleep")
        Cam.set("previewEnabled", name !== "previewoff")
        studio.previewError = name === "busy" ? "busy" : ""
        window.width = 1320; window.height = 880
        if (name === "small") { window.width = 820; window.height = 1400 }
        if (name === "small-aim") { window.width = 820; window.height = 1400; studio.compactTab = 1 } else studio.compactTab = 0
        if (name === "more") { Cam.set("moreAim", true); Cam.set("moreTracking", true); Cam.set("moreImage", true); window.height = 2100 }
    }

    onClosing: (close) => {
        if (Cam.values.closeToTray && Platform.trayAvailable) {
            close.accepted = false
            window.hide()
        } else {
            Qt.quit()
        }
    }

    Connections {
        target: Updater
        // Only when the user asked; automatic checks fail quietly and retry.
        function onCheckFailed(message, manual) {
            if (manual) toasts.show(qsTr("Couldn't check for updates"), "error", qsTr("Details"), () => window.openSettings("app"))
        }
    }
    Connections {
        target: Platform
        function onShowRequested() { window.bringForward() }
        function onPageRequested(p) { window.openSettings() }
    }
    Connections {
        target: Cam
        function onErrorOccurred(message) { window.toast(message, "error") }
        function onNotice(message) { window.toast(message, "info") }
        function onUndoAvailable(message) { toasts.show(message, "info", qsTr("Undo"), () => Cam.undo()) }
        function onConnectedChanged() {
            // The tour the first time a camera is connected.
            if (Cam.connected && !Cam.values.tourDone && !window.screenshotMode) Qt.callLater(window.startTour)
        }
    }
    Connections {
        target: Platform
        function onNotice(message) { window.toast(message, "info") }
        function onError(message) { window.toast(message, "error") }
    }
    property bool screenshotMode: false
    Timer { // first run: the tour, once a camera is there
        interval: 1200
        running: true
        onTriggered: if (Cam.connected && !Cam.values.tourDone && !window.screenshotMode) window.startTour()
    }

    // ---------------------------------------------------------------- pages
    NavRail {
        id: rail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        page: window.page
        onPageRequested: (page) => { if (page === "settings") window.openSettings(); else window.page = page }
        onOpenTour: window.startTour()
        onOpenShortcuts: shortcutsDialog.open()
        onOpenPalette: commandPalette.open()
        onOpenDirectionCheck: directionCheck.open()
        onOpenWhatsNew: Platform.openUrl(Platform.repoUrl + "/releases/tag/v" + Platform.version)
        onOpenReport: report.open()
        onOpenAbout: about.open()
    }
    Item { // everything right of the strip
        id: pageArea
        anchors.left: rail.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    StudioPage {
        id: studio
        anchors.fill: pageArea
        visible: opacity > 0
        opacity: window.page === "studio" && !window.showConnect ? 1 : 0
        focus: visible
        windowVisible: window.visible
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        onOpenPalette: commandPalette.open()
        onOpenSettings: window.openSettings()
        onOpenReport: report.open()
        onOpenUpdate: updateDialog.open()
        onOpenProfiles: window.openSettings("profiles")
        onSaveProfile: { nameDialog.mode = "profile"; nameDialog.value = ""; nameDialog.open() }
        onOpenTour: window.startTour()
        onOpenAbout: about.open()
        onOpenShortcuts: shortcutsDialog.open()
        onOpenSection: (section) => window.openSettings(section)
        onSavePreset: { nameDialog.mode = "preset"; nameDialog.value = qsTr("Preset %1").arg(Cam.presets.length + 1); nameDialog.open() }
        onRenamePreset: (id, name) => { nameDialog.mode = "rename"; nameDialog.targetId = id; nameDialog.value = name; nameDialog.open() }
        onDeletePreset: (id, name) => {
            confirm.title = qsTr("Delete “%1”?").arg(name)
            confirm.message = qsTr("The camera will forget this preset. You can save it again later.")
            confirm.confirmText = qsTr("Delete")
            confirm.onConfirm = () => Cam.deletePreset(id)
            confirm.open()
        }
    }

    SettingsPage {
        id: settings
        anchors.fill: pageArea
        visible: opacity > 0
        opacity: window.page === "settings" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        transform: Translate { x: window.page === "settings" ? 0 : 24; Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } } }
        onBack: window.page = "studio"
        onOpenReport: report.open()
        onOpenAbout: about.open()
        onOpenUpdate: updateDialog.open()
        onSaveProfileRequested: { nameDialog.mode = "profile"; nameDialog.value = ""; nameDialog.open() }
        onOpenTour: window.startTour()
        onOpenDirectionCheck: directionCheck.open()
        onOpenUninstall: uninstallDialog.open()
        onToast: (message) => window.toast(message, "info")
        onConfirmGoBack: {
            confirm.title = qsTr("Go back to Gimbot %1?").arg(Updater.previousVersion)
            confirm.message = qsTr("This reinstalls the version you had before the last update. You'll be asked for your password, and Gimbot restarts afterwards. Your settings stay.")
            confirm.confirmText = qsTr("Go back")
            confirm.onConfirm = () => { Updater.rollback(); updateDialog.open() }
            confirm.open()
        }
        onConfirmFactoryReset: {
            confirm.title = qsTr("Reset the camera?")
            confirm.message = qsTr("This erases all presets, the tracking area and every camera setting, and can't be undone.")
            confirm.confirmText = qsTr("Reset camera")
            confirm.onConfirm = () => Cam.factoryReset()
            confirm.open()
        }
    }

    ConnectPage {
        anchors.fill: pageArea
        visible: opacity > 0
        opacity: window.showConnect ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal + 100 } }
        onOpenSettings: window.openSettings()
        onOpenReport: report.open()
    }

    // ---------------------------------------------------------------- overlays
    Toasts { id: toasts; anchors.fill: parent; z: 100 }

    CommandPalette {
        id: commandPalette
        actions: {
            let a = [
                { title: Cam.values.mode !== 0 ? qsTr("Turn tracking off") : qsTr("Turn tracking on"), hint: "Ctrl T", icon: "person", keywords: "tracking switch", run: () => Cam.toggleTracking() },
                { title: Cam.trackingPaused ? qsTr("Resume tracking") : "", icon: "play", run: () => Cam.resumeTracking() },
                { title: qsTr("Tracking mode: Person"), icon: "person", keywords: "mode human", run: () => Cam.set("mode", 2) },
                { title: qsTr("Tracking mode: Group"), icon: "person", keywords: "mode", run: () => Cam.set("mode", 1) },
                { title: qsTr("Tracking mode: Hand"), icon: "hand", keywords: "mode", run: () => Cam.set("mode", 3) },
                { title: qsTr("Tracking mode: Desk"), icon: "camera", keywords: "mode", run: () => Cam.set("mode", 5) },
                { title: qsTr("Tracking mode: Whiteboard"), icon: "camera", keywords: "mode", run: () => Cam.set("mode", 4) },
                { title: Cam.values.asleep ? qsTr("Wake the camera") : qsTr("Put the camera to sleep"), hint: "Ctrl L", icon: "moon", keywords: "privacy", run: () => Cam.set("asleep", !Cam.values.asleep) },
                { title: qsTr("Recenter"), hint: "Home", icon: "target", run: () => Cam.recenter() },
                { title: qsTr("Zoom in"), hint: "+", icon: "plus", run: () => Cam.zoomBy(10) },
                { title: qsTr("Zoom out"), hint: "−", icon: "chevron-down", run: () => Cam.zoomBy(-10) },
                { title: qsTr("Save this view as a preset"), icon: "plus", run: () => studio.savePreset() },
                { title: Cam.values.hdr ? qsTr("Turn HDR off") : qsTr("Turn HDR on"), icon: "sun", run: () => Cam.set("hdr", !Cam.values.hdr) },
                { title: Cam.values.mirrored ? qsTr("Stop mirroring") : qsTr("Mirror the image"), icon: "sliders", run: () => Cam.set("mirrored", !Cam.values.mirrored) },
                { title: Cam.values.previewEnabled ? qsTr("Turn the preview off") : qsTr("Turn the preview on"), icon: "eye", run: () => Cam.set("previewEnabled", !Cam.values.previewEnabled) },
                { title: qsTr("Reset image settings"), icon: "refresh", run: () => Cam.resetImage() },
                { title: qsTr("Settings"), hint: "Ctrl ,", icon: "gear", run: () => window.openSettings() },
                { title: studio.canEditZone ? qsTr("Draw the tracking area") : "", icon: "area", keywords: "zone limit edit", run: () => { window.page = "studio"; studio.zoneEditing = true } },
                { title: qsTr("Tracking area settings"), icon: "area", keywords: "zone limit", run: () => window.openSettings("area") },
                { title: qsTr("Voice command settings"), icon: "mic", keywords: "audio", run: () => window.openSettings("voice") },
                { title: qsTr("Profiles"), icon: "layers", run: () => window.openSettings("profiles") },
                { title: qsTr("Check for updates"), icon: "download", run: () => { Updater.check(); window.openSettings("app") } },
                { title: Updater.state === "available" && Updater.canInstall ? qsTr("Install Gimbot %1").arg(Updater.latestVersion) : "", icon: "download", run: () => updateDialog.open() },
                { title: qsTr("Report a problem"), icon: "bug", keywords: "bug issue help", run: () => report.open() },
                { title: qsTr("Keyboard shortcuts"), hint: "?", icon: "help", keywords: "keys hotkeys", run: () => shortcutsDialog.open() },
                { title: qsTr("Show the tour"), icon: "help", keywords: "help tips intro", run: () => window.startTour() },
                { title: qsTr("Check movement directions"), icon: "move", keywords: "invert reversed up down", run: () => directionCheck.open() },
                { title: qsTr("Movement: %1").arg([qsTr("Fast"), qsTr("Normal"), qsTr("Smooth"), qsTr("Cinematic")][(Cam.values.smoothness + 1) % 4]), icon: "move", keywords: "smoothness speed glide", run: () => Cam.set("smoothness", (Cam.values.smoothness + 1) % 4) },
                { title: qsTr("Uninstall Gimbot"), icon: "power", keywords: "remove delete", run: () => uninstallDialog.open() },
                { title: qsTr("About Gimbot"), icon: "info", run: () => about.open() },
                { title: qsTr("Quit Gimbot"), hint: "Ctrl Q", icon: "power", run: () => Qt.quit() }
            ]
            for (let i = 0; i < Cam.presets.length; ++i) {
                const p = Cam.presets[i]
                a.splice(8 + i, 0, { title: qsTr("Go to preset: %1").arg(p.name), hint: "Ctrl " + (i + 1), icon: "chevron-right", run: () => Cam.goToPreset(p.id) })
            }
            for (let j = 0; j < Cam.profiles.length; ++j) {
                const name = Cam.profiles[j]
                a.push({ title: qsTr("Apply profile: %1").arg(name), icon: "layers", run: () => Cam.applyProfile(name) })
            }
            return a.filter(x => x.title.length > 0)
        }
    }

    ReportDialog { id: report; onDone: (m) => window.toast(m) }
    UpdateDialog { id: updateDialog; onReportRequested: report.open() }
    AboutDialog { id: about }
    ConfirmDialog { id: confirm }
    DirectionCheck { id: directionCheck }
    ShortcutsDialog { id: shortcutsDialog }
    UninstallDialog { id: uninstallDialog }
    Tour {
        id: tour
        targets: studio.tourTargets
        onFinished: Cam.set("tourDone", true)
    }

    NameDialog {
        id: nameDialog
        property string mode: "preset"
        property int targetId: -1
        title: mode === "profile" ? qsTr("Save profile") : mode === "rename" ? qsTr("Rename preset") : qsTr("Save this view")
        iconName: mode === "profile" ? "layers" : "camera"
        placeholder: mode === "profile" ? qsTr("e.g. Meetings") : qsTr("e.g. Desk")
        acceptText: mode === "rename" ? qsTr("Rename") : qsTr("Save")
        onAccepted: (name) => {
            if (mode === "profile") Cam.saveProfile(name)
            else if (mode === "rename") Cam.renamePreset(targetId, name)
            else {
                const id = Cam.savePreset(name)
                if (id >= 0) studio.preview.grabThumbnail(Cam.thumbnailPath(id), (ok) => { if (ok) Cam.thumbnailSaved(id) })
            }
        }
    }

    // ---------------------------------------------------------------- shortcuts
    Shortcut { sequence: "Ctrl+K"; onActivated: commandPalette.open() }
    Shortcut { sequence: "Ctrl+,"; onActivated: window.openSettings() }
    Shortcut { sequence: "Ctrl+T"; enabled: Cam.connected; onActivated: Cam.toggleTracking() }
    Shortcut { sequence: "Ctrl+L"; enabled: Cam.connected; onActivated: Cam.set("asleep", !Cam.values.asleep) }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+1"; onActivated: Cam.goToPresetIndex(0) }
    Shortcut { sequence: "Ctrl+2"; onActivated: Cam.goToPresetIndex(1) }
    Shortcut { sequence: "Ctrl+3"; onActivated: Cam.goToPresetIndex(2) }
    Shortcut { sequence: "Ctrl+4"; onActivated: Cam.goToPresetIndex(3) }
    Shortcut { sequence: "Ctrl+5"; onActivated: Cam.goToPresetIndex(4) }
    Shortcut { sequence: "Ctrl+6"; onActivated: Cam.goToPresetIndex(5) }
    Shortcut { sequence: "Ctrl+7"; onActivated: Cam.goToPresetIndex(6) }
    Shortcut { sequence: "Ctrl+8"; onActivated: Cam.goToPresetIndex(7) }
    Shortcut { sequence: "Ctrl+9"; onActivated: Cam.goToPresetIndex(8) }
    Shortcut { sequence: "Esc"; enabled: window.page === "settings"; onActivated: window.page = "studio" }
    Shortcut { sequence: "Esc"; enabled: window.page === "studio" && studio.zoneEditing; onActivated: studio.zoneEditing = false }
}
