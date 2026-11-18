import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../themes"

FocusScope {
    id: page
    required property var vault
    readonly property var sections: [
        {key: "all", title: "Все записи", icon: "grid"},
        {key: "favorites", title: "Избранное", icon: "star"},
        {key: "password", title: "Пароли", icon: "key"},
        {key: "note", title: "Защищённые заметки", label: "Заметки", icon: "note"},
        {key: "settings", title: "Настройки", icon: "settings"}
    ]
    readonly property bool settings: vault.section === "settings"
    readonly property var sectionInfo: sections.find(section => section.key === vault.section)
    readonly property bool canUseShortcuts: !editor.active && !generator.active
        && !appearancePicker.active && !deleteDialog.opened && !entryMenu.opened
        && !folderDialog.opened && !deleteFolderDialog.opened && !folderMenu.opened
    property var appearanceEntry: ({})

    function openFolderMenu(folder, anchor, x, y) {
        if (!folder || vault.busy)
            return
        folderMenu.folder = folder
        const point = anchor.mapToItem(folderMenu.parent, x, y)
        folderMenu.popup(Math.max(8, Math.min(point.x, folderMenu.parent.width - folderMenu.width - 8)),
                         Math.max(8, Math.min(point.y, folderMenu.parent.height - folderMenu.implicitHeight - 8)))
    }

    function showEntryMenu(entryId, item, x, y) {
        vault.select(entryId)
        if (vault.detail.id === entryId)
            entryMenu.showFor(vault.detail, item.mapToItem(entryMenu.parent, x, y))
    }

    function confirmRemoval(entryId) {
        deleteDialog.entryId = entryId
        deleteDialog.entryTitle = vault.detail.title || ""
        deleteDialog.open()
    }

    function runEntryAction(action, entryId) {
        vault.select(entryId)
        if (vault.detail.id !== entryId)
            return
        switch (action) {
        case "open":
            if (details.item)
                details.item.focusDetails()
            break
        case "username":
        case "password":
            vault.copyField(entryId, action)
            break
        case "edit": openEditor(true); break
        case "icon":
        case "color":
            appearanceEntry = {
                id: vault.detail.id, kind: vault.detail.kind, title: vault.detail.title,
                icon: vault.detail.icon, accent: vault.detail.accent
            }
            appearancePicker.sourceComponent = action === "icon" ? iconPicker : colorPicker
            appearancePicker.active = true
            appearancePicker.item.open()
            break
        case "favorite": vault.toggleFavorite(entryId); break
        case "duplicate": vault.duplicate(entryId); break
        case "delete": confirmRemoval(entryId); break
        }
    }

    function openEditor(editing) {
        editor.active = true
        editor.item.begin(editing ? vault.detail : null,
                          vault.section === "note" ? "note" : "password")
    }

    function openGenerator(useInEditor) {
        generator.active = true
        generator.item.begin(useInEditor)
    }

    function focusList() {
        if (entries.currentItem)
            entries.currentItem.forceActiveFocus()
        else
            newButton.forceActiveFocus()
    }

    function focusSearch() {
        if (settings)
            vault.setSection("all")
        search.forceActiveFocus()
        search.selectAll()
    }

    Shortcut {
        sequence: "Ctrl+N"
        enabled: page.canUseShortcuts
        onActivated: page.openEditor(false)
    }
    Shortcut {
        sequences: ["Ctrl+K", "Ctrl+F"]
        enabled: page.canUseShortcuts
        onActivated: page.focusSearch()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: rail
            objectName: "navigationRail"
            property real railWidth: page.vault.sidebarCollapsed ? 66 : page.width < 940 ? 200 : 208
            Behavior on railWidth { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
            Layout.preferredWidth: railWidth
            Layout.fillHeight: true
            color: Theme.rail
            clip: true

            Rectangle {
                anchors.right: parent.right
                height: parent.height
                width: 1
                color: Theme.line
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 13
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: page.height < 540 ? 10 : 16
                    spacing: 7
                    Mark {
                        visible: !page.vault.sidebarCollapsed
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                    }
                    Label {
                        visible: !page.vault.sidebarCollapsed
                        Layout.fillWidth: true
                        text: "Umbra Vault"
                        color: Theme.ink
                        font.pixelSize: page.width < 940 ? 14 : 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    FluentButton {
                        objectName: "toggleSidebar"
                        Layout.fillWidth: page.vault.sidebarCollapsed
                        glyph: "sidebar"
                        quiet: true
                        hint: page.vault.sidebarCollapsed ? "Развернуть панель" : "Свернуть панель"
                        accessibleLabel: hint
                        onClicked: page.vault.setSidebarCollapsed(!page.vault.sidebarCollapsed)
                    }
                }
                Repeater {
                    model: page.sections
                    FluentButton {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: page.height < 540 ? 34 : 41
                        text: page.vault.sidebarCollapsed ? "" : modelData.label || modelData.title
                        accessibleLabel: modelData.title + (selected ? " · текущий раздел" : "")
                        hint: modelData.title
                        glyph: modelData.icon
                        alignLeft: !page.vault.sidebarCollapsed
                        quiet: true
                        selected: page.vault.section === modelData.key
                        onClicked: page.vault.setSection(modelData.key)
                    }
                }
                FluentButton {
                    objectName: "newFolderButton"
                    Layout.fillWidth: true
                    text: page.vault.sidebarCollapsed ? "" : "Новая папка"
                    accessibleLabel: page.vault.sidebarCollapsed ? "Развернуть папки" : text
                    hint: accessibleLabel
                    glyph: page.vault.sidebarCollapsed ? "folder" : "plus"
                    alignLeft: !page.vault.sidebarCollapsed
                    quiet: true
                    enabled: !page.vault.busy
                    onClicked: {
                        if (page.vault.sidebarCollapsed)
                            page.vault.setSidebarCollapsed(false)
                        else
                            folderDialog.begin("", "")
                    }
                }
                ListView {
                    id: folderList
                    objectName: "folderList"
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    clip: true
                    spacing: 3
                    model: page.vault.sidebarCollapsed ? [] : page.vault.folders
                    currentIndex: model.findIndex(folder => folder.id === page.vault.currentFolder)
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain)
                    }
                    ScrollBar.vertical: ScrollBar {}
                    delegate: FluentButton {
                        id: folderButton
                        objectName: "folderSidebarItem"
                        required property var modelData
                        width: folderList.width - 8
                        height: 34
                        text: modelData.name
                        hint: modelData.name
                        glyph: "folder"
                        glyphInk: modelData.accent ? Theme.entryInk(page.vault.entryAccents, modelData.accent) : foreground
                        alignLeft: true
                        quiet: true
                        selected: page.vault.currentFolder === modelData.id
                        onClicked: page.vault.setSection("folder:" + modelData.id)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Menu
                                    || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                                page.openFolderMenu(modelData, folderButton, 12, height)
                                event.accepted = true
                            }
                        }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: point => {
                                folderButton.forceActiveFocus()
                                page.openFolderMenu(folderButton.modelData, folderButton,
                                                    point.position.x, point.position.y)
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }
                Label {
                    visible: !page.vault.sidebarCollapsed
                    Layout.leftMargin: 10
                    Layout.topMargin: page.height < 540 ? 5 : 10
                    Layout.rightMargin: 6
                    Layout.fillWidth: true
                    text: page.vault.demoMode ? "Демосессия" : page.vault.vaultFileName
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                    Accessible.name: page.vault.demoMode ? text : page.vault.vaultFilePath
                    color: Theme.muted
                    font.pixelSize: 12
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.vault.sidebarCollapsed ? 1 : 2
                    columnSpacing: 2
                    rowSpacing: 2
                    FluentButton {
                        objectName: "closeVaultButton"
                        visible: !page.vault.demoMode
                        enabled: !page.vault.busy
                        Layout.fillWidth: true
                        text: page.vault.sidebarCollapsed ? "" : "Закрыть файл"
                        horizontalPadding: 8
                        glyph: "close"
                        quiet: true
                        alignLeft: !page.vault.sidebarCollapsed
                        accessibleLabel: "Закрыть хранилище"
                        hint: page.vault.busy ? "Сохранение изменений…" : accessibleLabel
                        onClicked: page.vault.closeVault()
                    }
                    FluentButton {
                        Layout.fillWidth: page.vault.demoMode || page.vault.sidebarCollapsed
                        text: page.vault.demoMode && !page.vault.sidebarCollapsed ? "Заблокировать" : ""
                        glyph: "lock"
                        quiet: true
                        alignLeft: text !== ""
                        hint: "Заблокировать (Ctrl+L)"
                        accessibleLabel: hint
                        onClicked: page.vault.lock()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: page.width < 940 ? 17 : 26
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    Layout.fillWidth: page.settings
                    Layout.maximumWidth: page.vault.currentFolder ? (page.width < 940 ? 180 : 295) : Infinity
                    Layout.rightMargin: 10
                    text: page.sectionInfo ? page.sectionInfo.title : page.vault.currentFolderName
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    color: Theme.ink
                    font.pixelSize: page.width < 940 ? 22 : 28
                    font.weight: Font.DemiBold
                }
                FluentButton {
                    id: folderActions
                    visible: !!page.vault.currentFolder
                    enabled: !page.vault.busy
                    glyph: "more"
                    hint: "Действия с папкой"
                    accessibleLabel: hint
                    onClicked: page.openFolderMenu(
                        page.vault.folders.find(folder => folder.id === page.vault.currentFolder),
                        folderActions, 0, folderActions.height)
                }
                FluentField {
                    id: search
                    visible: !page.settings
                    Layout.fillWidth: true
                    Layout.minimumWidth: 90
                    leftPadding: 35
                    rightPadding: page.vault.query ? 34 : 12
                    placeholderText: "Поиск записей"
                    Accessible.name: "Поиск записей (Ctrl+K)"
                    text: page.vault.query
                    onTextEdited: page.vault.search(text)
                    Keys.onEscapePressed: {
                        if (text)
                            page.vault.search("")
                        else
                            page.focusList()
                    }
                    Glyph {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 17
                        height: 17
                        name: "search"
                        ink: Theme.muted
                    }
                    FluentButton {
                        visible: search.text !== ""
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "close"
                        quiet: true
                        accessibleLabel: "Очистить поиск"
                        hint: accessibleLabel
                        onClicked: {
                            page.vault.search("")
                            search.forceActiveFocus()
                        }
                    }
                }
                FluentButton {
                    text: page.width < 940 ? "" : "Генератор"
                    accessibleLabel: "Генератор паролей"
                    hint: accessibleLabel
                    glyph: "spark"
                    onClicked: page.openGenerator(false)
                }
                FluentButton {
                    objectName: "newEntryButton"
                    id: newButton
                    visible: !page.settings
                    primary: true
                    text: page.width < 940 ? "" : "Новая запись"
                    accessibleLabel: "Новая запись"
                    hint: "Новая запись (Ctrl+N)"
                    glyph: "plus"
                    onClicked: page.openEditor(false)
                }
            }

            Loader {
                id: settingsLoader
                objectName: "settingsLoader"
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: active
                active: page.settings
                sourceComponent: SettingsPage { vault: page.vault }
            }

            RowLayout {
                visible: !page.settings
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: page.vault.rows.length > 0
                        ? Math.max(187, Math.floor((page.width - 210) * 0.36))
                        : 0
                    Layout.fillWidth: page.vault.rows.length === 0
                    color: Theme.surface
                    border.color: Theme.line
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        RowLayout {
                            visible: page.vault.rows.length > 0
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            Label {
                                text: "Записи"
                                Layout.fillWidth: true
                                color: Theme.ink
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: page.vault.rows.length
                                color: Theme.muted
                            }
                        }

                        ListView {
                            id: entries
                            objectName: "entries"
                            visible: count > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3
                            model: page.settings ? [] : page.vault.rows
                            currentIndex: page.vault.rows.findIndex(row => row.id === page.vault.detail.id)
                            keyNavigationEnabled: false
                            ScrollBar.vertical: ScrollBar {}

                            delegate: ItemDelegate {
                                id: record
                                required property var modelData
                                required property int index
                                property bool chosen: page.vault.detail.id === modelData.id
                                readonly property color entryInk: Theme.entryInk(page.vault.entryAccents, modelData.accent)
                                width: ListView.view.width - 8
                                implicitHeight: Math.max(page.vault.compactList ? 44 : 57,
                                                         implicitContentHeight + topPadding + bottomPadding)
                                horizontalPadding: 10
                                verticalPadding: page.vault.compactList ? 4 : 8
                                hoverEnabled: true
                                focusPolicy: Qt.StrongFocus
                                Accessible.name: modelData.title + (chosen ? " · выбрано" : "")
                                onClicked: page.vault.select(modelData.id)
                                Keys.onReturnPressed: clicked()
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Menu
                                            || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                                        page.showEntryMenu(modelData.id, record, 16, height)
                                        event.accepted = true
                                    }
                                }
                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: point => {
                                        record.forceActiveFocus()
                                        page.showEntryMenu(record.modelData.id, record, point.position.x, point.position.y)
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (index + 1 < entries.count)
                                        page.moveSelection(index + 1)
                                }
                                Keys.onUpPressed: {
                                    if (index > 0)
                                        page.moveSelection(index - 1)
                                }
                                background: Rectangle {
                                    radius: 8
                                    color: record.down || record.chosen ? Theme.tint
                                        : record.hovered ? Theme.hover : "transparent"
                                    border.width: record.activeFocus ? 2 : 0
                                    border.color: Theme.accent
                                    Behavior on color { ColorAnimation { duration: Theme.duration } }
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: record.chosen && !record.activeFocus
                                        width: 2
                                        height: 16
                                        radius: 1
                                        color: record.entryInk
                                    }
                                }
                                contentItem: RowLayout {
                                    spacing: page.vault.compactList ? 7 : 8
                                    EntryBadge {
                                        Layout.preferredWidth: page.vault.compactList ? 27 : 32
                                        Layout.preferredHeight: Layout.preferredWidth
                                        kind: record.modelData.kind
                                        iconId: record.modelData.icon
                                        ink: record.entryInk
                                        symbolSize: page.vault.compactList ? 15 : 17
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: page.vault.compactList ? 0 : 2
                                        Label {
                                            Layout.fillWidth: true
                                            text: record.modelData.title
                                            color: Theme.ink
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            textFormat: Text.PlainText
                                        }
                                        Label {
                                            visible: text !== ""
                                            Layout.fillWidth: true
                                            text: record.modelData.subtitle
                                            color: Theme.muted
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            textFormat: Text.PlainText
                                        }
                                    }
                                    Glyph {
                                        visible: record.modelData.favorite
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        name: "star"
                                    }
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: page.vault.rows.length === 0
                            ColumnLayout {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 30, 440)
                                spacing: 11
                                Mark { Layout.alignment: Qt.AlignHCenter }
                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: page.vault.query ? "Совпадений нет"
                                        : page.vault.currentFolder ? "Папка пока пустая"
                                        : page.vault.total === 0 ? "Хранилище пока пустое"
                                        : page.vault.section === "favorites" ? "В избранном пока пусто"
                                        : "В этом разделе пока пусто"
                                    color: Theme.ink
                                    font.pixelSize: 21
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                }
                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: page.vault.query ? "Измените запрос или очистите поиск."
                                        : page.vault.section === "favorites" && page.vault.total
                                        ? "Нажмите звезду в карточке, чтобы добавить запись."
                                        : "Добавьте пароль или заметку."
                                    color: Theme.muted
                                    wrapMode: Text.WordWrap
                                }
                                FluentButton {
                                    visible: !!page.vault.query || page.vault.section !== "favorites"
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 7
                                    text: page.vault.query ? "Очистить поиск" : "Новая запись"
                                    glyph: page.vault.query ? "close" : "plus"
                                    onClicked: {
                                        if (page.vault.query)
                                            page.vault.search("")
                                        else
                                            page.openEditor(false)
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: details
                    objectName: "detailsLoader"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: active ? 290 : 0
                    visible: active
                    active: !page.settings && !!page.vault.detail.id
                    sourceComponent: DetailsPage {
                        vault: page.vault
                        onEdit: page.openEditor(true)
                        onRequestRemoval: page.confirmRemoval(page.vault.detail.id)
                        onRequestMenu: item => page.showEntryMenu(page.vault.detail.id, item, item.width, item.height)
                    }
                }
            }
        }
    }

    function moveSelection(index) {
        vault.select(vault.rows[index].id)
        entries.positionViewAtIndex(index, ListView.Contain)
        focusList()
    }

    Component.onCompleted: Qt.callLater(focusList)

    EntryMenu {
        id: entryMenu
        objectName: "entryMenu"
        onChosen: (action, entryId) => Qt.callLater(page.runEntryAction, action, entryId)
    }
    Loader {
        id: appearancePicker
        objectName: "appearancePicker"
        active: false
    }
    Component {
        id: iconPicker
        IconPicker {
            vault: page.vault
            entry: page.appearanceEntry
            onClosed: {
                appearancePicker.active = false
                page.focusList()
            }
        }
    }
    Component {
        id: colorPicker
        ColorPicker {
            vault: page.vault
            entry: page.appearanceEntry
            folderMode: !!entry.isFolder
            onClosed: {
                appearancePicker.active = false
                page.focusList()
            }
        }
    }
    Loader {
        id: editor
        objectName: "editorLoader"
        active: false
        sourceComponent: EntryDialog {
            vault: page.vault
            onRequestGenerator: page.openGenerator(true)
            onClosed: {
                editor.active = false
                page.focusList()
            }
        }
    }
    Loader {
        id: generator
        objectName: "generatorLoader"
        active: false
        sourceComponent: GeneratorDialog {
            vault: page.vault
            onUsePassword: password => {
                if (editor.active)
                    editor.item.setPassword(password)
            }
            onClosed: {
                generator.active = false
                if (!editor.active)
                    page.focusList()
            }
        }
    }
    Menu {
        id: folderMenu
        objectName: "folderMenu"
        property var folder: ({})
        parent: Overlay.overlay
        width: 233
        margins: 8
        padding: 5
        background: Rectangle {
            radius: 10
            color: Theme.surface
            border.color: Theme.line
        }
        FluentMenuItem {
            objectName: "renameFolderAction"
            text: "Переименовать папку"
            glyph: "edit"
            onTriggered: {
                const folder = folderMenu.folder
                Qt.callLater(folderDialog.begin, folder.id, folder.name)
            }
        }
        FluentMenuItem {
            objectName: "colorFolderAction"
            text: "Изменить цвет папки"
            glyph: "palette"
            onTriggered: {
                const folder = folderMenu.folder
                Qt.callLater(() => {
                    page.appearanceEntry = {id: folder.id, title: folder.name, accent: folder.accent,
                                            icon: "folder", kind: "note", isFolder: true}
                    appearancePicker.sourceComponent = colorPicker
                    appearancePicker.active = true
                    appearancePicker.item.open()
                })
            }
        }
        FluentMenuItem {
            text: "Удалить папку…"
            glyph: "trash"
            danger: true
            onTriggered: {
                deleteFolderDialog.folder = folderMenu.folder
                Qt.callLater(deleteFolderDialog.open)
            }
        }
    }
    FluentDialog {
        id: folderDialog
        objectName: "folderDialog"
        property string folderId
        title: folderId ? "Переименовать папку" : "Новая папка"
        width: Math.min(page.width - 32, 420)
        onOpened: folderName.forceActiveFocus()

        function begin(id, name) {
            folderId = id
            folderName.text = name
            folderError.text = ""
            open()
            folderName.selectAll()
        }

        function submit() {
            folderError.text = page.vault.saveFolder(folderId, folderName.text)
            if (!folderError.text)
                close()
        }

        contentItem: ColumnLayout {
            FluentField {
                id: folderName
                objectName: "folderName"
                Layout.fillWidth: true
                placeholderText: "Название папки"
                Accessible.name: placeholderText
                maximumLength: 80
                onAccepted: folderDialog.submit()
            }
            Label {
                id: folderError
                visible: text !== ""
                Layout.fillWidth: true
                color: Theme.danger
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.AlertMessage
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                FluentButton { text: "Отмена"; onClicked: folderDialog.close() }
                FluentButton {
                    objectName: "saveFolder"
                    primary: true
                    text: folderDialog.folderId ? "Сохранить" : "Создать"
                    onClicked: folderDialog.submit()
                }
            }
        }
    }
    FluentDialog {
        id: deleteFolderDialog
        property var folder: ({})
        title: "Удалить папку?"
        width: Math.min(page.width - 32, 420)
        onOpened: cancelFolderDelete.forceActiveFocus()
        contentItem: ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: "Записи из папки «" + (deleteFolderDialog.folder.name || "") + "» останутся во всех записях."
                textFormat: Text.PlainText
                color: Theme.muted
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                FluentButton {
                    id: cancelFolderDelete
                    text: "Отмена"
                    onClicked: deleteFolderDialog.close()
                }
                FluentButton {
                    danger: true
                    text: "Удалить папку"
                    onClicked: {
                        page.vault.removeFolder(deleteFolderDialog.folder.id)
                        deleteFolderDialog.close()
                    }
                }
            }
        }
    }
    FluentDialog {
        id: deleteDialog
        objectName: "deleteDialog"
        property string entryId
        property string entryTitle
        title: "Удалить запись?"
        width: Math.min(page.width - 32, 420)
        onOpened: cancelDelete.forceActiveFocus()
        onClosed: page.focusList()
        ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: "Запись «" + deleteDialog.entryTitle + "» будет удалена."
                textFormat: Text.PlainText
                color: Theme.muted
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                FluentButton {
                    id: cancelDelete
                    text: "Отмена"
                    onClicked: deleteDialog.close()
                }
                FluentButton {
                    text: "Удалить"
                    danger: true
                    onClicked: {
                        page.vault.remove(deleteDialog.entryId)
                        deleteDialog.close()
                    }
                }
            }
        }
    }
}
