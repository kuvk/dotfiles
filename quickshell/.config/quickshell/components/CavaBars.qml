import QtQuick
import qs.config
import qs.services

// Audio visualizer bars from Cava.values
Row {
    id: root

    property int barWidth: 3
    property real maxHeight: 14
    property color color: Theme.sky

    spacing: 1
    height: maxHeight

    Repeater {
        model: Cava.values

        Rectangle {
            required property real modelData

            anchors.bottom: parent.bottom
            width: root.barWidth
            height: Math.max(2, modelData * root.maxHeight)
            radius: root.barWidth / 2
            color: root.color

            Behavior on height {
                NumberAnimation {
                    duration: 60
                }
            }
        }
    }
}
