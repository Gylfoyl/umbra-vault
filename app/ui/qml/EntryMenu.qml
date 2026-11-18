import QtQuick
import QtQuick.Controls
import "../components"
import "../themes"

Menu {
    id: menu
    property var entry: ({})
    signal chosen(string action, string entryId)
    parent: Overlay.overlay
    popupType: Popup.Item
    width: 245
    margins: 8
    padding: 5

    function showFor(value, point) {
        entry = {
            id: value.id, username: !!value.username, hasPassword: value.hasPassword,
            favorite: value.favorite
        }
        const right = parent.width - width - margins
        const bottom = parent.height - implicitHeight - margins
        popup(Math.max(margins, Math.min(point.x, right)),
              Math.max(margins, Math.min(point.y, bottom)))
    }

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.line
        radius: 10
    }

    FluentMenuItem { text: "Открыть"; glyph: "arrow"; onTriggered: menu.chosen("open", menu.entry.id) }
    FluentMenuItem {
        text: "Копировать логин"
        glyph: "copy"
        enabled: !!menu.entry.username
        onTriggered: menu.chosen("username", menu.entry.id)
    }
    FluentMenuItem {
        text: "Копировать пароль"
        glyph: "copy"
        enabled: !!menu.entry.hasPassword
        onTriggered: menu.chosen("password", menu.entry.id)
    }
    FluentMenuItem { text: "Изменить"; glyph: "edit"; onTriggered: menu.chosen("edit", menu.entry.id) }
    FluentMenuItem { text: "Изменить иконку"; glyph: "picture"; onTriggered: menu.chosen("icon", menu.entry.id) }
    FluentMenuItem { text: "Изменить цвет"; glyph: "palette"; onTriggered: menu.chosen("color", menu.entry.id) }
    FluentMenuItem {
        text: menu.entry.favorite ? "Убрать из избранного" : "Добавить в избранное"
        glyph: "star"
        onTriggered: menu.chosen("favorite", menu.entry.id)
    }
    FluentMenuItem { text: "Дублировать"; glyph: "copy"; onTriggered: menu.chosen("duplicate", menu.entry.id) }
    MenuSeparator {
        contentItem: Rectangle { implicitHeight: 1; color: Theme.line }
    }
    FluentMenuItem {
        text: "Удалить…"
        glyph: "trash"
        danger: true
        onTriggered: menu.chosen("delete", menu.entry.id)
    }
}
