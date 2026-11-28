// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Gimbot

// Tracking on/off, framing, field of view, and (under More) style, auto zoom
// and quick toggles for gestures, voice commands and the tracking area.
Card {
    id: root
    title: qsTr("Tracking")
    active: root.on // corner brackets while tracking
    moreKey: "moreTracking"
    signal openArea()
    signal openVoice()

    readonly property var v: Cam.values
    readonly property bool on: v.mode !== 0
    // The mode the switch shows/uses: the current one, or the one it will turn on.
    readonly property int shownMode: on ? v.mode : v.lastTrackingMode
    readonly property var modeNames: ["", qsTr("Group"), qsTr("Person"), qsTr("Hand"), qsTr("Whiteboard"), qsTr("Desk")]
    readonly property bool anyVoice: v.voice0 || v.voice1 || v.voice2 || v.voice3 || v.voice4 || v.voice5 || v.voice6
    readonly property bool usable: Cam.connected && !v.asleep

    subtitle: !Cam.connected ? "" : on ? qsTr("On · %1").arg(modeNames[v.mode] || "")
                                       : Cam.trackingPaused ? qsTr("Paused because you moved the camera")
                                       : qsTr("Off · turns on as %1").arg(modeNames[shownMode] || qsTr("Person"))
    note: v.asleep ? qsTr("The camera is asleep. Wake it to use tracking.") : ""
    noteAction: v.asleep ? qsTr("Wake") : ""
    onNoteActivated: Cam.set("asleep", false)

    headerExtras: [
        Btn {
            visible: Cam.trackingPaused
            enabled: Cam.connected && !Cam.values.asleep
            text: qsTr("Resume")
            iconName: "play"
            variant: "outline"
            compact: true
            pill: true
            tip: qsTr("Turn tracking back on in %1 mode").arg(root.modeNames[root.shownMode] || "")
            shortcut: "Ctrl T"
            onClicked: Cam.resumeTracking()
        },
        Toggle {
            id: master
            checked: root.on
            enabled: root.usable
            accessibleName: qsTr("Tracking")
            tip: root.on ? qsTr("Turn tracking off (Ctrl+T)") : qsTr("Turn tracking on in %1 mode (Ctrl+T)").arg(root.modeNames[root.shownMode] || "")
            onToggled: Cam.setTracking(checked)
        }
    ]

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true
        Caption { text: qsTr("Framing") }
        Segmented {
            Layout.fillWidth: true
            stretch: true
            options: [qsTr("Full body"), qsTr("Upper body"), qsTr("Close-up")]
            tips: [qsTr("Keep your whole body in the picture"), qsTr("Head and shoulders down to the waist"), qsTr("Head and shoulders")]
            accessibleName: qsTr("Framing")
            currentIndex: root.shownMode === 2 ? root.v.framing : -1
            enabled: root.usable && root.shownMode === 2
            opacity: enabled ? 1 : 0.5
            onActivated: (i) => Cam.set("framing", i)
        }
        Text {
            visible: root.usable && root.shownMode !== 2
            text: qsTr("Framing is for Person tracking. Choose Person on the picture to use it.")
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.small
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true
        Caption { text: qsTr("Field of view") }
        Segmented {
            Layout.fillWidth: true
            stretch: true
            options: [qsTr("Wide 86°"), qsTr("Medium 78°"), qsTr("Narrow 65°")]
            tips: [qsTr("Shows the most of the room"), qsTr("A little tighter"), qsTr("Tightest view, less background")]
            accessibleName: qsTr("Field of view")
            currentIndex: root.v.fov
            enabled: root.usable
            onActivated: (i) => Cam.set("fov", i)
        }
        Text {
            text: qsTr("Changes what every app sees, not just this preview.")
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.small
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    more: [
        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            Caption { text: qsTr("Style") }
            Segmented {
                Layout.fillWidth: true
                stretch: true
                options: [qsTr("Standard"), qsTr("Headroom"), qsTr("Motion")]
                tips: [qsTr("Balanced framing"), qsTr("Leaves more space above your head"), qsTr("Follows fast movement more closely")]
                accessibleName: qsTr("Tracking style")
                currentIndex: root.v.trackStyle
                enabled: root.usable
                onActivated: (i) => Cam.set("trackStyle", i)
            }
        },
        QuickToggle {
            label: qsTr("Zoom in automatically")
            description: qsTr("Keeps you a steady size in the picture while tracking")
            checked: root.v.autoZoom
            onToggled: (on) => Cam.set("autoZoom", on)
        },
        QuickToggle {
            label: qsTr("Resume tracking by itself")
            description: qsTr("After you move the camera by hand, tracking comes back %1 seconds after you stop").arg(root.v.autoResumeSeconds)
            checked: root.v.autoResume
            needsCamera: false
            onToggled: (on) => Cam.set("autoResume", on)
        },
        QuickToggle {
            label: qsTr("Gestures")
            description: qsTr("Raise a palm to select yourself, make an L to zoom")
            checked: root.v.gestureSelect || root.v.gestureZoom
            onToggled: (on) => { Cam.set("gestureSelect", on); Cam.set("gestureZoom", on) }
        },
        QuickToggle {
            label: qsTr("Voice commands")
            description: qsTr("“Hi Tiny”, “Track me”, “Zoom in”…")
            checked: root.anyVoice
            actionText: qsTr("Choose…")
            onAction: root.openVoice()
            onToggled: (on) => { for (let i = 0; i < 7; ++i) Cam.set("voice" + i, on) }
        },
        QuickToggle {
            label: qsTr("Tracking area")
            description: qsTr("Only track inside a set area")
            checked: root.v.zoneEnabled
            actionText: qsTr("Edit…")
            onAction: root.openArea()
            onToggled: (on) => Cam.set("zoneEnabled", on)
        },
        Btn {
            text: qsTr("Reset tracking settings")
            iconName: "refresh"
            variant: "ghost"
            compact: true
            enabled: Cam.connected
            tip: qsTr("Upper body, standard style, wide view, auto zoom on. You can undo this.")
            onClicked: Cam.resetTracking()
        }
    ]

    component Caption: Text {
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.small
    }
    component QuickToggle: Item {
        id: qt
        property string label: ""
        property string description: ""
        property bool checked: false
        property bool needsCamera: true
        property string actionText: ""
        signal toggled(bool on)
        signal action()
        Layout.fillWidth: true
        implicitHeight: Math.max(44, texts.implicitHeight + 8)
        ColumnLayout {
            id: texts
            anchors.left: parent.left
            anchors.right: controls.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { text: qt.label; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Text { text: qt.description; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small; Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: text.length > 0 }
        }
        Row {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Btn { visible: qt.actionText.length > 0; text: qt.actionText; variant: "ghost"; compact: true; onClicked: qt.action() }
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: qt.checked
                enabled: !qt.needsCamera || root.usable
                accessibleName: qt.label
                onToggled: qt.toggled(checked)
            }
        }
    }
}
