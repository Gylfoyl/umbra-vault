import QtQuick
import QtQuick.Controls
import "../themes"

TextField {
    id: control
    implicitHeight: 40
    selectByMouse: true
    color: Theme.ink
    placeholderTextColor: Theme.muted
    selectionColor: Theme.tint
    selectedTextColor: Theme.ink
    leftPadding: 12
    rightPadding: 12

    background: Rectangle {
        radius: 8
        color: Theme.raised
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.duration } }
    }
}
