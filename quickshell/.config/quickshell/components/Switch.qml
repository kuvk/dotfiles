import QtQuick
import qs.config

MouseArea {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    cursorShape: Qt.PointingHandCursor
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.highlight : Theme.surface1

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 6
            height: width
            radius: width / 2
            color: root.checked ? Theme.base : Theme.overlay2

            Behavior on x {
                NumberAnimation {
                    duration: Theme.animDuration
                }
            }
        }
    }
}
