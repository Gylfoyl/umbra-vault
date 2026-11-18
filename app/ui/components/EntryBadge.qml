import QtQuick
import "../themes"

Rectangle {
    id: badge
    property string iconId: ""
    property string kind: "password"
    property color ink: Theme.accent
    property int symbolSize: 19
    readonly property string symbol: iconId || (kind === "note" ? "note" : "key")

    implicitWidth: 36
    implicitHeight: implicitWidth
    radius: 9
    color: Qt.tint(Theme.raised, Qt.alpha(ink, Theme.dark ? 0.16 : 0.13))
    border.color: Qt.tint(Theme.line, Qt.alpha(ink, 0.20))
    Accessible.ignored: true

    Image {
        anchors.centerIn: parent
        width: badge.symbolSize
        height: width
        sourceSize.width: 72
        sourceSize.height: 72
        source: "image://entryicons/" + badge.symbol + "/" + badge.ink.toString().slice(-6)
        cache: !badge.symbol.startsWith("custom-")
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }
}
