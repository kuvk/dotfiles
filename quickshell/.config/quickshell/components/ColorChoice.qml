import QtQuick
import qs.config

// Theme colors to pick from, wrapping to fit; `value` is the color's name in Theme
Flow {
    id: root

    property string value
    signal picked(string name)

    readonly property var defaultNames: ["text", "subtext1", "subtext0", "base", "accent", "accent2", "accent3", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "blue", "lavender", "mauve", "pink"]
    property var names: defaultNames

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
                border.color: root.value === swatch.modelData ? Theme.text : Theme.overlay0
                // the outline keeps background colors visible on the window
                border.width: root.value === swatch.modelData ? 2 : 1
            }
        }
    }
}
