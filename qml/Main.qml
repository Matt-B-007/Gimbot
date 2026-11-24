import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 1320
    height: 880
    minimumWidth: 760
    minimumHeight: 560
    visible: !startHidden
    title: cam.connected ? "Gimbot · " + cam.model : "Gimbot"
    color: Theme.bg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize

    property string page: "studio" // studio | settings
    property bool forceConnectScreen: false // screenshots only
    readonly property bool showConnect: forceConnectScreen || (!cam.connected && page === "studio")

    Component.onCompleted: {
        Theme.mode = Qt.binding(() => cam.values.theme)
        Theme.useSystemAccent = Qt.binding(() => cam.values.systemAccent)
    }

    // Live gimbal angles only while someone can see them.
    Binding { target: cam; property: "livePosition"; value: window.visible && !window.showConnect }

    function bringForward() {
        window.show()
        window.raise()
        window.requestActivate()
    }
    function openSettings(section) {
        page = "settings"
        if (section) settings.scrollTo(section)
    }
    function toast(message, kind) { toasts.show(message, kind) }

    // Used by --screenshots to visit each screen.
    function showScreen(name) {
        palette.close(); report.close(); about.close()
        if (name !== "updating" && name !== "updated") updateDialog.close()
        if (name.endsWith("-dark")) { cam.set("theme", 1); name = name.replace("-dark", "") }
        forceConnectScreen = name === "connect"
        const parts = name.split(":")
        if (parts[0] === "settings") { page = "settings"; settings.scrollTo(parts[1] || "area") }
        else page = "studio"
        if (name === "palette") palette.open()
        if (name === "report") report.open()
        if (name === "about") about.open()
        if (name === "update") updateDialog.open()
        if (name === "updating") updater.install()
    }

    onClosing: (close) => {
        if (cam.values.closeToTray && platform.trayAvailable) {
            close.accepted = false
            window.hide()
        } else {
            Qt.quit()
        }
    }

    Connections {
        target: platform
        function onShowRequested() { window.bringForward() }
        function onPageRequested(p) { window.openSettings() }
    }
    Connections {
        target: cam
        function onErrorOccurred(message) { window.toast(message, "error") }
        function onNotice(message) { window.toast(message, "info") }
    }

    // ---------------------------------------------------------------- pages
    StudioPage {
        id: studio
        anchors.fill: parent
        visible: opacity > 0
        opacity: window.page === "studio" && !window.showConnect ? 1 : 0
        focus: visible
        windowVisible: window.visible
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        onOpenPalette: palette.open()
        onOpenSettings: window.openSettings()
        onOpenReport: report.open()
        onOpenUpdate: updateDialog.open()
        onSavePreset: { nameDialog.mode = "preset"; nameDialog.value = qsTr("Preset %1").arg(cam.presets.length + 1); nameDialog.open() }
        onRenamePreset: (id, name) => { nameDialog.mode = "rename"; nameDialog.targetId = id; nameDialog.value = name; nameDialog.open() }
        onDeletePreset: (id, name) => {
            confirm.title = qsTr("Delete “%1”?").arg(name)
            confirm.message = qsTr("The camera will forget this preset. You can save it again later.")
            confirm.confirmText = qsTr("Delete")
            confirm.onConfirm = () => cam.deletePreset(id)
            confirm.open()
        }
    }

    SettingsPage {
        id: settings
        anchors.fill: parent
        visible: opacity > 0
        opacity: window.page === "settings" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        transform: Translate { x: window.page === "settings" ? 0 : 24; Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } } }
        onBack: window.page = "studio"
        onOpenReport: report.open()
        onOpenAbout: about.open()
        onOpenUpdate: updateDialog.open()
        onSaveProfileRequested: { nameDialog.mode = "profile"; nameDialog.value = ""; nameDialog.open() }
        onConfirmFactoryReset: {
            confirm.title = qsTr("Reset the camera?")
            confirm.message = qsTr("This erases all presets, the tracking area and every camera setting, and can't be undone.")
            confirm.confirmText = qsTr("Reset camera")
            confirm.onConfirm = () => cam.factoryReset()
            confirm.open()
        }
    }

    ConnectPage {
        anchors.fill: parent
        visible: opacity > 0
        opacity: window.showConnect ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal + 100 } }
        onOpenSettings: window.openSettings()
        onOpenReport: report.open()
    }

    // ---------------------------------------------------------------- overlays
    Toasts { id: toasts; anchors.fill: parent; z: 100 }

    CommandPalette {
        id: palette
        actions: {
            let a = [
                { title: qsTr("Turn tracking on or off"), hint: "Ctrl T", icon: "person", run: () => cam.toggleTracking() },
                { title: qsTr("Track a person"), icon: "person", keywords: "mode human", run: () => cam.set("mode", 2) },
                { title: qsTr("Track a group"), icon: "person", keywords: "mode", run: () => cam.set("mode", 1) },
                { title: qsTr("Follow my hand"), icon: "hand", keywords: "mode", run: () => cam.set("mode", 3) },
                { title: qsTr("Desk view"), icon: "camera", keywords: "mode", run: () => cam.set("mode", 5) },
                { title: qsTr("Whiteboard view"), icon: "camera", keywords: "mode", run: () => cam.set("mode", 4) },
                { title: cam.values.asleep ? qsTr("Wake the camera") : qsTr("Put the camera to sleep"), hint: "Ctrl L", icon: "moon", keywords: "privacy", run: () => cam.set("asleep", !cam.values.asleep) },
                { title: qsTr("Recenter"), hint: "Home", icon: "target", run: () => cam.recenter() },
                { title: qsTr("Zoom in"), hint: "+", icon: "plus", run: () => cam.zoomBy(10) },
                { title: qsTr("Zoom out"), hint: "−", icon: "chevron-down", run: () => cam.zoomBy(-10) },
                { title: qsTr("Save this view as a preset"), icon: "plus", run: () => studio.savePreset() },
                { title: cam.values.hdr ? qsTr("Turn HDR off") : qsTr("Turn HDR on"), icon: "sun", run: () => cam.set("hdr", !cam.values.hdr) },
                { title: cam.values.mirrored ? qsTr("Stop mirroring") : qsTr("Mirror the image"), icon: "sliders", run: () => cam.set("mirrored", !cam.values.mirrored) },
                { title: cam.values.previewEnabled ? qsTr("Turn the preview off") : qsTr("Turn the preview on"), icon: "eye", run: () => cam.set("previewEnabled", !cam.values.previewEnabled) },
                { title: qsTr("Reset image settings"), icon: "refresh", run: () => cam.resetImage() },
                { title: qsTr("Settings"), hint: "Ctrl ,", icon: "gear", run: () => window.openSettings() },
                { title: qsTr("Tracking area settings"), icon: "area", keywords: "zone limit", run: () => window.openSettings("area") },
                { title: qsTr("Voice command settings"), icon: "mic", keywords: "audio", run: () => window.openSettings("voice") },
                { title: qsTr("Profiles"), icon: "layers", run: () => window.openSettings("profiles") },
                { title: qsTr("Check for updates"), icon: "download", run: () => { updater.check(); window.openSettings("app") } },
                { title: updater.state === "available" && updater.canInstall ? qsTr("Install Gimbot %1").arg(updater.latestVersion) : "", icon: "download", run: () => updateDialog.open() },
                { title: qsTr("Report a problem"), icon: "bug", keywords: "bug issue help", run: () => report.open() },
                { title: qsTr("About Gimbot"), icon: "info", run: () => about.open() },
                { title: qsTr("Quit Gimbot"), hint: "Ctrl Q", icon: "power", run: () => Qt.quit() }
            ]
            for (let i = 0; i < cam.presets.length; ++i) {
                const p = cam.presets[i]
                a.splice(8 + i, 0, { title: qsTr("Go to preset: %1").arg(p.name), hint: "Ctrl " + (i + 1), icon: "chevron-right", run: () => cam.goToPreset(p.id) })
            }
            for (let j = 0; j < cam.profiles.length; ++j) {
                const name = cam.profiles[j]
                a.push({ title: qsTr("Apply profile: %1").arg(name), icon: "layers", run: () => cam.applyProfile(name) })
            }
            return a.filter(x => x.title.length > 0)
        }
    }

    ReportDialog { id: report; onDone: (m) => window.toast(m) }
    UpdateDialog { id: updateDialog; onReportRequested: report.open() }
    AboutDialog { id: about }
    ConfirmDialog { id: confirm }

    NameDialog {
        id: nameDialog
        property string mode: "preset"
        property int targetId: -1
        title: mode === "profile" ? qsTr("Save profile") : mode === "rename" ? qsTr("Rename preset") : qsTr("Save this view")
        iconName: mode === "profile" ? "layers" : "camera"
        placeholder: mode === "profile" ? qsTr("e.g. Meetings") : qsTr("e.g. Desk")
        acceptText: mode === "rename" ? qsTr("Rename") : qsTr("Save")
        onAccepted: (name) => {
            if (mode === "profile") cam.saveProfile(name)
            else if (mode === "rename") cam.renamePreset(targetId, name)
            else {
                const id = cam.savePreset(name)
                if (id >= 0) studio.preview.grabThumbnail(cam.thumbnailPath(id), (ok) => { if (ok) cam.thumbnailSaved(id) })
            }
        }
    }

    // ---------------------------------------------------------------- shortcuts
    Shortcut { sequence: "Ctrl+K"; onActivated: palette.open() }
    Shortcut { sequence: "Ctrl+,"; onActivated: window.openSettings() }
    Shortcut { sequence: "Ctrl+T"; enabled: cam.connected; onActivated: cam.toggleTracking() }
    Shortcut { sequence: "Ctrl+L"; enabled: cam.connected; onActivated: cam.set("asleep", !cam.values.asleep) }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+1"; onActivated: cam.goToPresetIndex(0) }
    Shortcut { sequence: "Ctrl+2"; onActivated: cam.goToPresetIndex(1) }
    Shortcut { sequence: "Ctrl+3"; onActivated: cam.goToPresetIndex(2) }
    Shortcut { sequence: "Esc"; enabled: window.page === "settings"; onActivated: window.page = "studio" }
}
