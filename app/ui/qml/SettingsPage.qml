import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../themes"

ScrollView {
    id: page
    required property var vault
    contentWidth: availableWidth
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    ColumnLayout {
        width: page.availableWidth
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: appearance.implicitHeight + 34
            color: Theme.surface
            border.color: Theme.line
            radius: 12
            ColumnLayout {
                id: appearance
                anchors.fill: parent
                anchors.margins: 17
                spacing: 12

                Label {
                    Layout.bottomMargin: 2
                    text: "Оформление"
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    color: Theme.ink
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "Цветовая тема"; color: Theme.ink }
                    FluentCombo {
                        objectName: "themePicker"
                        readonly property var themes: ["umbra", "midnight", "snow", "forest", "graphite"]
                        Accessible.name: "Цветовая тема"
                        model: ["Тёмная тема", "Midnight", "Snow", "Forest", "Graphite"]
                        currentIndex: themes.indexOf(page.vault.theme)
                        onActivated: index => page.vault.setTheme(themes[index])
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: "Плотность списка"; color: Theme.ink }
                    FluentCombo {
                        objectName: "densityPicker"
                        model: ["Стандартная", "Компактная"]
                        currentIndex: page.vault.compactList ? 1 : 0
                        Accessible.name: "Плотность списка"
                        onActivated: index => page.vault.setCompactList(index === 1)
                    }
                }
                FluentSwitch {
                    text: "Уменьшить движение"
                    checked: page.vault.reducedMotion
                    onToggled: page.vault.setReducedMotion(checked)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: security.implicitHeight + 34
            color: Theme.surface
            border.color: Theme.line
            radius: 12
            ColumnLayout {
                id: security
                anchors.fill: parent
                anchors.margins: 17
                spacing: 11

                Label {
                    text: "Безопасность"
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    color: Theme.ink
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: "Блокировка при бездействии"
                        color: Theme.ink
                        wrapMode: Text.WordWrap
                    }
                    FluentCombo {
                        readonly property var minutes: [0, 1, 5, 10, 15]
                        Accessible.name: "Блокировка при бездействии"
                        model: ["Выключена", "1 минута", "5 минут", "10 минут", "15 минут"]
                        currentIndex: minutes.indexOf(page.vault.idleMinutes)
                        onActivated: index => page.vault.setIdleMinutes(minutes[index])
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Скопированные кнопкой приложения пароли и заметки очищаются из буфера через 20 секунд, если буфер остался прежним."
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: about.implicitHeight + 34
            color: Theme.surface
            border.color: Theme.line
            radius: 12
            ColumnLayout {
                id: about
                anchors.fill: parent
                anchors.margins: 17
                spacing: 8

                Label {
                    text: "О приложении"
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    color: Theme.ink
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Mark {}
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            text: "Umbra Vault " + page.vault.appVersion
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                            color: Theme.ink
                        }
                        Label { text: "Разработчик · Umbra"; color: Theme.muted }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Лицензия Umbra Vault ожидает согласования."
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    text: "Python · PSF License\nQt, PySide6 и Shiboken6 · LGPL v3\ncryptography · Apache 2.0 / BSD 3-Clause\nargon2-cffi · MIT"
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
