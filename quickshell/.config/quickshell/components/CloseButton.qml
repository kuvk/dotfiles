import QtQuick
import qs.config

// Small X for the top right corner of windows: no background, the X turns
// the accent color on hover. Hidden unless Settings > Windows > Window
// buttons is on.
MouseArea {
    id: root

    visible: Config.windowButtons
    implicitWidth: 28
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Icon {
        anchors.centerIn: parent
        text: Icons.close
        color: root.containsMouse ? Theme.accent : Theme.subtext0

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }
    }
}
