import QtQuick
import qs.config

// A theme's palette as bars stacked top to bottom (theme carousel card):
// backgrounds, text, the two accents, then the colors.
Rectangle {
    id: root

    property var colors: ({})
    property string title: ""

    readonly property var slots: ["base", "mantle", "surface0", "surface1", "overlay1", "text", "accent", "accent2", "red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink"]
    readonly property real gap: Math.max(1, height * 0.006)

    color: colors.crust ?? "#000000"

    Column {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.slots

            Rectangle {
                required property string modelData

                width: root.width
                height: (root.height - root.gap * (root.slots.length - 1)) / root.slots.length
                color: root.colors[modelData] ?? "#808080"
            }
        }
    }
}
