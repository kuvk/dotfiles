import QtQuick
import QtQuick.Layouts
import qs.config

// Row used in dropdown lists (networks, devices, sinks)
MouseArea {
    id: root

    property string icon
    property string label
    property string sublabel: ""
    property bool highlighted: false
    default property alias trailing: trailingRow.data

    Layout.fillWidth: true
    implicitHeight: 44
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: Theme.smallRadius
        color: root.highlighted ? Theme.selectedFill : (root.containsMouse ? Theme.hoverFill : "transparent")
        border.width: root.containsMouse && !root.highlighted ? Theme.controlBorder : 0
        border.color: Theme.hoverBorder
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 10

        Icon {
            text: root.icon
            color: root.highlighted ? Theme.accent : Theme.subtext
            Layout.preferredWidth: 18
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: root.highlighted ? Theme.accent : Theme.foreground
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                color: Theme.subtext
                font.pixelSize: Theme.captionSize
            }
        }

        Row {
            id: trailingRow

            spacing: 2
        }
    }
}
