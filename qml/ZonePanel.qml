// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Gimbot

// Zone tracking settings, beside the picture while the zone is drawn on it.
Card {
    id: root
    title: qsTr("Zone tracking")
    active: true
    signal done()
    signal moreSettings()

    function across(yaw) {
        const s = Math.round(Cam.screenFromYaw(yaw))
        return s < 0 ? qsTr("%1° left").arg(-s) : s > 0 ? qsTr("%1° right").arg(s) : qsTr("straight ahead")
    }
    function upDown(pitch) { // the SDK counts pitch down as positive
        const p = Math.round(pitch)
        return p < 0 ? qsTr("%1° up").arg(-p) : p > 0 ? qsTr("%1° down").arg(p) : qsTr("level")
    }
    readonly property real leftYaw: { void (Cam.values.mirrored); return Cam.screenFromYaw(Cam.values.zoneYawMin) < Cam.screenFromYaw(Cam.values.zoneYawMax) ? Cam.values.zoneYawMin : Cam.values.zoneYawMax }
    readonly property real rightYaw: Cam.values.zoneYawMin + Cam.values.zoneYawMax - leftYaw

    headerExtras: Toggle {
        checked: Cam.values.zoneEnabled
        Accessible.name: qsTr("Zone tracking")
        enabled: Cam.connected
        onToggled: Cam.set("zoneEnabled", checked)
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("The camera follows you, but never turns past the edges of the area. Good for keeping a doorway or a second screen out of shot.")
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            // A fixed list; each cell works out its own value, so the cells
            // aren't remade on every camera update.
            model: [qsTr("Left edge"), qsTr("Right edge"), qsTr("Top edge"), qsTr("Bottom edge")]
            delegate: Rectangle {
                id: cell
                required property int index
                required property string modelData
                readonly property string value: index === 0 ? root.across(root.leftYaw)
                                              : index === 1 ? root.across(root.rightYaw)
                                              : index === 2 ? root.upDown(Math.min(Cam.values.zonePitchMin, Cam.values.zonePitchMax))
                                              : root.upDown(Math.max(Cam.values.zonePitchMin, Cam.values.zonePitchMax))
                Layout.fillWidth: true
                implicitHeight: cellCol.implicitHeight + 20
                radius: Theme.radiusSm + 2
                color: Theme.surface2
                ColumnLayout {
                    id: cellCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    Text { text: cell.modelData; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.small }
                    Text { text: cell.value; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: qsTr("Pick who to follow"); color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1 }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Follows whoever is in the area, without you choosing")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.small
            }
        }
        Toggle {
            checked: Cam.values.zoneAutoSelect
            Accessible.name: qsTr("Pick who to follow")
            enabled: Cam.connected
            onToggled: Cam.set("zoneAutoSelect", checked)
        }
    }
    Btn {
        variant: "ghost"
        compact: true
        text: qsTr("More zone settings")
        onClicked: root.moreSettings()
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Btn {
            Layout.fillWidth: true
            text: qsTr("Reset area")
            enabled: Cam.connected
            tip: qsTr("Back to the camera's whole range, the same as Reset area in Settings")
            onClicked: Cam.resetZone()
        }
        Btn {
            Layout.fillWidth: true
            variant: "primary"
            glow: true
            text: qsTr("Done")
            onClicked: root.done()
        }
    }
}
