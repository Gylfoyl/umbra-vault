import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../themes"

FluentDialog {
    id: dialog
    required property var vault
    property bool canApply: false
    readonly property bool valid: lower.checked || upper.checked || digits.checked || symbols.checked
    signal usePassword(string password)
    width: Math.min(parent.width - 32, 448)
    title: "Генератор паролей"

    function begin(apply) {
        canApply = apply
        refresh()
        open()
    }

    function refresh() {
        output.text = valid
            ? vault.generate(length.value, lower.checked, upper.checked, digits.checked, symbols.checked)
            : ""
        output.cursorPosition = 0
    }

    onOpened: length.forceActiveFocus()
    contentItem: ColumnLayout {
        spacing: 11
        RowLayout {
            Layout.fillWidth: true
            FluentField {
                id: output
                objectName: "generatedPassword"
                Layout.fillWidth: true
                readOnly: true
                selectByMouse: false
                activeFocusOnTab: false
                font.family: "Cascadia Mono"
                Accessible.name: "Сгенерированный пароль"
            }
            FluentButton {
                glyph: "copy"
                enabled: output.text !== ""
                hint: "Скопировать на 20 секунд"
                accessibleLabel: hint
                onClicked: dialog.vault.copyGenerated(output.text)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: "Длина, от 8 до 128"
                color: Theme.muted
            }
            SpinBox {
                id: length
                from: 8
                to: 128
                value: 20
                editable: true
                Accessible.name: "Длина пароля"
                onValueModified: dialog.refresh()
            }
        }
        GridLayout {
            columns: 2
            Layout.fillWidth: true
            CheckBox { id: lower; text: "Строчные"; checked: true; onToggled: dialog.refresh() }
            CheckBox { id: upper; text: "Прописные"; checked: true; onToggled: dialog.refresh() }
            CheckBox { id: digits; text: "Цифры"; checked: true; onToggled: dialog.refresh() }
            CheckBox { id: symbols; text: "Спецсимволы"; checked: true; onToggled: dialog.refresh() }
        }
        Label {
            Layout.fillWidth: true
            visible: !dialog.valid
            text: "Выберите хотя бы один набор символов."
            color: Theme.danger
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.AlertMessage
        }
        RowLayout {
            Layout.fillWidth: true
            FluentButton {
                objectName: "regenerate"
                text: "Обновить"
                glyph: "spark"
                enabled: dialog.valid
                onClicked: dialog.refresh()
            }
            Item { Layout.fillWidth: true }
            FluentButton { text: "Закрыть"; onClicked: dialog.close() }
            FluentButton {
                objectName: "applyPassword"
                visible: dialog.canApply
                enabled: output.text !== ""
                primary: true
                text: "Вставить"
                onClicked: {
                    dialog.usePassword(output.text)
                    dialog.close()
                }
            }
        }
    }
}
