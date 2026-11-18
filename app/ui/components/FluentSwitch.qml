import QtQuick
import QtQuick.Controls
import "../themes"

Switch {
    id: control
    spacing: 9
    padding: 0
    focusPolicy: Qt.StrongFocus

    indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 22
        anchors.verticalCenter: parent.verticalCenter
        radius: 11
        color: control.checked ? Theme.accent : Theme.raised
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus || control.checked ? Theme.accent : Theme.muted

        Rectangle {
            x: control.checked ? 21 : 5
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: control.checked ? Theme.accentText : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.duration } }
        }
    }
    contentItem: Label {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        verticalAlignment: Text.AlignVCenter
        color: Theme.ink
    }
}
