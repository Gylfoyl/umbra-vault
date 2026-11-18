import QtQuick
import QtQuick.Controls
import "../themes"

TextArea {
    id: control
    implicitHeight: 76
    padding: 11
    color: Theme.ink
    selectByMouse: true
    wrapMode: TextEdit.Wrap
    selectionColor: Theme.tint
    selectedTextColor: Theme.ink

    background: Rectangle {
        radius: 8
        color: Theme.raised
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.line
    }
}
