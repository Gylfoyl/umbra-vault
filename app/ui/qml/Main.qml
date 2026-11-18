import QtQuick
import QtQuick.Controls
import "../components"
import "../themes"

ApplicationWindow {
    id: window
    required property var vault

    width: Math.min(1160, Math.max(minimumWidth, Screen.desktopAvailableWidth - 32))
    height: Math.min(740, Math.max(minimumHeight, Screen.desktopAvailableHeight - 66))
    minimumWidth: 800
    minimumHeight: 480
    visible: true
    title: "Umbra Vault"
    color: Theme.canvas

    palette.window: Theme.canvas
    palette.windowText: Theme.ink
    palette.text: Theme.ink
    palette.button: Theme.raised
    palette.buttonText: Theme.ink
    palette.base: Theme.surface
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.accentText

    Binding {
        target: Theme
        property: "selectedTheme"
        value: window.vault.theme
    }
    Binding {
        target: Theme
        property: "reducedMotion"
        value: window.vault.reducedMotion
    }

    Loader {
        id: workspace
        objectName: "workspaceLoader"
        anchors.fill: parent
        active: window.vault.route === "workspace"
        focus: active
        sourceComponent: Workspace { vault: window.vault }
    }
    Loader {
        anchors.fill: parent
        active: window.vault.route !== "workspace"
        focus: active
        sourceComponent: Gateway { vault: window.vault }
    }

    Shortcut {
        sequence: "Ctrl+L"
        enabled: workspace.active
        onActivated: window.vault.lock()
    }
    Connections {
        target: window.vault
        function onFeedback(message) {
            toastLabel.text = message
            toastTimer.restart()
        }
        function onRouteChanged() {
            toastTimer.stop()
            toastLabel.text = ""
        }
    }
    Timer {
        id: toastTimer
        interval: 3200
        onTriggered: toastLabel.text = ""
    }
    Rectangle {
        z: 1
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        width: toastLabel.implicitWidth + 28
        height: 38
        radius: 9
        color: Theme.surface
        border.color: Theme.line
        visible: toastLabel.text !== ""
        Label {
            id: toastLabel
            anchors.centerIn: parent
            color: Theme.ink
            Accessible.role: Accessible.AlertMessage
        }
    }
}
