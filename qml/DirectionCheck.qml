// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts

// Checks that Up moves the camera up and Right moves it right, and fixes it
// if not. Gimbot follows OBSBOT's documented directions, so this should
// pass; it's here in case a camera or firmware differs.
Sheet {
    id: root
    title: qsTr("Check movement directions")
    iconName: "move"
    maxWidth: 480
    property int step: 0 // 0 intro, 1 tilt, 2 pan, 3 done
    property bool flippedTilt: false
    property bool flippedPan: false
    onOpened: { step = 0; flippedTilt = false; flippedPan = false }

    function answer(correct) {
        if (step === 1) {
            if (!correct) { cam.set("invertTilt", !cam.values.invertTilt); flippedTilt = true }
            step = 2
            cam.nudge(0, 1)
        } else if (step === 2) {
            if (!correct) { cam.set("invertPan", !cam.values.invertPan); flippedPan = true }
            step = 3
        }
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        lineHeight: 1.2
        text: [
            qsTr("The camera will move a little up, then a little right. Watch the picture and say which way it went. Tracking turns off while you check."),
            qsTr("The camera just tilted. Did the picture move <b>up</b>?"),
            qsTr("The camera just turned. Did the picture move <b>right</b>?"),
            root.flippedTilt || root.flippedPan
                ? qsTr("Fixed. %1 now go the right way. You can change this later under Settings › Movement.")
                    .arg(root.flippedTilt && root.flippedPan ? qsTr("Up/down and left/right") : root.flippedTilt ? qsTr("Up and down") : qsTr("Left and right"))
                : qsTr("All good: the directions were already right.")
        ][root.step]
        textFormat: Text.StyledText
    }

    buttons: [
        Btn { text: qsTr("Move it again"); variant: "ghost"; visible: root.step === 1 || root.step === 2
              onClicked: root.step === 1 ? cam.nudge(1, 0) : cam.nudge(0, 1) },
        Item { Layout.fillWidth: true },
        Btn { text: qsTr("Cancel"); variant: "ghost"; visible: root.step === 0; onClicked: root.close() },
        Btn { text: qsTr("Start"); variant: "primary"; visible: root.step === 0; enabled: cam.connected && !cam.values.asleep
              onClicked: { root.step = 1; cam.nudge(1, 0) } },
        Btn { text: qsTr("No, the other way"); variant: "outline"; visible: root.step === 1 || root.step === 2; onClicked: root.answer(false) },
        Btn { text: qsTr("Yes"); variant: "primary"; visible: root.step === 1 || root.step === 2; onClicked: root.answer(true) },
        Btn { text: qsTr("Done"); variant: "primary"; visible: root.step === 3; onClicked: root.close() }
    ]
}
