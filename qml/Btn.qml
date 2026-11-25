import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Button in one of several looks: primary, secondary, ghost, outline, danger.
Button {
    id: control
    property string variant: "secondary"
    property string iconName: ""
    property bool pill: false
    property bool compact: false
    property string tip: ""       // hover explanation
    property string shortcut: ""  // shown in the hover hint

    readonly property color fg: !enabled ? Theme.textFaint
                              : variant === "primary" ? Theme.accentInk
                              : variant === "danger" ? Theme.danger
                              : variant === "outline" ? Theme.accentText
                              : variant === "ghost" ? Theme.textMuted
                              : Theme.text

    implicitHeight: compact ? 32 : 40
    leftPadding: text.length > 0 ? (compact ? 12 : 16) : 0
    rightPadding: leftPadding
    implicitWidth: text.length > 0 ? implicitContentWidth + leftPadding + rightPadding : implicitHeight
    font.family: Theme.font
    font.pixelSize: compact ? Theme.small + 1 : Theme.fontSize
    font.weight: variant === "primary" ? Font.DemiBold : Font.Medium
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text.length > 0 ? text : tip
    Accessible.description: tip
    scale: down ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast } }

    contentItem: RowLayout {
        spacing: 8
        Icon {
            visible: control.iconName.length > 0
            name: control.iconName
            color: control.fg
            size: control.compact ? 15 : 16
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: control.text.length > 0 ? 0 : (control.implicitHeight - size) / 2
        }
        Text {
            visible: control.text.length > 0
            text: control.text
            font: control.font
            color: control.fg
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Tip {
        visible: control.hovered && (control.tip.length > 0 || control.shortcut.length > 0)
        text: control.tip
        shortcut: control.shortcut
    }

    background: Rectangle {
        radius: control.pill ? height / 2 : Theme.radiusSm + 2
        color: {
            if (control.variant === "primary")
                return control.down ? Qt.darker(Theme.accent, 1.1) : control.hovered ? Qt.lighter(Theme.accent, 1.06) : Theme.accent
            if (control.variant === "ghost" || control.variant === "outline" || control.variant === "danger")
                return control.down || control.hovered ? Theme.hover : "transparent"
            return control.down ? Theme.sunken : control.hovered ? Qt.lighter(Theme.surface2, Theme.dark ? 1.15 : 0.98) : Theme.surface2
        }
        border.width: control.variant === "primary" || control.variant === "ghost" ? 0 : 1
        border.color: control.variant === "outline" ? Theme.accent
                    : control.variant === "danger" ? Theme.danger : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Rectangle { // keyboard focus ring
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            visible: control.visualFocus
        }
    }
}
