import QtQuick
import qs.config

// Row of theme colors to pick from; `value` is the color's name in Theme
Row {
    id: root

    property string value
    signal picked(string name)

    readonly property var names: ["text", "subtext0", "accent", "accent2", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "blue", "lavender", "mauve", "pink"]

    spacing: 4

    Repeater {
        model: root.names

        MouseArea {
            id: swatch

            required property string modelData

            width: 22
            height: 22
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked(modelData)

            Rectangle {
                anchors.centerIn: parent
                width: root.value === swatch.modelData ? 22 : (swatch.containsMouse ? 18 : 16)
                height: width
                radius: width / 2
                color: Theme[swatch.modelData]
                border.color: Theme.text
                border.width: root.value === swatch.modelData ? 2 : 0
            }
        }
    }
}
