import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// A choice in a row of them (DNS, Wi-Fi band); a Repeater's delegate
MouseArea {
    id: pill

    property string text
    property bool current: false

    Layout.fillWidth: true
    Layout.preferredWidth: pillLabel.implicitWidth + 20
    Layout.preferredHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: pill.current ? Theme.alpha(Theme.highlight, 0.25) : (pill.containsMouse ? Theme.hoverBg : Theme.cardBg)
        border.color: pill.current ? Theme.highlight : "transparent"
        border.width: Theme.borderWidth
    }

    StyledText {
        id: pillLabel

        anchors.centerIn: parent
        text: pill.text
        color: pill.current ? Theme.highlight : Theme.text
        font.pixelSize: Theme.fontSize - 1
    }
}
