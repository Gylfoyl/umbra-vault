import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

ColumnLayout {
    id: row
    property string title
    property string value
    property bool secret: false
    property bool revealed: false
    property bool copyable: true
    signal copy()
    signal toggleReveal()

    spacing: 6
    Label {
        text: row.title
        color: Theme.muted
        font.pixelSize: 12
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 42
        radius: 8
        color: Theme.raised
        border.color: Theme.line

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 4
            spacing: 3

            Label {
                Layout.fillWidth: true
                text: row.value
                color: Theme.ink
                font.family: row.secret ? "Cascadia Mono" : Qt.application.font.family
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            FluentButton {
                visible: row.secret
                glyph: row.revealed ? "hide" : "eye"
                quiet: true
                accessibleLabel: row.revealed ? "Скрыть пароль" : "Показать пароль"
                hint: accessibleLabel
                onClicked: row.toggleReveal()
            }
            FluentButton {
                visible: row.copyable
                quiet: true
                glyph: "copy"
                accessibleLabel: "Скопировать · " + row.title
                hint: accessibleLabel
                onClicked: row.copy()
            }
        }
    }
}
