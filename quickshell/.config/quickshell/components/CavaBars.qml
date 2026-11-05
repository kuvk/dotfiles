import QtQuick
import qs.config
import qs.services

// Audio visualizer: `count` bars filling the width, fixed height. When
// silent (or not playing) the bottoms of the bars stay visible.
Item {
    id: root

    property int count: Cava.bars
    property real spacing: 3
    property real minHeight: 3
    property color color: Theme.sky

    readonly property real barWidth: Math.max(1, (width - spacing * (count - 1)) / count)

    implicitHeight: 36

    Row {
        anchors.bottom: parent.bottom
        spacing: root.spacing

        Repeater {
            model: root.count

            Rectangle {
                required property int index

                anchors.bottom: parent.bottom
                width: root.barWidth
                height: Math.max(root.minHeight, (Cava.values[Math.floor(index * Cava.values.length / root.count)] ?? 0) * root.height)
                radius: Math.min(2, root.barWidth / 2)
                color: root.color
                opacity: Cava.values.length > 0 ? 1 : 0.5

                Behavior on height {
                    NumberAnimation {
                        duration: 60
                    }
                }
            }
        }
    }
}
