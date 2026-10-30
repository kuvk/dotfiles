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
        color: root.containsMouse ? Theme.hoverBg : (root.highlighted ? Theme.cardBg : "transparent")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 10

        Icon {
            text: root.icon
            color: root.highlighted ? Theme.highlight : Theme.subtext0
            Layout.preferredWidth: 18
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: root.highlighted ? Theme.highlight : Theme.text
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Row {
            id: trailingRow

            spacing: 2
        }
    }
}
