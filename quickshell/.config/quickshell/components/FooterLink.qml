import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// The line at the bottom of a dropdown, on the right: opens the full app (or refreshes)
Item {
    id: link

    property alias text: label.text
    signal clicked

    Layout.fillWidth: true
    implicitHeight: label.implicitHeight

    StyledText {
        id: label

        anchors.right: parent.right
        width: Math.min(implicitWidth, parent.width)
        color: area.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent
        font.pixelSize: Theme.fontSize - 1
        elide: Text.ElideLeft

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }
}
