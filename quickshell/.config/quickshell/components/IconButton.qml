import QtQuick
import qs.config

MouseArea {
    id: root

    property alias icon: label.text
    property color color: Theme.text
    property int size: 30

    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: root.size / 2
        color: root.containsMouse ? Theme.hoverBg : "transparent"
    }

    Icon {
        id: label

        anchors.centerIn: parent
        color: root.color
    }
}
