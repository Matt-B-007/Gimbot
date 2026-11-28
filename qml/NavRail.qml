// SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Gimbot

// The strip down the left of the window: the logo, the two pages, and Help.
Rectangle {
    id: root
    property string page: "studio"
    signal pageRequested(string page)
    signal openTour()
    signal openShortcuts()
    signal openPalette()
    signal openDirectionCheck()
    signal openWhatsNew()
    signal openReport()
    signal openAbout()

    implicitWidth: 76
    color: Theme.sidebar
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 6

        Rectangle { // the logo: hull square, accent edge, purple mark
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 14
            implicitWidth: 44
            implicitHeight: 44
            radius: 12
            color: "#0c1016"
            border.color: Qt.rgba(Theme.brand.r, Theme.brand.g, Theme.brand.b, 0.35)
            Image {
                anchors.centerIn: parent
                source: "icons/gimbot.svg"
                sourceSize: Qt.size(30, 30)
                width: 30
                height: 30
            }
            Accessible.ignored: true
        }

        Repeater {
            model: [
                { page: "studio", label: qsTr("Studio"), icon: "camera" },
                { page: "settings", label: qsTr("Settings"), icon: "gear" }
            ]
            delegate: AbstractButton {
                id: navButton
                required property var modelData
                readonly property bool current: root.page === navButton.modelData.page
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 60
                implicitHeight: 58
                focusPolicy: Qt.TabFocus
                Accessible.name: navButton.modelData.label
                Accessible.role: Accessible.PageTab
                onClicked: root.pageRequested(navButton.modelData.page)
                background: Rectangle {
                    radius: 12
                    color: navButton.current ? Theme.accentSoft : navButton.hovered ? Theme.hover : "transparent"
                    border.width: navButton.visualFocus ? 2 : 0
                    border.color: Theme.accent
                }
                contentItem: ColumnLayout {
                    spacing: 4
                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        name: navButton.modelData.icon
                        size: 22
                        color: navButton.current ? Theme.accentText : Theme.textMuted
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: navButton.modelData.label
                        color: navButton.current ? Theme.accentText : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        IconBtn {
            id: helpButton
            Layout.alignment: Qt.AlignHCenter
            iconName: "help"
            tip: qsTr("Help")
            onClicked: helpMenu.popup(helpButton, helpButton.width + 6, 0)
        }
    }

    StyledMenu {
        id: helpMenu
        MenuEntry { text: qsTr("Show the tour"); onTriggered: root.openTour() }
        MenuEntry { text: qsTr("Keyboard shortcuts"); onTriggered: root.openShortcuts() }
        MenuEntry { text: qsTr("Search all commands"); onTriggered: root.openPalette() }
        MenuEntry { text: qsTr("Check camera directions"); onTriggered: root.openDirectionCheck() }
        MenuLine {}
        MenuEntry { text: qsTr("What's new"); enabled: Platform.repoUrl.length > 0; onTriggered: root.openWhatsNew() }
        MenuEntry { text: qsTr("Report a problem…"); onTriggered: root.openReport() }
        MenuEntry { text: qsTr("About Gimbot"); onTriggered: root.openAbout() }
    }
}
