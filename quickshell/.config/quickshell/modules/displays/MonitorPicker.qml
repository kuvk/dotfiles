import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// A chip per monitor, disabled ones too; the chosen one is edited below (Displays)
// Monitor picker (also lists disabled monitors)
Flow {
    // the Displays panel: its monitors, selection and actions
    required property var panel

    Layout.fillWidth: true
    spacing: 6

    Repeater {
        model: panel.mons

        MouseArea {
            id: chip

            required property var modelData
            required property int index

            width: chipText.implicitWidth + 24
            height: 30
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.selected = index

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: chip.index === panel.selected ? Theme.accent : Theme.cardBg
            }

            StyledText {
                id: chipText

                anchors.centerIn: parent
                text: chip.modelData.name + (!chip.modelData.enabled ? " (off)" : chip.modelData.lid_closed ? " (lid closed)" : "")
                color: chip.index === panel.selected ? Theme.background : (chip.modelData.enabled && !chip.modelData.lid_closed ? Theme.foreground : Theme.dimText)
            }
        }
    }
}
