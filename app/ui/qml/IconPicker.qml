import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../components"
import "../themes"

FluentDialog {
    id: picker
    required property var vault
    required property var entry
    property string chosen: entry.icon || ""
    property string errorText: ""
    readonly property var categories: ["Все", ...new Set(vault.iconCatalog.map(icon => icon.category))]
    readonly property var filtered: {
        const query = search.text.trim().toLocaleLowerCase()
        const group = categories[category.currentIndex]
        const matches = vault.iconCatalog.filter(icon =>
            (group === "Все" || group === icon.category)
            && (icon.label + " " + icon.keywords).toLocaleLowerCase().includes(query))
        if (group === "Все" && !query)
            return [{id: "", label: "Авто"}, ...matches]
        return matches
    }
    width: Math.min(parent.width - 32, 568)
    height: Math.min(parent.height - 24, 483)
    title: "Выбор иконки"

    onOpened: search.forceActiveFocus()
    onClosed: vault.discardIconPreview()

    FileDialog {
        id: files
        title: "Выбрать локальную иконку"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Изображения (*.png *.svg)"]
        onAccepted: {
            if (!picker.visible)
                return
            const result = picker.vault.importIconPreview(selectedFile)
            picker.errorText = result.error || ""
            if (result.icon)
                picker.chosen = result.icon
        }
    }

    contentItem: ColumnLayout {
        spacing: 9
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            FluentField {
                id: search
                objectName: "iconSearch"
                Layout.fillWidth: true
                placeholderText: "Поиск иконок"
                Accessible.name: placeholderText
                Keys.onDownPressed: {
                    if (grid.count) {
                        grid.currentIndex = 0
                        grid.forceActiveFocus()
                    }
                }
            }
            FluentCombo {
                id: category
                model: picker.categories
                Accessible.name: "Категория иконок"
            }
        }
        GridView {
            id: grid
            objectName: "iconGrid"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            activeFocusOnTab: true
            Accessible.name: "Каталог иконок"
            model: picker.filtered
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 88)))
            cellHeight: 63
            ScrollBar.vertical: ScrollBar {}
            Keys.onReturnPressed: if (currentItem) picker.chosen = currentItem.modelData.id
            Keys.onSpacePressed: if (currentItem) picker.chosen = currentItem.modelData.id

            delegate: Button {
                id: tile
                required property var modelData
                width: grid.cellWidth - 6
                height: grid.cellHeight - 6
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                Accessible.name: modelData.label
                Accessible.selected: picker.chosen === modelData.id
                onClicked: picker.chosen = modelData.id
                background: Rectangle {
                    radius: 8
                    color: picker.chosen === tile.modelData.id ? Theme.tint
                        : tile.hovered ? Theme.hover : "transparent"
                    border.width: tile.GridView.isCurrentItem && grid.activeFocus ? 2 : 1
                    border.color: tile.GridView.isCurrentItem && grid.activeFocus ? Theme.accent : Theme.line
                }
                contentItem: ColumnLayout {
                    spacing: 1
                    EntryBadge {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 25
                        Layout.preferredHeight: 25
                        iconId: tile.modelData.id
                        kind: picker.entry.kind
                        symbolSize: 16
                        border.width: 0
                        color: "transparent"
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.label
                        color: Theme.ink
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: "Иконки не найдены"
                color: Theme.muted
            }
        }
        Label {
            visible: picker.errorText !== ""
            Layout.fillWidth: true
            text: picker.errorText
            wrapMode: Text.WordWrap
            color: Theme.danger
            Accessible.role: Accessible.AlertMessage
        }
        RowLayout {
            Layout.fillWidth: true
            EntryBadge {
                iconId: picker.chosen
                kind: picker.entry.kind
                ink: Theme.entryInk(picker.vault.entryAccents, picker.entry.accent)
            }
            Label {
                text: "Предпросмотр"
                visible: picker.width >= 490
                color: Theme.muted
            }
            Item { Layout.fillWidth: true }
            FluentButton {
                text: "Открыть файл…"
                glyph: "picture"
                hint: "PNG или статический SVG, до 512 КиБ"
                onClicked: files.open()
            }
            FluentButton { text: "Отмена"; onClicked: picker.close() }
            FluentButton {
                objectName: "applyIcon"
                text: "Применить"
                primary: true
                onClicked: {
                    picker.vault.setEntryIcon(picker.entry.id, picker.chosen)
                    picker.close()
                }
            }
        }
    }
}
