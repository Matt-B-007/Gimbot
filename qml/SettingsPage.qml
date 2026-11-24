import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

// Every camera and app setting, grouped into sections with a side menu.
Rectangle {
    id: root
    color: Theme.bg
    signal back()
    signal openReport()
    signal openAbout()
    signal confirmFactoryReset()
    signal saveProfileRequested()

    readonly property bool connected: cam.connected
    readonly property var v: cam.values
    readonly property bool anyVoice: v.voice0 || v.voice1 || v.voice2 || v.voice3 || v.voice4 || v.voice5 || v.voice6

    function scrollTo(name) {
        for (let i = 0; i < sections.children.length; ++i) {
            const s = sections.children[i]
            if (s.sectionId === name) {
                scrollAnim.to = Math.min(s.y, Math.max(0, flick.contentHeight - flick.height))
                scrollAnim.restart()
                return
            }
        }
    }

    readonly property var navItems: [
        { id: "area", label: qsTr("Tracking area"), icon: "area" },
        { id: "startup", label: qsTr("Startup and power"), icon: "power" },
        { id: "voice", label: qsTr("Audio and voice"), icon: "mic" },
        { id: "image", label: qsTr("Image"), icon: "sun" },
        { id: "motion", label: qsTr("Movement and zoom"), icon: "crosshair" },
        { id: "gestures", label: qsTr("Gestures"), icon: "hand" },
        { id: "profiles", label: qsTr("Profiles"), icon: "layers" },
        { id: "app", label: qsTr("App"), icon: "sliders" },
        { id: "device", label: qsTr("Device"), icon: "camera" }
    ]
    // Which section is in view, for highlighting the side menu.
    readonly property string currentSection: {
        let current = "area"
        for (let i = 0; i < sections.children.length; ++i) {
            const s = sections.children[i]
            if (s.sectionId && s.y - 40 <= flick.contentY) current = s.sectionId
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
                    Rectangle { width: 8; height: 8; radius: 4; color: root.connected ? Theme.success : Theme.textFaint }
                    Text {
                        text: root.connected ? qsTr("%1 · detected automatically").arg(cam.model) : qsTr("No camera connected")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.small + 1
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

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
                    onClicked: root.scrollTo(modelData.id)
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

                    // ------------------------------------------------ tracking area
                    Section {
                        sectionId: "area"
                        title: qsTr("Tracking area")
                        subtitle: qsTr("Keep tracking inside a set area, so the camera never turns toward a window or a door.")
                        headerExtras: Toggle {
                            checked: root.v.zoneEnabled
                            enabled: root.connected
                            Accessible.name: qsTr("Limit tracking to an area")
                            onToggled: cam.set("zoneEnabled", checked)
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
                                x: parent.width * (cam.pan + parent.yawRange) / (2 * parent.yawRange) - 6
                                y: parent.height * (-cam.tilt + parent.pitchRange) / (2 * parent.pitchRange) - 6
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
                                onMoved: (x) => cam.set("zoneYawMin", Math.round(x))
                            }
                            SliderRow {
                                Layout.fillWidth: true
                                label: qsTr("Right limit")
                                from: 0; to: 120; stepSize: 1
                                value: root.v.zoneYawMax
                                valueText: Math.round(root.v.zoneYawMax) + "°"
                                onMoved: (x) => cam.set("zoneYawMax", Math.round(x))
                            }
                            SliderRow {
                                Layout.fillWidth: true
                                label: qsTr("Upper limit")
                                from: 0; to: 90; stepSize: 1
                                value: -root.v.zonePitchMin
                                valueText: Math.round(-root.v.zonePitchMin) + "° " + qsTr("up")
                                onMoved: (x) => cam.set("zonePitchMin", -Math.round(x))
                            }
                            SliderRow {
                                Layout.fillWidth: true
                                label: qsTr("Lower limit")
                                from: 0; to: 90; stepSize: 1
                                value: root.v.zonePitchMax
                                valueText: Math.round(root.v.zonePitchMax) + "° " + qsTr("down")
                                onMoved: (x) => cam.set("zonePitchMax", Math.round(x))
                            }
                        }
                        SettingRow {
                            label: qsTr("Pick who to track automatically")
                            description: qsTr("When off, you choose the person with a gesture.")
                            Toggle { checked: root.v.zoneAutoSelect; enabled: root.connected; onToggled: cam.set("zoneAutoSelect", checked) }
                        }
                        SettingRow {
                            label: qsTr("Starting position in the area")
                            divider: false
                            Btn { text: qsTr("Use current view"); compact: true; enabled: root.connected; onClicked: cam.zoneStart("use-current") }
                            Btn { text: qsTr("Go there"); compact: true; enabled: root.connected; onClicked: cam.zoneStart("go") }
                            Btn { text: qsTr("Reset area"); variant: "ghost"; compact: true; enabled: root.connected; onClicked: { cam.resetZone(); cam.zoneStart("reset") } }
                        }
                    }

                    // ------------------------------------------------ startup and power
                    Section {
                        sectionId: "startup"
                        title: qsTr("Startup and power")
                        subtitle: qsTr("What the camera does when it turns on, and when it goes to sleep.")
                        SettingRow {
                            label: qsTr("Start position and zoom")
                            description: qsTr("Saved on the camera")
                            Btn { text: qsTr("Use current view"); compact: true; enabled: root.connected; onClicked: cam.startup("use-current") }
                            Btn { text: qsTr("Go there"); compact: true; enabled: root.connected; onClicked: cam.startup("go") }
                            Btn { text: qsTr("Reset"); variant: "ghost"; compact: true; enabled: root.connected; onClicked: cam.startup("reset") }
                        }
                        SettingRow {
                            label: qsTr("Tracking mode at startup")
                            Select {
                                model: [qsTr("Off"), qsTr("Person · upper body"), qsTr("Person · full body"), qsTr("Person · close-up"),
                                        qsTr("Group"), qsTr("Hand"), qsTr("Desk"), qsTr("Whiteboard")]
                                currentIndex: root.v.bootMode
                                enabled: root.connected
                                onActivated: (i) => cam.set("bootMode", i)
                            }
                        }
                        SettingRow {
                            label: qsTr("Go to sleep when idle")
                            Select {
                                readonly property var seconds: [0, 300, 600, 1800, 3600]
                                model: [qsTr("Never"), qsTr("After 5 minutes"), qsTr("After 10 minutes"), qsTr("After 30 minutes"), qsTr("After 1 hour")]
                                currentIndex: Math.max(0, seconds.indexOf(root.v.sleepTimer))
                                onActivated: (i) => cam.set("sleepTimer", seconds[i])
                            }
                        }
                        SettingRow {
                            label: qsTr("Keep the microphone on while asleep")
                            divider: false
                            Toggle { checked: root.v.micDuringSleep; enabled: root.connected; onToggled: cam.set("micDuringSleep", checked) }
                        }
                    }

                    // ------------------------------------------------ audio and voice
                    Section {
                        sectionId: "voice"
                        title: qsTr("Audio and voice")
                        subtitle: qsTr("Say a command to the camera instead of reaching for the app.")
                        SettingRow {
                            label: qsTr("Automatic mic volume")
                            description: qsTr("Evens out loud and quiet speech")
                            Toggle { checked: root.v.audioAutoGain; enabled: root.connected; onToggled: cam.set("audioAutoGain", checked) }
                        }
                        SettingRow {
                            id: voiceMaster
                            label: qsTr("Voice commands")
                            Toggle {
                                checked: root.anyVoice
                                enabled: root.connected
                                onToggled: { for (let i = 0; i < 7; ++i) cam.set("voice" + i, checked) }
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
                                onActivated: (i) => cam.set("voiceLanguage", i === 0 ? 1 : 0)
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
                                            onToggled: cam.set("voice" + voiceRow.index, checked)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ------------------------------------------------ image
                    Section {
                        sectionId: "image"
                        title: qsTr("Image")
                        headerExtras: Btn { text: qsTr("Reset all"); variant: "ghost"; compact: true; enabled: root.connected; onClicked: cam.resetImage() }

                        Label2 { text: qsTr("Field of view") }
                        Segmented {
                            Layout.fillWidth: true
                            stretch: true
                            options: [qsTr("Wide 86°"), qsTr("Medium 78°"), qsTr("Narrow 65°")]
                            currentIndex: root.v.fov
                            enabled: root.connected
                            onActivated: (i) => cam.set("fov", i)
                        }

                        SettingRow {
                            label: qsTr("Automatic exposure")
                            Toggle { checked: root.v.exposureAuto; enabled: root.connected; onToggled: cam.set("exposureAuto", checked) }
                        }
                        SettingRow {
                            label: qsTr("Shutter speed")
                            dim: root.v.exposureAuto
                            Select {
                                implicitWidth: 160
                                model: cam.shutterLabels
                                currentIndex: root.v.shutter - 9
                                enabled: root.connected
                                onActivated: (i) => cam.set("shutter", i + 9)
                            }
                        }
                        SettingRow {
                            label: qsTr("Expose for faces")
                            Toggle { checked: root.v.faceExposure; enabled: root.connected; onToggled: cam.set("faceExposure", checked) }
                        }
                        SettingRow {
                            label: qsTr("Autofocus")
                            Toggle { checked: root.v.autoFocus; enabled: root.connected; onToggled: cam.set("autoFocus", checked) }
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            label: qsTr("Manual focus")
                            valueText: qsTr("Near ↔ far")
                            from: 0; to: 100; stepSize: 1
                            value: root.v.manualFocus
                            dim: root.v.autoFocus
                            enabled: root.connected
                            onMoved: (x) => cam.set("manualFocus", Math.round(x))
                        }
                        SettingRow {
                            label: qsTr("Focus on faces")
                            Toggle { checked: root.v.faceFocus; enabled: root.connected; onToggled: cam.set("faceFocus", checked) }
                        }

                        Label2 { text: qsTr("White balance") }
                        Segmented {
                            Layout.fillWidth: true
                            stretch: true
                            options: [qsTr("Auto"), qsTr("Daylight"), qsTr("Cloudy"), qsTr("Tungsten"), qsTr("Fluorescent"), qsTr("Manual")]
                            currentIndex: root.v.wbMode
                            enabled: root.connected
                            onActivated: (i) => cam.set("wbMode", i)
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            visible: root.v.wbMode === 5
                            label: qsTr("Temperature")
                            from: cam.ranges.wb.min; to: cam.ranges.wb.max; stepSize: 100
                            value: root.v.wbKelvin
                            valueText: root.v.wbKelvin + " K"
                            onMoved: (x) => cam.set("wbKelvin", Math.round(x / 100) * 100)
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
                                    from: cam.ranges[modelData.key].min
                                    to: cam.ranges[modelData.key].max
                                    stepSize: 1
                                    value: root.v[modelData.key]
                                    onMoved: (x) => cam.set(modelData.key, Math.round(x))
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
                            onActivated: (i) => cam.set("antiFlicker", i)
                        }
                        SettingRow {
                            label: qsTr("HDR")
                            Toggle { checked: root.v.hdr; enabled: root.connected; onToggled: cam.set("hdr", checked) }
                        }
                        SettingRow {
                            label: qsTr("Mirror image")
                            divider: false
                            Toggle { checked: root.v.mirrored; enabled: root.connected; onToggled: cam.set("mirrored", checked) }
                        }
                    }

                    // ------------------------------------------------ movement
                    Section {
                        sectionId: "motion"
                        title: qsTr("Movement and zoom")
                        SliderRow {
                            Layout.fillWidth: true
                            label: qsTr("Zoom speed")
                            from: 0; to: 10; stepSize: 1
                            value: root.v.zoomSpeed
                            valueText: root.v.zoomSpeed === 0 ? qsTr("Camera default") : root.v.zoomSpeed + " / 10"
                            onMoved: (x) => cam.set("zoomSpeed", Math.round(x))
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            label: qsTr("Manual pan and tilt speed")
                            from: 10; to: 120; stepSize: 5
                            value: root.v.gimbalSpeed
                            valueText: root.v.gimbalSpeed + "°/s"
                            onMoved: (x) => cam.set("gimbalSpeed", Math.round(x))
                        }
                        SettingRow {
                            label: qsTr("Zoom in automatically while tracking")
                            Toggle { checked: root.v.autoZoom; onToggled: cam.set("autoZoom", checked) }
                        }
                        SettingRow {
                            label: qsTr("Reverse pan direction")
                            description: qsTr("For a camera mounted upside down")
                            Toggle { checked: root.v.yawReverse; onToggled: cam.set("yawReverse", checked) }
                        }
                        SettingRow {
                            label: qsTr("Flip click-to-aim left and right")
                            description: qsTr("If clicking the preview turns the camera the wrong way")
                            Toggle { checked: root.v.invertPan; onToggled: cam.set("invertPan", checked) }
                        }
                        SettingRow {
                            label: qsTr("Flip click-to-aim up and down")
                            divider: false
                            Toggle { checked: root.v.invertTilt; onToggled: cam.set("invertTilt", checked) }
                        }
                    }

                    // ------------------------------------------------ gestures
                    Section {
                        sectionId: "gestures"
                        title: qsTr("Gestures")
                        SettingRow {
                            label: qsTr("Select or release the target")
                            description: qsTr("Raise an open palm")
                            Toggle { checked: root.v.gestureSelect; onToggled: cam.set("gestureSelect", checked) }
                        }
                        SettingRow {
                            label: qsTr("Zoom in and out")
                            description: qsTr("Make an L shape with your thumb and finger")
                            Toggle { checked: root.v.gestureZoom; onToggled: cam.set("gestureZoom", checked) }
                        }
                        SettingRow {
                            label: qsTr("Dynamic zoom")
                            Toggle { checked: root.v.gestureDynamic; onToggled: cam.set("gestureDynamic", checked) }
                        }
                        SettingRow {
                            label: qsTr("Reverse dynamic zoom direction")
                            divider: false
                            dim: !root.v.gestureDynamic
                            Toggle { checked: root.v.gestureReverse; enabled: root.v.gestureDynamic; onToggled: cam.set("gestureReverse", checked) }
                        }
                    }

                    // ------------------------------------------------ profiles
                    Section {
                        sectionId: "profiles"
                        title: qsTr("Profiles")
                        subtitle: qsTr("Save your whole setup, like “Meetings” or “Streaming”, and switch in one click.")
                        headerExtras: Btn { text: qsTr("Save current…"); iconName: "plus"; compact: true; onClicked: root.saveProfileRequested() }

                        Text {
                            visible: cam.profiles.length === 0
                            text: qsTr("No profiles yet.")
                            color: Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                        }
                        Repeater {
                            model: cam.profiles
                            SettingRow {
                                id: profileRow
                                required property string modelData
                                label: modelData
                                Btn { text: qsTr("Apply"); variant: "outline"; compact: true; enabled: root.connected; onClicked: cam.applyProfile(profileRow.modelData) }
                                IconBtn { iconName: "trash"; tip: qsTr("Delete profile"); implicitWidth: 32; implicitHeight: 32; iconSize: 15; onClicked: cam.deleteProfile(profileRow.modelData) }
                            }
                        }
                        RowLayout {
                            spacing: 8
                            Btn { text: qsTr("Import…"); iconName: "upload"; variant: "ghost"; compact: true; onClicked: importDialog.open() }
                            Btn { text: qsTr("Export…"); iconName: "download"; variant: "ghost"; compact: true; enabled: cam.profiles.length > 0; onClicked: exportDialog.open() }
                        }
                    }

                    // ------------------------------------------------ app
                    Section {
                        sectionId: "app"
                        title: qsTr("App")
                        Label2 { text: qsTr("Appearance") }
                        SettingRow {
                            label: qsTr("Theme")
                            Segmented {
                                implicitWidth: 260
                                stretch: true
                                options: [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                                currentIndex: root.v.theme
                                onActivated: (i) => cam.set("theme", i)
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
                                onActivated: (i) => cam.set("systemAccent", i === 1)
                            }
                        }
                        SettingRow {
                            label: qsTr("Show framing grid on the preview")
                            Toggle { checked: root.v.showGrid; onToggled: cam.set("showGrid", checked) }
                        }
                        SettingRow {
                            label: qsTr("Show live preview")
                            description: qsTr("Turn off to leave the camera's video free for other apps")
                            Toggle { checked: root.v.previewEnabled; onToggled: cam.set("previewEnabled", checked) }
                        }

                        Label2 { text: qsTr("Behavior"); Layout.topMargin: 8 }
                        SettingRow {
                            label: qsTr("Keep running in the tray when closed")
                            description: platform.trayAvailable ? "" : qsTr("No system tray was found")
                            Toggle { checked: root.v.closeToTray; enabled: platform.trayAvailable; onToggled: cam.set("closeToTray", checked) }
                        }
                        SettingRow {
                            label: qsTr("Start Gimbot when you log in")
                            description: qsTr("Starts hidden in the tray")
                            Toggle { checked: root.v.autostart; onToggled: cam.set("autostart", checked) }
                        }
                        SettingRow {
                            visible: platform.kdeIntegration
                            label: qsTr("Keyboard shortcuts")
                            description: qsTr("Assign keys that work in any app in System Settings › Shortcuts › Gimbot")
                            Btn { text: qsTr("Open"); iconName: "external"; compact: true; onClicked: platform.openUrl("systemsettings://kcm_keys") }
                        }

                        Label2 { text: qsTr("Updates"); Layout.topMargin: 8 }
                        SettingRow {
                            label: qsTr("Tell me about new versions")
                            description: !updater.configured ? qsTr("Not available in this build")
                                        : root.v.updateChannel === 2 ? qsTr("Includes beta versions, which may have bugs")
                                        : qsTr("Updates are installed by your package manager")
                            Segmented {
                                implicitWidth: 260
                                stretch: true
                                enabled: updater.configured
                                options: [qsTr("Off"), qsTr("Normal"), qsTr("Beta")]
                                currentIndex: root.v.updateChannel
                                onActivated: (i) => cam.set("updateChannel", i)
                            }
                        }
                        SettingRow {
                            visible: updater.configured && root.v.updateChannel > 0
                            label: updater.state === "checking" ? qsTr("Checking…")
                                 : updater.state === "available" ? qsTr("Version %1 is available").arg(updater.latestVersion)
                                 : updater.state === "upToDate" ? qsTr("You're up to date (%1)").arg(platform.version)
                                 : updater.state === "error" ? qsTr("Couldn't check for updates")
                                 : qsTr("Current version: %1").arg(platform.version)
                            description: updater.lastChecked.length > 0 ? qsTr("Last checked %1").arg(updater.lastChecked) : ""
                            Btn { visible: updater.state === "available"; text: qsTr("What's new"); variant: "outline"; compact: true; onClicked: platform.openUrl(updater.latestUrl) }
                            Btn { text: qsTr("Check now"); iconName: "refresh"; compact: true; enabled: updater.state !== "checking"; onClicked: updater.check() }
                        }

                        Label2 { text: qsTr("Help"); Layout.topMargin: 8 }
                        SettingRow {
                            label: qsTr("Report a problem")
                            description: qsTr("Collects version and log details for a bug report. Nothing is sent without you.")
                            Btn { text: qsTr("Report…"); iconName: "bug"; compact: true; onClicked: root.openReport() }
                        }
                        SettingRow {
                            label: qsTr("Detailed logging")
                            description: qsTr("Records more detail to help track down hard bugs")
                            Toggle { checked: root.v.verboseLogging; onToggled: cam.set("verboseLogging", checked) }
                        }
                        SettingRow {
                            label: qsTr("Log files")
                            divider: false
                            Btn { text: qsTr("Open folder"); iconName: "folder"; variant: "ghost"; compact: true; onClicked: platform.openLogFolder() }
                            Btn { text: qsTr("About Gimbot"); iconName: "info"; variant: "ghost"; compact: true; onClicked: root.openAbout() }
                        }
                    }

                    // ------------------------------------------------ device
                    Section {
                        sectionId: "device"
                        title: qsTr("Device")
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 14
                            Repeater {
                                model: [{ k: qsTr("Model"), v: root.connected ? cam.model : "—" },
                                        { k: qsTr("Serial number"), v: root.connected ? cam.serial : "—" },
                                        { k: qsTr("Firmware"), v: root.connected ? cam.firmware : "—" },
                                        { k: qsTr("OBSBOT SDK"), v: platform.sdkVersion },
                                        { k: qsTr("Firmware updates"), v: qsTr("Use OBSBOT Center on Windows or Mac") },
                                        { k: qsTr("Gimbot"), v: platform.version }]
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
                            label: qsTr("Guide light while adjusting the tracking area")
                            description: qsTr("The camera's light shows a pattern while you change the area")
                            Toggle { checked: root.v.guideLight; onToggled: cam.set("guideLight", checked) }
                        }
                        SettingRow {
                            label: qsTr("Reset to factory settings")
                            description: qsTr("Erases presets and every camera setting")
                            divider: false
                            Btn { text: qsTr("Reset camera…"); variant: "danger"; compact: true; enabled: root.connected; onClicked: root.confirmFactoryReset() }
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
        id: exportDialog
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("Gimbot profiles (*.json)")]
        defaultSuffix: "json"
        onAccepted: cam.exportProfiles(selectedFile)
    }
    FileDialog {
        id: importDialog
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Gimbot profiles (*.json)")]
        onAccepted: cam.importProfiles(selectedFile)
    }

    component Section: Card {
        property string sectionId: ""
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
