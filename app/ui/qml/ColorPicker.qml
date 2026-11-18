import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../themes"

FluentDialog {
    id: picker
    required property var vault
    required property var entry
    property bool folderMode: false
    property string chosen: entry.accent || ""
    title: folderMode ? "Цвет папки" : "Акцент записи"
    width: Math.min(parent.width - 32, 402)
    onOpened: defaults.forceActiveFocus()

    contentItem: ColumnLayout {
        spacing: 13

        RowLayout {
            Layout.fillWidth: true
            EntryBadge {
                iconId: picker.entry.icon || ""
                kind: picker.entry.kind
                ink: Theme.entryInk(picker.vault.entryAccents, picker.chosen)
            }
            Label {
                Layout.fillWidth: true
                text: picker.entry.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.ink
                font.weight: Font.DemiBold
            }
            FluentButton {
                id: defaults
                text: "Из темы"
                selected: !picker.chosen
                onClicked: picker.chosen = ""
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 6
            rowSpacing: 7
            columnSpacing: 7

            Repeater {
                model: picker.vault.entryAccents
                FluentButton {
                    id: swatch
                    required property var modelData
                    Layout.fillWidth: true
                    implicitWidth: 38
                    implicitHeight: 40
                    hint: modelData.label
                    accessibleLabel: hint + (selected ? " · выбрано" : "")
                    selected: picker.chosen === modelData.id
                    onClicked: picker.chosen = modelData.id
                    contentItem: Item {
                        Rectangle {
                            anchors.centerIn: parent
                            width: 17
                            height: 17
                            radius: width / 2
                            color: Theme.dark ? swatch.modelData.dark : swatch.modelData.light
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            FluentButton { text: "Отмена"; onClicked: picker.close() }
            FluentButton {
                objectName: "applyColor"
                text: "Применить"
                primary: true
                onClicked: {
                    if (picker.folderMode)
                        picker.vault.setFolderAccent(picker.entry.id, picker.chosen)
                    else
                        picker.vault.setEntryAccent(picker.entry.id, picker.chosen)
                    picker.close()
                }
            }
        }
    }
}
