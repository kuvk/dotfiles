import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// A chip per monitor, disabled ones too, and the chosen one's name at the right; the chosen
// one is edited below (Displays)
RowLayout {
    id: picker

    // the DisplaysEditor: its monitors, selection and actions
    required property var panel

    Layout.fillWidth: true
    spacing: 12

    Flow {
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
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.selected = index

                // like the other controls: selected filled, the rest framed; round, or square
                // with the square shape
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius > 0 ? height / 2 : 0
                    color: chip.index === panel.selected ? Theme.selectedFill : (chip.containsMouse ? Theme.hoverFill : Theme.idleFill)
                    border.width: chip.index === panel.selected ? 0 : Theme.controlBorder
                    border.color: chip.containsMouse ? Theme.hoverBorder : Theme.idleBorder
                }

                StyledText {
                    id: chipText

                    anchors.centerIn: parent
                    text: chip.modelData.name + (!chip.modelData.enabled ? " (off)" : chip.modelData.lid_closed ? " (lid closed)" : "")
                    color: chip.modelData.enabled && !chip.modelData.lid_closed ? Theme.foreground : Theme.dimText
                    font.bold: chip.index === panel.selected
                }
            }
        }
    }

    StyledText {
        Layout.maximumWidth: picker.width / 2
        text: panel.current ? (panel.current.description || panel.current.name) : ""
        color: Theme.subtext
        elide: Text.ElideRight
    }
}
