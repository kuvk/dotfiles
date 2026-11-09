import QtQuick
import QtQuick.Controls
import qs.config

// An icon that does something when clicked: no background, the icon turns the text color
// under the cursor, and a tooltip says what it does (`tooltip`)
MouseArea {
    id: root

    property alias icon: label.text
    property color color: Theme.foreground
    property int size: 30
    property string tooltip: ""

    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Icon {
        id: label

        anchors.centerIn: parent
        color: root.containsMouse ? Theme.foreground : root.color
    }

    ToolTip {
        visible: root.containsMouse && root.tooltip !== ""
        delay: 400
        text: root.tooltip
        padding: 6

        contentItem: StyledText {
            text: root.tooltip
            font.pixelSize: Theme.smallSize
        }

        background: Rectangle {
            color: Theme.background
            radius: Theme.smallRadius
            border.width: Theme.controlBorder
            border.color: Theme.idleBorder
        }
    }
}
