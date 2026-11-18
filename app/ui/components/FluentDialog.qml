import QtQuick
import QtQuick.Controls
import "../themes"

Dialog {
    parent: Overlay.overlay
    modal: true
    focus: true
    anchors.centerIn: parent
    padding: 20
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle { color: Theme.overlay }
    background: Rectangle {
        color: Theme.surface
        border.color: Theme.line
        radius: 12
    }
    header: Label {
        visible: text !== ""
        text: parent.title
        padding: 20
        bottomPadding: 0
        font.pixelSize: 23
        font.weight: Font.DemiBold
        color: Theme.ink
    }
}
