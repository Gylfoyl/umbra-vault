import QtQuick
import QtQuick.Controls
import "../themes"

ComboBox {
    id: control
    implicitHeight: 40
    implicitWidth: Math.max(146, implicitContentWidth + 40)
    implicitContentWidthPolicy: ComboBox.WidestTextWhenCompleted
    leftPadding: 12
    rightPadding: 32
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        radius: 8
        color: control.down ? Theme.tint : Theme.raised
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.accent : Theme.line
    }
    indicator: Glyph {
        x: control.width - width - 10
        anchors.verticalCenter: parent.verticalCenter
        width: 15
        height: 15
        name: "chevron"
        ink: Theme.muted
    }
    contentItem: Label {
        text: control.displayText
        color: control.enabled ? Theme.ink : Theme.muted
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
