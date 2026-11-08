import QtQuick
import qs.config

MouseArea {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.selection

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 6
            height: width
            radius: width / 2
            color: root.checked ? Theme.background : Theme.subtext

            Behavior on x {
                NumberAnimation {
                    duration: Theme.animDuration
                }
            }
        }
    }
}
