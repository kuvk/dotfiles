import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// A choice in a row of them (DNS, Wi-Fi band, power mode); a Repeater's delegate. Styled
// like the control center's toggles: the theme's corners (square in Work-Game), a hairline border,
// the chosen one filled, with its label in the accent. With an icon, the icon sits above the label.
MouseArea {
    id: chip

    property string text
    property string icon: ""
    property bool current: false

    Layout.fillWidth: true
    Layout.preferredWidth: chipLabel.implicitWidth + 20
    Layout.preferredHeight: icon !== "" ? 52 : 28
    hoverEnabled: true
    activeFocusOnTab: true
    Keys.onPressed: event => {
        if (Nav.isActivate(event)) {
            chip.clicked(null);
            event.accepted = true;
        }
    }
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: Theme.smallRadius
        color: chip.current ? Theme.selectedFill : (chip.containsMouse ? Theme.hoverFill : Theme.idleFill)
        border.width: chip.current ? 0 : Theme.controlBorder
        border.color: chip.containsMouse ? Theme.hoverBorder : Theme.idleBorder

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: chipLabel.top
        anchors.bottomMargin: 2
        visible: chip.icon !== ""
        text: chip.icon
        color: chip.current ? Theme.accent : Theme.subtext
    }

    StyledText {
        id: chipLabel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: chip.icon !== "" ? 9 : 0
        text: chip.text
        color: chip.current ? Theme.accent : Theme.foreground
        font.pixelSize: Theme.smallSize
        font.weight: Font.DemiBold
    }

    FocusRing {}
}
