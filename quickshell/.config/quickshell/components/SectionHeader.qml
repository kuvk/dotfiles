import QtQuick
import QtQuick.Layouts
import qs.config

// Title row for popouts: title on the left, optional controls on the right
RowLayout {
    id: root

    property string title
    default property alias controls: controlsRow.data

    Layout.fillWidth: true
    spacing: 8

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Theme.fontSize + 2
        font.weight: Font.Bold
    }

    Row {
        id: controlsRow

        spacing: 4
    }
}
