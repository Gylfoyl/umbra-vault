import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Button {
    id: control
    property bool primary: false
    property bool selected: false
    property bool quiet: false
    property bool danger: false
    property string glyph: ""
    property color glyphInk: foreground
    property string hint: ""
    property string accessibleLabel: text
    property bool alignLeft: false

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 36
    horizontalPadding: text ? 12 : 9
    Accessible.name: accessibleLabel
    ToolTip.text: hint
    ToolTip.delay: 650
    ToolTip.visible: hint !== "" && hovered

    readonly property color foreground: !enabled ? Theme.muted : primary
        ? Theme.accentText : danger ? Theme.danger : selected ? Theme.accent : Theme.ink

    background: Rectangle {
        radius: 8
        color: control.down ? (control.primary ? Qt.darker(Theme.accent, 1.15) : Theme.tint)
            : control.primary && control.enabled ? Theme.accent
            : control.selected ? Theme.tint
            : control.hovered && control.enabled ? Theme.hover
            : control.quiet ? "transparent" : Theme.surface
        border.width: control.visualFocus ? 2 : control.quiet || control.primary ? 0 : 1
        border.color: control.visualFocus ? Theme.accent : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.duration } }
    }

    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        RowLayout {
            id: content
            x: control.alignLeft ? 0 : Math.max(0, (parent.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width)
            spacing: 8
            Glyph {
                visible: control.glyph !== ""
                Layout.preferredWidth: 17
                Layout.preferredHeight: 17
                name: control.glyph
                ink: control.glyphInk
            }
            Label {
                visible: control.text !== ""
                Layout.fillWidth: true
                text: control.text
                color: control.foreground
                font.weight: control.primary || control.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }
}
