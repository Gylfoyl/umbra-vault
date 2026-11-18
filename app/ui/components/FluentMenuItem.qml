import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

MenuItem {
    id: control
    property string glyph
    property bool danger: false
    readonly property color foreground: !enabled ? Theme.muted : danger ? Theme.danger : Theme.ink

    implicitHeight: 35
    leftPadding: 10
    rightPadding: 12
    opacity: enabled ? 1 : 0.52
    contentItem: RowLayout {
        spacing: 9
        Glyph {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            name: control.glyph
            ink: control.foreground
        }
        Label {
            Layout.fillWidth: true
            text: control.text
            color: control.foreground
            textFormat: Text.PlainText
        }
    }
    background: Rectangle {
        radius: 7
        color: control.down ? Theme.tint : control.highlighted ? Theme.hover : "transparent"
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.accent
    }
}
