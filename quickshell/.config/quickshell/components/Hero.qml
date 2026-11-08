import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// The top of a dropdown, after the network one: a large icon, a bold title, a status line
// in small capitals under it, and the dropdown's controls on the right (its children)
RowLayout {
    id: hero

    property string icon
    property color iconColor: Theme.highlight
    property string title
    property string status
    property color statusColor: Theme.subtext0
    // for a dropdown that animates its status line (the network's phrases)
    readonly property alias statusItem: statusLabel
    default property alias controls: controlsRow.data

    Layout.fillWidth: true
    spacing: 12

    Icon {
        text: hero.icon
        color: hero.iconColor
        font.pixelSize: Theme.iconSize * 2
        Layout.preferredWidth: Theme.iconSize * 2.2
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        StyledText {
            Layout.fillWidth: true
            text: hero.title
            font.pixelSize: Theme.fontSize + 2
            font.weight: Font.Bold
        }

        Caption {
            id: statusLabel

            Layout.fillWidth: true
            visible: text !== ""
            text: hero.status
            color: hero.statusColor
        }
    }

    RowLayout {
        id: controlsRow

        spacing: 8
    }
}
