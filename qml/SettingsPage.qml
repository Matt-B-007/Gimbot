// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtCore
import QtQuick.Layouts
import Gimbot

// Every camera and app setting, in seven groups with a side menu.
Rectangle {
    id: root
    color: Theme.bg
    signal back()
    signal openReport()
    signal openAbout()
    signal confirmFactoryReset()
    signal confirmGoBack()
    signal toast(string message)
    signal saveProfileRequested()
    signal openUpdate()
    signal openTour()
    signal openDirectionCheck()
    signal openUninstall()

    readonly property bool connected: Cam.connected
    readonly property var v: Cam.values
    readonly property bool anyVoice: v.voice0 || v.voice1 || v.voice2 || v.voice3 || v.voice4 || v.voice5 || v.voice6

    function scrollTo(name, groupTop) { // groupTop: the side menu, which goes to the top of a group
        for (let pass = groupTop ? 1 : 0; pass < 2; ++pass)
        for (let i = 0; i < sections.children.length; ++i) {
            const s = sections.children[i]
            // A section by its own name first ("app" is the App card, though
            // Profiles sits above it in the same group); else the group's first.
            if (pass === 0 ? s.sectionId === name : s.navGroup === name) {
                scrollAnim.to = Math.min(s.y, Math.max(0, flick.contentHeight - flick.height))
                scrollAnim.restart()
                return
            }
        }
    }

    readonly property var navItems: [
        { id: "camera", label: qsTr("Camera"), icon: "camera" },
        { id: "tracking", label: qsTr("Tracking"), icon: "area" },
        { id: "image", label: qsTr("Image"), icon: "sun" },
        { id: "voice", label: qsTr("Microphone and voice"), icon: "mic" },
        { id: "gestures", label: qsTr("Gestures"), icon: "hand" },
        { id: "startup", label: qsTr("Startup and sleep"), icon: "power" },
        { id: "app", label: qsTr("App and updates"), icon: "sliders" }
    ]
    // Which section is in view, for highlighting the side menu.
    readonly property string currentSection: {
        let current = "camera"
        for (let i = 0; i < sections.children.length; ++i) {
            const s = sections.children[i]
            if (s.sectionId && s.y - 40 <= flick.contentY) current = s.navGroup
        }
        return current
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout { // header
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            spacing: 12
            IconBtn { iconName: "chevron-left"; tip: qsTr("Back (Esc)"); onClicked: root.back() }
            Text { text: qsTr("Settings"); color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            Rectangle {
                implicitHeight: 32
                implicitWidth: deviceChip.implicitWidth + 24
                radius: 16
                color: Theme.surface
                border.color: Theme.border
                RowLayout {
                    id: deviceChip
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: root.connected ? Theme.success : Theme.textFaint }
                    Text {
                        text: root.connected ? qsTr("%1 · detected automatically").arg(Cam.model) : qsTr("No camera connected")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.small + 1
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ListView { // side menu
                id: nav
                Layout.preferredWidth: root.width > 900 ? 230 : 0
                visible: root.width > 900
                Layout.fillHeight: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                spacing: 2
                model: root.navItems
                Rectangle { // the sidebar surface
                    parent: nav
                    anchors.fill: parent
                    anchors.margins: -8
                    anchors.bottomMargin: 16
                    z: -1
                    radius: Theme.radius
                    color: Theme.sidebar
                }
                interactive: false
                delegate: AbstractButtonLike {
                    id: navItem
                    required property var modelData
                    width: nav.width - 16
                    implicitHeight: 40
                    selected: root.currentSection === modelData.id
                    background: Rectangle {
                        radius: Theme.radiusSm + 2
                        color: navItem.selected ? Theme.surface2 : navItem.hovered ? Theme.hover : "transparent"
                        border.width: navItem.visualFocus ? 2 : 0
                        border.color: Theme.accent
                    }
                    onClicked: root.scrollTo(modelData.id, true)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 10
                        Icon { name: navItem.modelData.icon; size: 16; color: navItem.selected ? Theme.accentText : Theme.textMuted }
                        Text {
                            text: navItem.modelData.label
                            color: navItem.selected ? Theme.text : Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.weight: navItem.selected ? Font.DemiBold : Font.Normal
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: sections.implicitHeight + 48
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                NumberAnimation on contentY { id: scrollAnim; duration: 350; easing.type: Easing.OutCubic; running: false }

                ColumnLayout {
                    id: sections
                    x: 24
                    y: 24
                    width: Math.min(flick.width - 48, 860)
                    spacing: 20

                    // ------------------------------------------------ device
                    Section {
                        sectionId: "device"
                        navGroup: "camera"
                        title: qsTr("Camera")
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 14
                            Repeater {
                                model: [{ k: qsTr("Model"), v: root.connected ? Cam.model : "—" },
                                        { k: qsTr("Serial number"), v: root.connected ? Cam.serial : "—" },
                                        { k: qsTr("Firmware"), v: root.connected ? Cam.firmware : "—" },
                                        { k: qsTr("Firmware updates"), v: qsTr("OBSBOT Center on Windows or macOS (the SDK can't update firmware)") },
                                        { k: qsTr("Gimbot"), v: Platform.version }]
                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 2
                                    Text { text: parent.modelData.k; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
                                    Text {
                                        text: parent.modelData.v
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                        SettingRow {
                            id: sdkRow
                            readonly property string saved: Platform.savedSdk
                            readonly property string savedVersion: saved.replace(/^libdev_?v?/, "").replace(/\.zip$/, "")
                            readonly property bool newer: saved.length > 0 && savedVersion !== Platform.sdkVersion
                            label: qsTr("OBSBOT SDK %1").arg(Platform.sdkVersion)
                            description: saved.length > 0
                                ? (newer ? qsTr("Saved: %1 (newer than this build). Rebuild Gimbot to use it.").arg(saved)
                                         : qsTr("Saved in Gimbot's folder: %1. You can delete it from Downloads.").arg(saved))
                                : qsTr("No SDK saved in Gimbot's folder yet. Add it so updates work without your Downloads folder.")
                            Btn { text: qsTr("Open folder"); iconName: "folder"; variant: "ghost"; compact: true; onClicked: Platform.openSdkFolder() }
                            Btn { text: qsTr("Add SDK…"); iconName: "plus"; compact: true; onClicked: sdkDialog.open() }
                            Btn {
                                visible: sdkRow.newer && Updater.canInstall
                                text: qsTr("Rebuild")
                                iconName: "refresh"
                                variant: "primary"
                                compact: true
                                onClicked: { Updater.rebuild(); root.openUpdate() }
                            }
                        }
                        SettingRow {
                            label: qsTr("Reset to factory settings")
                            description: qsTr("Erases presets and every camera setting")
                            divider: false
                            Btn { text: qsTr("Reset camera…"); variant: "danger"; compact: true; enabled: root.connected; onClicked: root.confirmFactoryReset() }
                        }
                    }

                    // ------------------------------------------------ movement
                    Section {
                        sectionId: "motion"
                        navGroup: "camera"
                        title: qsTr("Movement and zoom")
                        SliderRow {
                            Layout.fillWidth: true
                            label: qsTr("Zoom speed")
                            from: 0; to: 10; stepSize: 1
                            value: root.v.zoomSpeed
                            valueText: root.v.zoomSpeed === 0 ? qsTr("Camera default") : root.v.zoomSpeed + " / 10"
                            onMoved: (x) => Cam.set("zoomSpeed", Math.round(x))
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            label: qsTr("Manual pan and tilt speed")
                            from: 10; to: 120; stepSize: 5
                            value: root.v.gimbalSpeed
                            valueText: root.v.gimbalSpeed + "°/s"
                            onMoved: (x) => Cam.set("gimbalSpeed", Math.round(x))
                        }
                        SettingRow {
                            label: qsTr("Movement")
                            description: qsTr("How smoothly the camera glides for double-click aiming, presets and the arrow keys. The aim pad follows your hand directly.")
                            Segmented {
                                implicitWidth: 340
                                stretch: true
                                options: [qsTr("Fast"), qsTr("Normal"), qsTr("Smooth"), qsTr("Cinematic")]
                                currentIndex: root.v.smoothness
                                onActivated: (i) => Cam.set("smoothness", i)
                            }
                        }
                        SettingRow {
                            label: qsTr("Camera mounted upside down")
                            description: qsTr("Tells the camera to reverse its turning direction")
                            Toggle { checked: root.v.yawReverse; onToggled: Cam.set("yawReverse", checked) }
                        }

                        Label2 { text: qsTr("Advanced"); Layout.topMargin: 8 }
                        SettingRow {
                            label: qsTr("Check movement directions")
                            description: qsTr("Up should move the camera up and Right should move it right. If they don't, this fixes it in two steps.")
                            Btn { text: qsTr("Check…"); iconName: "move"; compact: true; enabled: root.connected; onClicked: root.openDirectionCheck() }
                        }
                        SettingRow {
                            label: qsTr("Flip left and right")
                            description: qsTr("For every control: arrow keys, the aim pad, double-click aiming and dragging. Normally off.")
                            Toggle { checked: root.v.invertPan; onToggled: Cam.set("invertPan", checked) }
                        }
                        SettingRow {
                            label: qsTr("Flip up and down")
                            description: qsTr("For every control. Normally off.")
                            divider: false
                            Toggle { checked: root.v.invertTilt; onToggled: Cam.set("invertTilt", checked) }
                        }
                    }

                    // ================================================ TRACKING
                    // ------------------------------------------------ tracking
                    Section {
                        sectionId: "tracking"
                        title: qsTr("Tracking")
                        subtitle: qsTr("How the camera behaves while it follows you.")
                        SettingRow {
                            label: qsTr("Zoom in automatically while tracking")
                            Toggle { checked: root.v.autoZoom; onToggled: Cam.set("autoZoom", checked) }
                        }
                        SettingRow {
                            label: qsTr("Resume tracking by itself")
                            description: qsTr("After you move the camera by hand, turn tracking back on once you stop")
                            Toggle { checked: root.v.autoResume; onToggled: Cam.set("autoResume", checked) }
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            visible: root.v.autoResume
                            label: qsTr("Resume after")
                            from: 2; to: 30; stepSize: 1
                            value: root.v.autoResumeSeconds
                            valueText: qsTr("%1 s").arg(root.v.autoResumeSeconds)
                            onMoved: (x) => Cam.set("autoResumeSeconds", Math.round(x))
                        }
                    }

                    // ------------------------------------------------ tracking area
                    Section {
                        sectionId: "area"
                        navGroup: "tracking"
                        title: qsTr("Tracking area")
                        subtitle: qsTr("Keep tracking inside a set area, so the camera never turns toward a window or a door.")
                        SettingRow {
                            label: qsTr("Guide light while adjusting the tracking area")
                            description: qsTr("The camera's light shows a pattern while you change the area")
                            Toggle { checked: root.v.guideLight; onToggled: Cam.set("guideLight", checked) }
                        }
                        headerExtras: Toggle {
                            checked: root.v.zoneEnabled
                            enabled: root.connected
                            Accessible.name: qsTr("Limit tracking to an area")
                            onToggled: Cam.set("zoneEnabled", checked)
                        }

                        Rectangle { // picture of the area
                            Layout.fillWidth: true
                            Layout.preferredHeight: width / 2.6
                            radius: Theme.radius
                            color: Theme.sunken
                            border.color: Theme.border
                            clip: true
                            readonly property real yawRange: 120
                            readonly property real pitchRange: 90
                            Rectangle { x: parent.width / 2; width: 1; height: parent.height; color: Theme.border }
                            Rectangle { y: parent.height / 2; height: 1; width: parent.width; color: Theme.border }
                            Rectangle {
                                readonly property real l: (root.v.zoneYawMin + parent.yawRange) / (2 * parent.yawRange)
                                readonly property real r: (root.v.zoneYawMax + parent.yawRange) / (2 * parent.yawRange)
                                readonly property real t: (root.v.zonePitchMin + parent.pitchRange) / (2 * parent.pitchRange)
                                readonly property real b: (root.v.zonePitchMax + parent.pitchRange) / (2 * parent.pitchRange)
                                x: parent.width * l
                                width: parent.width * Math.max(0, r - l)
                                y: parent.height * t
                                height: parent.height * Math.max(0, b - t)
                                radius: 8
                                color: root.v.zoneEnabled ? Theme.accentSoft : "transparent"
                                border.width: 1.5
                                border.color: root.v.zoneEnabled ? Theme.accent : Theme.textFaint
                                Behavior on x { NumberAnimation { duration: Theme.fast } }
                                Behavior on width { NumberAnimation { duration: Theme.fast } }
                                Behavior on y { NumberAnimation { duration: Theme.fast } }
                                Behavior on height { NumberAnimation { duration: Theme.fast } }
                                Text { x: 8; y: 6; text: qsTr("Tracking area"); color: Theme.accentText; font.family: Theme.font; font.pixelSize: 11 }
                            }
                            Rectangle { // where the camera points now
                                width: 12; height: 12; radius: 6
                                color: Theme.text
                                // The area uses the SDK's frame: yaw + is your right, pitch + is down.
                                x: parent.width * (Cam.rawYaw + parent.yawRange) / (2 * parent.yawRange) - 6
                                y: parent.height * (Cam.rawPitch + parent.pitchRange) / (2 * parent.pitchRange) - 6
                            }
                            Text { x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: qsTr("Your left"); color: Theme.textFaint; font.family: Theme.font; font.pixelSize: 11 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: qsTr("Your right"); color: Theme.textFaint; font.family: Theme.font; font.pixelSize: 11 }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 16
                            enabled: root.connected
                            SliderRow {
                                Layout.fillWidth: true
                                label: qsTr("Left limit")
                                from: -120; to: 0; stepSize: 1
                                value: root.v.zoneYawMin
                                valueText: Math.round(-root.v.zoneYawMin) + "°"
                                onMoved: (x) => Cam.set("zoneYawMin", Math.round(x))
                            }
                            SliderRow {
                                Layout.fillWidth: true
                                label: qsTr("Right limit")
                                from: 0; to: 120; stepSize: 1
                                value: root.v.zoneYawMax
                                valueText: Math.round(root.v.zoneYawMax) + "°"
                                onMoved: (x) => Cam.set("zoneYawMax", Math.round(x))
                            }
                            SliderRow {
                                Layout.fillWidth: true
                                label: qsTr("Upper limit")
                                from: 0; to: 90; stepSize: 1
                                value: -root.v.zonePitchMin
                                valueText: Math.round(-root.v.zonePitchMin) + "° " + qsTr("up")
                                onMoved: (x) => Cam.set("zonePitchMin", -Math.round(x))
                            }
                            SliderRow {
                                Layout.fillWidth: true
                                label: qsTr("Lower limit")
                                from: 0; to: 90; stepSize: 1
                                value: root.v.zonePitchMax
                                valueText: Math.round(root.v.zonePitchMax) + "° " + qsTr("down")
                                onMoved: (x) => Cam.set("zonePitchMax", Math.round(x))
                            }
                        }
                        SettingRow {
                            label: qsTr("Pick who to track automatically")
                            description: qsTr("When off, you choose the person with a gesture.")
                            Toggle { checked: root.v.zoneAutoSelect; enabled: root.connected; onToggled: Cam.set("zoneAutoSelect", checked) }
                        }
                        SettingRow {
                            label: qsTr("Starting position in the area")
                            divider: false
                            Btn { text: qsTr("Use current view"); compact: true; enabled: root.connected; onClicked: Cam.zoneStart("use-current") }
                            Btn { text: qsTr("Go there"); compact: true; enabled: root.connected; onClicked: Cam.zoneStart("go") }
                            Btn { text: qsTr("Reset area"); variant: "ghost"; compact: true; enabled: root.connected; onClicked: { Cam.resetZone(); Cam.zoneStart("reset") } }
                        }
                    }

                    // ------------------------------------------------ image
                    Section {
                        sectionId: "image"
                        title: qsTr("Image")
                        headerExtras: Btn { text: qsTr("Reset all"); variant: "ghost"; compact: true; enabled: root.connected; onClicked: Cam.resetImage() }

                        Label2 { text: qsTr("Field of view") }
                        Segmented {
                            Layout.fillWidth: true
                            stretch: true
                            options: [qsTr("Wide 86°"), qsTr("Medium 78°"), qsTr("Narrow 65°")]
                            currentIndex: root.v.fov
                            enabled: root.connected
                            onActivated: (i) => Cam.set("fov", i)
                        }

                        SettingRow {
                            label: qsTr("Automatic exposure")
                            Toggle { checked: root.v.exposureAuto; enabled: root.connected; onToggled: Cam.set("exposureAuto", checked) }
                        }
                        SettingRow {
                            label: qsTr("Shutter speed")
                            dim: root.v.exposureAuto
                            Select {
                                implicitWidth: 160
                                model: Cam.shutterLabels
                                currentIndex: root.v.shutter - 9
                                enabled: root.connected
                                onActivated: (i) => Cam.set("shutter", i + 9)
                            }
                        }
                        SettingRow {
                            label: qsTr("Expose for faces")
                            Toggle { checked: root.v.faceExposure; enabled: root.connected; onToggled: Cam.set("faceExposure", checked) }
                        }
                        SettingRow {
                            label: qsTr("Autofocus")
                            Toggle { checked: root.v.autoFocus; enabled: root.connected; onToggled: Cam.set("autoFocus", checked) }
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            label: qsTr("Manual focus")
                            valueText: qsTr("Near ↔ far")
                            from: 0; to: 100; stepSize: 1
                            value: root.v.manualFocus
                            dim: root.v.autoFocus
                            enabled: root.connected
                            onMoved: (x) => Cam.set("manualFocus", Math.round(x))
                        }
                        SettingRow {
                            label: qsTr("Focus on faces")
                            Toggle { checked: root.v.faceFocus; enabled: root.connected; onToggled: Cam.set("faceFocus", checked) }
                        }

                        Label2 { text: qsTr("White balance") }
                        Segmented {
                            Layout.fillWidth: true
                            stretch: true
                            options: [qsTr("Auto"), qsTr("Daylight"), qsTr("Cloudy"), qsTr("Indoor"), qsTr("Fluorescent"), qsTr("Manual")]
                            currentIndex: root.v.wbMode
                            enabled: root.connected
                            onActivated: (i) => Cam.set("wbMode", i)
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            visible: root.v.wbMode === 5
                            label: qsTr("Temperature")
                            from: Cam.ranges.wb.min; to: Cam.ranges.wb.max; stepSize: 100
                            value: root.v.wbKelvin
                            valueText: root.v.wbKelvin + " K"
                            onMoved: (x) => Cam.set("wbKelvin", Math.round(x / 100) * 100)
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            columns: width > 560 ? 2 : 1
                            columnSpacing: 24
                            rowSpacing: 16
                            enabled: root.connected
                            Repeater {
                                model: [{ key: "brightness", label: qsTr("Brightness") }, { key: "contrast", label: qsTr("Contrast") },
                                        { key: "saturation", label: qsTr("Saturation") }, { key: "sharpness", label: qsTr("Sharpness") },
                                        { key: "hue", label: qsTr("Hue") }]
                                SliderRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: modelData.label
                                    from: Cam.ranges[modelData.key].min
                                    to: Cam.ranges[modelData.key].max
                                    stepSize: 1
                                    value: root.v[modelData.key]
                                    onMoved: (x) => Cam.set(modelData.key, Math.round(x))
                                }
                            }
                        }

                        Label2 { text: qsTr("Anti-flicker"); Layout.topMargin: 6 }
                        Segmented {
                            Layout.fillWidth: true
                            stretch: true
                            options: [qsTr("Off"), qsTr("50 Hz"), qsTr("60 Hz"), qsTr("Auto")]
                            currentIndex: root.v.antiFlicker
                            enabled: root.connected
                            onActivated: (i) => Cam.set("antiFlicker", i)
                        }
                        SettingRow {
                            label: qsTr("HDR")
                            Toggle { checked: root.v.hdr; enabled: root.connected; onToggled: Cam.set("hdr", checked) }
                        }
                        SettingRow {
                            label: qsTr("Mirror image")
                            divider: false
                            Toggle { checked: root.v.mirrored; enabled: root.connected; onToggled: Cam.set("mirrored", checked) }
                        }
                    }

                    // ------------------------------------------------ microphone and voice
                    Section {
                        sectionId: "voice"
                        title: qsTr("Microphone and voice")
                        subtitle: qsTr("How the camera’s microphone sounds, and the commands you can say to it.")
                        SettingRow {
                            label: qsTr("Automatic mic volume")
                            description: qsTr("Evens out loud and quiet speech")
                            Toggle { checked: root.v.audioAutoGain; enabled: root.connected; onToggled: Cam.set("audioAutoGain", checked) }
                        }
                        SettingRow {
                            label: qsTr("Keep the microphone on while asleep")
                            description: qsTr("Other apps can still hear you while the camera sleeps")
                            Toggle { checked: root.v.micDuringSleep; enabled: root.connected; onToggled: Cam.set("micDuringSleep", checked) }
                        }
                        SettingRow {
                            id: voiceMaster
                            label: qsTr("Voice commands")
                            Toggle {
                                checked: root.anyVoice
                                enabled: root.connected
                                onToggled: { for (let i = 0; i < 7; ++i) Cam.set("voice" + i, checked) }
                            }
                        }
                        SettingRow {
                            label: qsTr("Language")
                            Segmented {
                                implicitWidth: 220
                                stretch: true
                                options: [qsTr("English"), qsTr("Chinese")]
                                currentIndex: root.v.voiceLanguage === 0 ? 1 : 0
                                enabled: root.connected
                                onActivated: (i) => Cam.set("voiceLanguage", i === 0 ? 1 : 0)
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > 560 ? 2 : 1
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: ["Hi Tiny", "Sleep Tiny", "Track me", "Unlock", "Zoom in", "Zoom out", qsTr("Preset position 1, 2, 3")]
                                Rectangle {
                                    id: voiceRow
                                    required property int index
                                    required property string modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    radius: Theme.radius
                                    color: Theme.surface2
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 10
                                        Text {
                                            text: "“" + voiceRow.modelData + "”"
                                            color: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize - 1
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        Toggle {
                                            checked: root.v["voice" + voiceRow.index]
                                            enabled: root.connected
                                            Accessible.name: voiceRow.modelData
                                            onToggled: Cam.set("voice" + voiceRow.index, checked)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ------------------------------------------------ gestures
                    Section {
                        sectionId: "gestures"
                        title: qsTr("Gestures")
                        SettingRow {
                            label: qsTr("Select or release the target")
                            description: qsTr("Raise an open palm")
                            Toggle { checked: root.v.gestureSelect; onToggled: Cam.set("gestureSelect", checked) }
                        }
                        SettingRow {
                            label: qsTr("Zoom in and out")
                            description: qsTr("Make an L shape with your thumb and finger")
                            Toggle { checked: root.v.gestureZoom; onToggled: Cam.set("gestureZoom", checked) }
                        }
                        SettingRow {
                            label: qsTr("Dynamic zoom")
                            Toggle { checked: root.v.gestureDynamic; onToggled: Cam.set("gestureDynamic", checked) }
                        }
                        SettingRow {
                            label: qsTr("Reverse dynamic zoom direction")
                            divider: false
                            dim: !root.v.gestureDynamic
                            Toggle { checked: root.v.gestureReverse; enabled: root.v.gestureDynamic; onToggled: Cam.set("gestureReverse", checked) }
                        }
                    }

                    // ------------------------------------------------ startup and sleep
                    Section {
                        sectionId: "startup"
                        title: qsTr("Startup and sleep")
                        subtitle: qsTr("What the camera does when it turns on, and when it goes to sleep.")
                        SettingRow {
                            label: qsTr("Start position and zoom")
                            description: qsTr("Saved on the camera")
                            Btn { text: qsTr("Use current view"); compact: true; enabled: root.connected; onClicked: Cam.startup("use-current") }
                            Btn { text: qsTr("Go there"); compact: true; enabled: root.connected; onClicked: Cam.startup("go") }
                            Btn { text: qsTr("Reset"); variant: "ghost"; compact: true; enabled: root.connected; onClicked: Cam.startup("reset") }
                        }
                        SettingRow {
                            label: qsTr("Tracking mode at startup")
                            Select {
                                model: [qsTr("Off"), qsTr("Person · upper body"), qsTr("Person · full body"), qsTr("Person · close-up"),
                                        qsTr("Group"), qsTr("Hand"), qsTr("Desk"), qsTr("Whiteboard")]
                                currentIndex: root.v.bootMode
                                enabled: root.connected
                                onActivated: (i) => Cam.set("bootMode", i)
                            }
                        }
                        SettingRow {
                            label: qsTr("Go to sleep when idle")
                            Select {
                                readonly property var seconds: [0, 300, 600, 1800, 3600]
                                model: [qsTr("Never"), qsTr("After 5 minutes"), qsTr("After 10 minutes"), qsTr("After 30 minutes"), qsTr("After 1 hour")]
                                currentIndex: Math.max(0, seconds.indexOf(root.v.sleepTimer))
                                onActivated: (i) => Cam.set("sleepTimer", seconds[i])
                            }
                        }
                        SettingRow {
                            label: qsTr("Picture on the camera while asleep")
                            description: qsTr("One of the three pictures saved on the camera")
                            divider: false
                            SleepPicturePicker { enabled: root.connected && root.v.hasSleepPicture; showLabel: false }
                        }
                    }

                    // ------------------------------------------------ profiles
                    Section {
                        sectionId: "profiles"
                        navGroup: "app"
                        title: qsTr("Profiles")
                        subtitle: qsTr("Save your whole setup, like “Meetings” or “Streaming”, and switch in one click.")
                        headerExtras: Btn { text: qsTr("Save current…"); iconName: "plus"; compact: true; onClicked: root.saveProfileRequested() }

                        Text {
                            visible: Cam.profiles.length === 0
                            text: qsTr("No profiles yet.")
                            color: Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Repeater {
                            model: Cam.profiles
                            SettingRow {
                                id: profileRow
                                required property string modelData
                                label: modelData
                                Btn { text: qsTr("Apply"); variant: "outline"; compact: true; enabled: root.connected; onClicked: Cam.applyProfile(profileRow.modelData) }
                                IconBtn { iconName: "trash"; tip: qsTr("Delete profile"); implicitWidth: 32; implicitHeight: 32; iconSize: 15; onClicked: Cam.deleteProfile(profileRow.modelData) }
                            }
                        }
                        RowLayout {
                            spacing: 8
                            Btn { text: qsTr("Import…"); iconName: "upload"; variant: "ghost"; compact: true; onClicked: importDialog.open() }
                            Btn { text: qsTr("Export…"); iconName: "download"; variant: "ghost"; compact: true; enabled: Cam.profiles.length > 0; onClicked: exportDialog.open() }
                        }
                    }

                    // ------------------------------------------------ app
                    Section {
                        sectionId: "app"
                        title: qsTr("App and updates")
                        Label2 { text: qsTr("Appearance") }
                        SettingRow {
                            label: qsTr("Theme")
                            Segmented {
                                implicitWidth: 260
                                stretch: true
                                options: [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                                currentIndex: root.v.theme
                                onActivated: (i) => Cam.set("theme", i)
                            }
                        }
                        SettingRow {
                            label: qsTr("Accent color")
                            description: qsTr("Use Gimbot's color or your Plasma accent")
                            Segmented {
                                implicitWidth: 260
                                stretch: true
                                options: [qsTr("Gimbot"), qsTr("System")]
                                currentIndex: root.v.systemAccent ? 1 : 0
                                onActivated: (i) => Cam.set("systemAccent", i === 1)
                            }
                        }
                        SettingRow {
                            label: qsTr("Plain background")
                            description: qsTr("Hides the faint dot pattern behind the preview when there's no picture. It's also hidden when animations are turned off in System Settings.")
                            Toggle { checked: root.v.plainBackground; onToggled: Cam.set("plainBackground", checked) }
                        }
                        SettingRow {
                            label: qsTr("Show framing grid on the preview")
                            Toggle { checked: root.v.showGrid; onToggled: Cam.set("showGrid", checked) }
                        }
                        SettingRow {
                            label: qsTr("Show live preview")
                            description: qsTr("Turn off to leave the camera's video free for other apps")
                            Toggle { checked: root.v.previewEnabled; onToggled: Cam.set("previewEnabled", checked) }
                        }

                        Label2 { text: qsTr("Behavior"); Layout.topMargin: 8 }
                        SettingRow {
                            label: qsTr("Keep running in the tray when closed")
                            description: Platform.trayAvailable ? "" : qsTr("No system tray was found")
                            Toggle { checked: root.v.closeToTray; enabled: Platform.trayAvailable; onToggled: Cam.set("closeToTray", checked) }
                        }
                        SettingRow {
                            label: qsTr("Start Gimbot when you log in")
                            description: qsTr("Starts hidden in the tray")
                            Toggle { checked: root.v.autostart; onToggled: Cam.set("autostart", checked) }
                        }
                        SettingRow {
                            visible: Platform.kdeIntegration
                            label: qsTr("Keyboard shortcuts")
                            description: qsTr("Assign keys that work in any app in System Settings › Shortcuts › Gimbot")
                            Btn { text: qsTr("Open"); iconName: "external"; compact: true; onClicked: Platform.openUrl("systemsettings://kcm_keys") }
                        }

                        Label2 { text: qsTr("Updates"); Layout.topMargin: 8 }
                        SettingRow {
                            label: qsTr("Tell me about new versions")
                            description: !Updater.configured ? qsTr("Not available in this build")
                                        : root.v.updateChannel === 2 ? qsTr("Includes beta versions, which may have bugs. Switching back offers the newest normal version.")
                                        : Updater.installType === "aur" ? qsTr("Installed from the AUR, so it updates with your AUR helper")
                                        : Updater.canInstall ? qsTr("Gimbot installs signed updates for you with one click")
                                        : qsTr("Update with your package manager")
                            Segmented {
                                implicitWidth: 260
                                stretch: true
                                enabled: Updater.configured
                                options: [qsTr("Off"), qsTr("Normal"), qsTr("Beta")]
                                currentIndex: root.v.updateChannel
                                onActivated: (i) => Cam.set("updateChannel", i)
                            }
                        }
                        SettingRow {
                            visible: Updater.configured && root.v.updateChannel > 0
                            label: Updater.state === "checking" ? qsTr("Checking…")
                                 : Updater.state === "available" ? qsTr("Version %1 is available").arg(Updater.latestVersion)
                                 : Updater.state === "upToDate" ? qsTr("You're up to date (%1)").arg(Platform.version)
                                 : Updater.state === "error" ? qsTr("Couldn't check for updates")
                                 : qsTr("Current version: %1").arg(Platform.version)
                            description: {
                                let d = []
                                if (Updater.state === "error") d.push(Updater.checkError)
                                else if (Updater.usedDnsFallback)
                                    d.push(qsTr("This computer's DNS isn't working, so Gimbot checked through a public DNS service. Other apps may not connect."))
                                if (Updater.lastChecked.length > 0) d.push(qsTr("Last checked %1").arg(Updater.lastChecked))
                                return d.join("\n")
                            }
                            Btn {
                                visible: (Updater.state === "error" && Updater.checkError.indexOf("DNS") >= 0) || Updater.usedDnsFallback
                                text: qsTr("How to fix")
                                iconName: "external"
                                variant: "ghost"
                                compact: true
                                onClicked: Platform.openUrl(Platform.repoUrl + "#cant-reach-github")
                            }
                            Btn {
                                visible: Updater.state === "available"
                                text: Updater.canInstall ? (Updater.isSwitch ? qsTr("Switch now") : qsTr("Update now")) : qsTr("What's new")
                                iconName: Updater.canInstall ? "download" : "external"
                                variant: Updater.canInstall ? "primary" : "outline"
                                compact: true
                                onClicked: Updater.canInstall ? root.openUpdate() : Platform.openUrl(Updater.latestUrl)
                            }
                            Btn {
                                text: Updater.state === "checking" ? qsTr("Checking…")
                                    : Updater.state === "error" ? (Updater.retryIn > 0 ? qsTr("Try again in %1 s").arg(Updater.retryIn) : qsTr("Try again"))
                                    : qsTr("Check now")
                                iconName: "refresh"
                                compact: true
                                enabled: Updater.state !== "checking" && !(Updater.state === "error" && Updater.retryIn > 0)
                                tip: Updater.retryIn > 0 ? qsTr("Waiting a moment before asking GitHub again") : ""
                                onClicked: Updater.check()
                            }
                        }
                        SettingRow { // AUR installs update through the AUR helper
                            visible: Updater.installType === "aur"
                            label: qsTr("Update from the AUR")
                            description: qsTr("Run this in a terminal: %1").arg(Updater.aurCommand)
                            Btn {
                                text: qsTr("Copy command")
                                iconName: "copy"
                                compact: true
                                onClicked: { Platform.copyToClipboard(Updater.aurCommand); root.toast(qsTr("Copied")) }
                            }
                        }
                        SettingRow {
                            visible: Updater.canInstall && Updater.previousVersion.length > 0
                            label: qsTr("Go back to Gimbot %1").arg(Updater.previousVersion)
                            description: qsTr("Reinstall the version you had before the last update, if this one misbehaves. Your settings stay.")
                            Btn {
                                text: qsTr("Go back…")
                                iconName: "undo"
                                compact: true
                                enabled: Updater.installState !== "running"
                                onClicked: root.confirmGoBack()
                            }
                        }

                        Label2 { text: qsTr("Help"); Layout.topMargin: 8 }
                        SettingRow {
                            label: qsTr("Tour")
                            description: qsTr("A quick look at the main controls")
                            Btn { text: qsTr("Show the tour"); iconName: "help"; compact: true; onClicked: root.openTour() }
                        }
                        SettingRow {
                            label: qsTr("Report a problem")
                            description: qsTr("Collects version and log details for a bug report. Nothing is sent without you.")
                            Btn { text: qsTr("Report…"); iconName: "bug"; compact: true; onClicked: root.openReport() }
                        }
                        SettingRow {
                            label: qsTr("Detailed logging")
                            description: qsTr("Records more detail to help track down hard bugs")
                            Toggle { checked: root.v.verboseLogging; onToggled: Cam.set("verboseLogging", checked) }
                        }
                        SettingRow {
                            label: qsTr("Log files")
                            Btn { text: qsTr("Open folder"); iconName: "folder"; variant: "ghost"; compact: true; onClicked: Platform.openLogFolder() }
                            Btn { text: qsTr("About Gimbot"); iconName: "info"; variant: "ghost"; compact: true; onClicked: root.openAbout() }
                        }
                        SettingRow {
                            label: qsTr("Uninstall Gimbot")
                            description: qsTr("Removes the app. You choose whether to keep your settings.")
                            divider: false
                            Btn { text: qsTr("Uninstall…"); variant: "danger"; compact: true; onClicked: root.openUninstall() }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Gimbot is not affiliated with OBSBOT or Remo Tech.")
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.small
                    }
                }
            }
        }
    }

    FileDialog {
        id: sdkDialog
        title: qsTr("Choose the OBSBOT SDK zip")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("OBSBOT SDK (libdev*.zip)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        onAccepted: {
            if (Platform.adoptSdk(selectedFile) && Updater.canInstall) { Updater.rebuild(); root.openUpdate() }
        }
    }
    FileDialog {
        id: exportDialog
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("Gimbot profiles (*.json)")]
        defaultSuffix: "json"
        onAccepted: Cam.exportProfiles(selectedFile)
    }
    FileDialog {
        id: importDialog
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Gimbot profiles (*.json)")]
        onAccepted: Cam.importProfiles(selectedFile)
    }

    component Section: Card {
        property string sectionId: ""
        property string navGroup: sectionId // which side-menu item it belongs to
        Layout.fillWidth: true
        padding: 22
    }
    component Label2: Text {
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.small
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }
}
