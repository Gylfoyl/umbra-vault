import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../themes"

Rectangle {
    id: pane
    required property var vault
    readonly property var entry: vault.detail
    readonly property bool isNote: entry.kind === "note"
    property bool revealed: false
    property string password: ""
    signal edit()
    signal requestRemoval()
    signal requestMenu(Item anchorItem)
    readonly property color entryInk: Theme.entryInk(vault.entryAccents, entry.accent)

    function focusDetails() {
        moreButton.forceActiveFocus()
    }

    color: Theme.surface
    border.color: Theme.line
    radius: 12

    Connections {
        target: pane.vault
        function onDetailChanged() {
            pane.revealed = false
            pane.password = ""
            scroller.contentItem.contentY = 0
        }
    }

    ScrollView {
        id: scroller
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actions.top
        anchors.margins: 2
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroller.availableWidth
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.bottomMargin: 7
                spacing: 10
                EntryBadge {
                    Layout.preferredWidth: 43
                    Layout.preferredHeight: 43
                    iconId: pane.entry.icon || ""
                    kind: pane.isNote ? "note" : "password"
                    symbolSize: 22
                    ink: pane.entryInk
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.fillWidth: true
                        text: pane.entry.title || ""
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        color: Theme.ink
                        textFormat: Text.PlainText
                    }
                    Label {
                        text: pane.isNote ? "Защищённая заметка" : "Пароль"
                        color: Theme.muted
                    }
                }
                FluentButton {
                    glyph: "star"
                    quiet: true
                    selected: !!pane.entry.favorite
                    accessibleLabel: selected ? "Убрать из избранного" : "Добавить в избранное"
                    hint: accessibleLabel
                    onClicked: pane.vault.toggleFavorite(pane.entry.id)
                }
                FluentButton {
                    id: moreButton
                    objectName: "entryActionsButton"
                    glyph: "more"
                    hint: "Действия с записью"
                    accessibleLabel: hint
                    quiet: true
                    onClicked: pane.requestMenu(moreButton)
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                implicitHeight: 1
                color: Theme.line
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 14

                FieldRow {
                    Layout.fillWidth: true
                    visible: !pane.isNote
                    title: "Логин"
                    value: pane.entry.username || "—"
                    copyable: !!pane.entry.username
                    onCopy: pane.vault.copyField(pane.entry.id, "username")
                }
                FieldRow {
                    Layout.fillWidth: true
                    visible: !pane.isNote
                    title: "Пароль"
                    secret: !!pane.entry.hasPassword
                    revealed: pane.revealed
                    value: !secret ? "—" : revealed ? pane.password : "••••••••••••"
                    copyable: secret
                    onCopy: pane.vault.copyField(pane.entry.id, "password")
                    onToggleReveal: {
                        pane.revealed = !pane.revealed
                        pane.password = pane.revealed ? pane.vault.reveal(pane.entry.id) : ""
                    }
                }
                FieldRow {
                    Layout.fillWidth: true
                    visible: !pane.isNote
                    title: "Сайт"
                    value: pane.entry.url || "—"
                    copyable: !!pane.entry.url
                    onCopy: pane.vault.copyField(pane.entry.id, "url")
                }
                ColumnLayout {
                    visible: pane.isNote || !!pane.entry.notes
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: "Заметки"; color: Theme.muted }
                        FluentButton {
                            visible: !!pane.entry.notes
                            glyph: "copy"
                            quiet: true
                            accessibleLabel: "Скопировать заметки"
                            hint: accessibleLabel
                            onClicked: pane.vault.copyField(pane.entry.id, "notes")
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: pane.entry.notes || "—"
                        textFormat: Text.PlainText
                        color: Theme.ink
                        wrapMode: Text.Wrap
                    }
                }
                Label {
                    visible: !!pane.entry.tags && pane.entry.tags.length > 0
                    Layout.fillWidth: true
                    text: visible ? "Теги · " + pane.entry.tags.join(" · ") : ""
                    textFormat: Text.PlainText
                    color: pane.entryInk
                    wrapMode: Text.Wrap
                }
                Item { implicitHeight: 4 }
            }
        }
    }

    RowLayout {
        id: actions
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        FluentButton {
            glyph: "trash"
            hint: "Удалить запись"
            accessibleLabel: hint
            danger: true
            quiet: true
            onClicked: pane.requestRemoval()
        }
        FluentButton {
            text: "Изменить"
            glyph: "edit"
            onClicked: pane.edit()
        }
    }
}
