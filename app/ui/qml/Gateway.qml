import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../components"
import "../themes"

FocusScope {
    id: screen
    required property var vault
    readonly property bool creating: vault.route === "setup"
    readonly property bool choosing: vault.route === "welcome" || vault.route === "vaultPicker"

    FileDialog {
        id: newVaultFile
        objectName: "newVaultFile"
        title: "Куда сохранить хранилище"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "umbra"
        nameFilters: ["Хранилище Umbra Vault (*.umbra)"]
        onAccepted: screen.vault.chooseVault(selectedFile, true)
    }

    FileDialog {
        id: existingVaultFile
        objectName: "existingVaultFile"
        title: "Открыть хранилище"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Хранилище Umbra Vault (*.umbra)", "Все файлы (*)"]
        onAccepted: screen.vault.chooseVault(selectedFile, false)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(screen.width * 0.44)
            color: Theme.rail
            clip: true

            Label {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 31
                text: "Umbra Vault"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: Theme.ink
            }

            Item {
                anchors.centerIn: parent
                width: Math.min(parent.width - 44, 360)
                height: width
                Repeater {
                    model: [1.0, 0.81, 0.62, 0.43]
                    Rectangle {
                        required property real modelData
                        anchors.centerIn: parent
                        width: parent.width * modelData
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: Theme.line
                    }
                }
                Rectangle {
                    width: 8
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    x: parent.width * 0.69 - width / 2
                    y: parent.height * 0.14 - height / 2
                }
                Mark {
                    anchors.centerIn: parent
                    width: 84
                    height: 84
                }
            }

            Label {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 31
                text: screen.vault.demoMode ? "Локальная демосессия" : "Локальное хранилище"
                color: Theme.muted
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackLayout {
                id: pages
                anchors.centerIn: parent
                width: Math.min(parent.width - 54, 370)
                currentIndex: screen.choosing ? 0 : 1

                ColumnLayout {
                    spacing: 12
                    Label {
                        Layout.fillWidth: true
                        text: "Ваше хранилище"
                        font.pixelSize: 37
                        font.weight: Font.DemiBold
                        color: Theme.ink
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 17
                        text: screen.vault.demoMode
                            ? "Попробуйте поиск, заметки и генератор паролей на вымышленных данных."
                            : "Создайте один зашифрованный файл или откройте существующее хранилище."
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                        lineHeight: 1.18
                    }
                    FluentButton {
                        id: openSample
                        visible: screen.vault.demoMode
                        objectName: "openSample"
                        Layout.fillWidth: true
                        implicitHeight: 43
                        primary: true
                        text: screen.vault.hasSample ? "Открыть демосессию" : "Открыть образец"
                        glyph: "vault"
                        onClicked: screen.vault.openSample()
                    }
                    FluentButton {
                        id: newDemo
                        visible: screen.vault.demoMode
                        objectName: "newDemo"
                        Layout.fillWidth: true
                        implicitHeight: 43
                        text: "Создать пустую демосессию"
                        glyph: "plus"
                        onClicked: {
                            if (screen.vault.hasSample)
                                replaceDemo.open()
                            else
                                screen.vault.newDemo()
                        }
                    }
                    FluentButton {
                        id: createFileButton
                        objectName: "selectNewVault"
                        visible: !screen.vault.demoMode
                        Layout.fillWidth: true
                        implicitHeight: 43
                        glyph: "plus"
                        primary: true
                        text: "Создать хранилище…"
                        onClicked: newVaultFile.open()
                    }
                    FluentButton {
                        objectName: "selectExistingVault"
                        visible: !screen.vault.demoMode
                        Layout.fillWidth: true
                        implicitHeight: 43
                        glyph: "folder"
                        text: "Открыть файл…"
                        onClicked: existingVaultFile.open()
                    }
                    FluentButton {
                        objectName: "openRecentVault"
                        visible: !screen.vault.demoMode && !!screen.vault.recentVaultName
                        Layout.fillWidth: true
                        alignLeft: true
                        glyph: "vault"
                        quiet: true
                        text: "Открыть " + screen.vault.recentVaultName
                        hint: text
                        onClicked: screen.vault.openRecentVault()
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: screen.vault.operationError
                        color: Theme.danger
                        wrapMode: Text.WordWrap
                        Accessible.role: Accessible.AlertMessage
                    }
                }

                ColumnLayout {
                    spacing: 12
                    Label {
                        Layout.fillWidth: true
                        text: screen.creating ? "Создать хранилище"
                            : screen.vault.route === "locked" ? "Хранилище заблокировано" : "Разблокировать"
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                        color: Theme.ink
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: !screen.vault.demoMode && !!text
                        text: screen.vault.vaultFileName
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                        color: Theme.accent
                        Accessible.name: screen.vault.vaultFilePath
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 9
                        text: screen.vault.demoMode ? "Код демосессии — " + screen.vault.demoCode
                            : screen.creating
                              ? "Задайте мастер-пароль. Восстановить его нельзя."
                              : "Введите мастер-пароль для доступа к записям."
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        FluentField {
                            id: code
                            objectName: "demoCode"
                            Layout.fillWidth: true
                            placeholderText: screen.vault.demoMode ? "Код разблокировки" : "Мастер-пароль"
                            Accessible.name: placeholderText
                            enabled: !screen.vault.busy
                            echoMode: show.checked ? TextInput.Normal : TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                            onAccepted: {
                                if (screen.creating)
                                    confirmation.forceActiveFocus()
                                else if (unlockButton.enabled)
                                    unlockButton.clicked()
                            }
                            onTextEdited: {
                                error.text = ""
                                screen.vault.clearOperationError()
                            }
                        }
                        FluentButton {
                            id: show
                            checkable: true
                            glyph: checked ? "hide" : "eye"
                            accessibleLabel: checked ? "Скрыть пароль" : "Показать пароль"
                            hint: accessibleLabel
                        }
                    }
                    FluentField {
                        id: confirmation
                        objectName: "masterConfirmation"
                        Layout.fillWidth: true
                        visible: screen.creating
                        enabled: !screen.vault.busy
                        placeholderText: "Повторите мастер-пароль"
                        Accessible.name: placeholderText
                        echoMode: show.checked ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        onTextEdited: screen.vault.clearOperationError()
                        onAccepted: if (unlockButton.enabled) unlockButton.clicked()
                    }
                    Label {
                        id: error
                        Layout.fillWidth: true
                        visible: text !== ""
                        wrapMode: Text.WordWrap
                        color: Theme.danger
                        Accessible.role: Accessible.AlertMessage
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: screen.vault.operationError
                        wrapMode: Text.WordWrap
                        color: Theme.danger
                        Accessible.role: Accessible.AlertMessage
                    }
                    FluentButton {
                        id: unlockButton
                        objectName: "unlock"
                        Layout.fillWidth: true
                        implicitHeight: 43
                        primary: true
                        enabled: !screen.vault.busy && code.length > 0 && (!screen.creating || confirmation.length > 0)
                        text: screen.vault.busy ? "Подождите…"
                            : screen.creating ? "Создать хранилище" : "Разблокировать"
                        glyph: "lock"
                        onClicked: {
                            if (!screen.vault.demoMode) {
                                if (screen.creating)
                                    screen.vault.createVault(code.text, confirmation.text)
                                else
                                    screen.vault.unlock(code.text)
                                if (screen.vault.busy) {
                                    code.clear()
                                    confirmation.clear()
                                    show.checked = false
                                }
                                return
                            }
                            if (!screen.vault.unlock(code.text)) {
                                error.text = "Неверный код демосессии."
                                code.forceActiveFocus()
                                code.selectAll()
                            }
                        }
                    }
                    FluentButton {
                        text: screen.vault.demoMode ? "На главный экран" : "Выбрать другой файл"
                        enabled: !screen.vault.busy
                        glyph: "arrow"
                        quiet: true
                        onClicked: screen.vault.demoMode ? screen.vault.welcome() : screen.vault.closeVault()
                    }
                }
            }

            Keys.onEscapePressed: {
                if (screen.vault.route === "unlock")
                    screen.vault.welcome()
                else if (!screen.choosing && !screen.vault.busy)
                    screen.vault.closeVault()
            }
        }
    }

    FluentDialog {
        id: replaceDemo
        title: "Создать новую демосессию?"
        width: Math.min(screen.width - 32, 420)
        ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: "Записи текущей демосессии будут удалены."
                color: Theme.muted
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                FluentButton { text: "Отмена"; onClicked: replaceDemo.close() }
                FluentButton {
                    text: "Создать"
                    primary: true
                    onClicked: {
                        replaceDemo.close()
                        screen.vault.newDemo()
                    }
                }
            }
        }
    }

    function resetFocus() {
        code.clear()
        confirmation.clear()
        error.text = ""
        show.checked = false
        if (vault.route === "welcome")
            openSample.forceActiveFocus()
        else if (vault.route === "vaultPicker")
            createFileButton.forceActiveFocus()
        else
            code.forceActiveFocus()
    }
    Component.onCompleted: Qt.callLater(resetFocus)
    Connections {
        target: screen.vault
        function onRouteChanged() {
            if (screen.vault.route !== "workspace")
                Qt.callLater(screen.resetFocus)
        }
        function onBusyChanged() {
            if (!screen.vault.busy)
                code.forceActiveFocus()
        }
    }
}
