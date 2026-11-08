import QtQuick
import qs.config

// A theme's palette as bars stacked top to bottom (theme carousel card):
// backgrounds, text, the accent, then the colors.
Rectangle {
    id: root

    property var colors: ({})
    property string title: ""

    readonly property var slots: ["background", "dark_background", "lighter_background", "selection", "dark_foreground", "foreground", "accent", "red", "orange", "yellow", "green", "cyan", "blue", "magenta", "bright_magenta"]
    readonly property real gap: Math.max(1, height * 0.006)

    color: colors.darker_background ?? "#000000"

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
