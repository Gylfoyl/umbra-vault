import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../themes"

FluentDialog {
    id: dialog
    required property var vault
    property string entryId: ""
    readonly property bool isNote: kindPicker.currentIndex === 1
    signal requestGenerator()
    title: entryId ? "Изменить запись" : "Новая запись"
    width: Math.min(parent.width - 32, 535)
    height: Math.min(parent.height - 24, isNote ? 380 : 467)
    topPadding: 15
    bottomPadding: 12

    function begin(entry, defaultKind) {
        entryId = entry ? entry.id : ""
        folderPicker.currentIndex = Math.max(0, folderPicker.findById(
            entry ? entry.folder : vault.currentFolder))
        kindPicker.currentIndex = (entry ? entry.kind : defaultKind) === "note" ? 1 : 0
        entryTitle.text = entry ? entry.title : ""
        username.text = entry ? entry.username : ""
        password.text = entry && entry.hasPassword ? vault.reveal(entry.id) : ""
        website.text = entry ? entry.url : ""
        notes.text = entry ? entry.notes : ""
        tags.text = entry ? entry.tags.join(", ") : ""
        error.text = ""
        open()
    }

    function setPassword(value) {
        password.text = value
        password.forceActiveFocus()
    }

    function commit() {
        error.text = vault.save({
            id: entryId, kind: isNote ? "note" : "password", title: entryTitle.text,
            username: username.text, password: password.text, url: website.text,
            notes: notes.text, tags: tags.text, folder: folderPicker.currentValue || ""
        })
        if (!error.text && !vault.busy)
            close()
        else if (error.text)
            entryTitle.forceActiveFocus()
    }

    onOpened: entryTitle.forceActiveFocus()
    Connections {
        target: dialog.vault
        function onEntrySaveFinished(message) {
            if (message)
                error.text = message
            else
                dialog.close()
        }
    }
    contentItem: ScrollView {
        id: scroll
        contentWidth: availableWidth
        rightPadding: contentHeight > availableHeight ? 10 : 0
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: contentHeight > availableHeight ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
        clip: true
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: "Название"; color: Theme.muted }
                    FluentField {
                        id: entryTitle
                        objectName: "entryTitle"
                        Layout.fillWidth: true
                        Accessible.name: "Название"
                        maximumLength: 240
                        onTextEdited: error.text = ""
                    }
                }
                ColumnLayout {
                    spacing: 4
                    Label { text: "Тип записи"; color: Theme.muted }
                    FluentCombo {
                        id: kindPicker
                        Accessible.name: "Тип записи"
                        focusPolicy: Qt.StrongFocus
                        enabled: !dialog.entryId
                        model: ["Пароль", "Защищённая заметка"]
                    }
                }
                ColumnLayout {
                    visible: folderPicker.count > 1
                    spacing: 4
                    Label { text: "Папка"; color: Theme.muted }
                    FluentCombo {
                        id: folderPicker
                        objectName: "entryFolderPicker"
                        Layout.preferredWidth: 140
                        Layout.maximumWidth: 140
                        Accessible.name: "Папка записи"
                        model: [{id: "", name: "Без папки"}, ...dialog.vault.folders]
                        textRole: "name"
                        valueRole: "id"

                        function findById(id) {
                            return model.findIndex(folder => folder.id === id)
                        }
                    }
                }
            }
            RowLayout {
                visible: !dialog.isNote
                Layout.fillWidth: true
                spacing: 12
                uniformCellSizes: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: "Логин"; color: Theme.muted }
                    FluentField {
                        id: username
                        Layout.fillWidth: true
                        Accessible.name: "Логин"
                        maximumLength: 512
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: "Сайт"; color: Theme.muted }
                    FluentField {
                        id: website
                        Layout.fillWidth: true
                        Accessible.name: "Сайт"
                        placeholderText: "https://"
                        maximumLength: 2048
                    }
                }
            }
            Label { visible: !dialog.isNote; text: "Пароль"; color: Theme.muted }
            RowLayout {
                visible: !dialog.isNote
                Layout.fillWidth: true
                FluentField {
                    id: password
                    objectName: "entryPassword"
                    Layout.fillWidth: true
                    Accessible.name: "Пароль"
                    echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                }
                FluentButton {
                    id: showPassword
                    glyph: checked ? "hide" : "eye"
                    checkable: true
                    accessibleLabel: checked ? "Скрыть пароль" : "Показать пароль"
                    hint: accessibleLabel
                }
                FluentButton {
                    glyph: "spark"
                    accessibleLabel: "Сгенерировать пароль"
                    hint: accessibleLabel
                    onClicked: dialog.requestGenerator()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label { text: "Заметки"; color: Theme.muted }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: dialog.isNote ? 110 : 70
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        FluentArea { id: notes; Accessible.name: "Заметки" }
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 146
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignTop
                    spacing: 4
                    Label { text: "Теги через запятую"; color: Theme.muted }
                    FluentField {
                        id: tags
                        Layout.fillWidth: true
                        Accessible.name: "Теги через запятую"
                        maximumLength: 512
                    }
                }
            }
        }
    }

    footer: ColumnLayout {
        spacing: 4
        Label {
            id: error
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.fillWidth: true
            visible: text !== ""
            color: Theme.danger
            Accessible.role: Accessible.AlertMessage
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.topMargin: 8
            Item { Layout.fillWidth: true }
            FluentButton { text: "Отмена"; onClicked: dialog.close() }
            FluentButton {
                objectName: "saveEntry"
                text: dialog.vault.busy ? "Сохранение…" : "Сохранить"
                enabled: !dialog.vault.busy
                primary: true
                onClicked: dialog.commit()
            }
        }
    }
}
