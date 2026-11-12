import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Control center tile: icon + label, highlighted when on
MouseArea {
    id: root

    property string icon
    property string label
    property string sublabel: ""
    property bool checked: false

    Layout.fillWidth: true
    implicitHeight: 56
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
        color: root.checked ? Theme.selectedFill : (root.containsMouse ? Theme.hoverFill : Theme.idleFill)
        border.width: root.checked ? 0 : Theme.controlBorder
        border.color: root.containsMouse ? Theme.hoverBorder : Theme.idleBorder

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Icon {
            text: root.icon
            color: root.checked ? Theme.accent : Theme.subtext
            font.pixelSize: Theme.iconLargeSize
            Layout.preferredWidth: 22
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                color: Theme.subtext
                font.pixelSize: Theme.captionSize
            }
        }
    }

    FocusRing {}
}
