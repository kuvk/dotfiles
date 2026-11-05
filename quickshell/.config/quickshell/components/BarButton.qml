import QtQuick
import qs.config

// Hoverable bar item. Put content inside; it is centered and padded.
MouseArea {
    id: root

    default property alias content: row.data
    property bool active: false

    implicitWidth: row.implicitWidth + Theme.padding * 2
    implicitHeight: Theme.barHeight - 6
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    Rectangle {
        anchors.fill: parent
        radius: Theme.smallRadius
        color: root.containsMouse || root.active ? Theme.hoverBg : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6
    }
}
