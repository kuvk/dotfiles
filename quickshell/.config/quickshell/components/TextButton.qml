import QtQuick
import qs.config

MouseArea {
    id: root

    property alias text: label.text
    property bool primary: false

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 32
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: Theme.smallRadius
        color: root.primary ? (root.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : (root.containsMouse ? Theme.selection : Theme.lighterBackground)
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        color: root.primary ? Theme.background : Theme.foreground
        font.weight: Font.DemiBold
    }
}
