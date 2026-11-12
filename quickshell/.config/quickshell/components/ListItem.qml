import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Row used in dropdown lists (networks, devices, sinks): the current one filled and bold,
// the one under the cursor framed
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
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (Nav.isActivate(event)) {
            root.clicked(null);
            event.accepted = true;
        }
    }
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: Theme.smallRadius
        color: root.containsMouse ? Theme.hoverFill : (root.highlighted ? Theme.selectedFill : "transparent")
        border.width: root.containsMouse ? Theme.controlBorder : 0
        border.color: Theme.hoverBorder
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 10

        Icon {
            text: root.icon
            color: Theme.foreground
            font.pixelSize: Theme.titleSize
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.bold: root.highlighted
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                color: Theme.labelText
                font.pixelSize: Theme.captionSize
            }
        }

        Row {
            id: trailingRow

            spacing: 2
        }
    }

    FocusRing {}
}
