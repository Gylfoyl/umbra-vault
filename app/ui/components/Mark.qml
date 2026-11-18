import QtQuick

Item {
    implicitWidth: 42
    implicitHeight: 42
    Accessible.ignored: true

    Image {
        anchors.fill: parent
        source: "../assets/umbra.png"
        sourceSize.width: 192
        sourceSize.height: 192
        fillMode: Image.PreserveAspectFit
        mipmap: true
        Accessible.ignored: true
    }
}
