import QtQuick
import qs.config

// Marks on a slider or bar with fixed values (the text size, the keyboard light): a thin
// vertical line at each of `count` points from start to end, reaching a little above and below
// the track; in the track's color, and in the fill's once the level reaches it. Nothing for
// fewer than two points.
Item {
    id: root

    property int count: 0
    // 0..1
    property real level: 0
    property real trackHeight: 6
    property color fillColor: Theme.foreground

    implicitHeight: trackHeight + 8
    height: implicitHeight
    visible: count > 1

    Repeater {
        model: root.count > 1 ? root.count : 0

        Rectangle {
            required property int index
            readonly property real at: index / (root.count - 1)

            x: Math.round(at * (root.width - width))
            width: 2
            height: root.height
            radius: 1
            color: root.level > 0 && root.level >= at - 0.0001 ? root.fillColor : Theme.selectedFill
        }
    }
}
