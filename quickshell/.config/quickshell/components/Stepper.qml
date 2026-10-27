import QtQuick
import QtQuick.Layouts
import qs.config

// "‹ value ›" selector; emits step(-1 | 1)
RowLayout {
    id: root

    property alias text: label.text
    signal step(int delta)

    spacing: 4
    opacity: enabled ? 1 : 0.4

    IconButton {
        size: 26
        icon: Icons.chevronLeft
        enabled: root.enabled
        onClicked: root.step(-1)
    }

    StyledText {
        id: label

        Layout.preferredWidth: 170
        horizontalAlignment: Text.AlignHCenter
    }

    IconButton {
        size: 26
        icon: Icons.chevronRight
        enabled: root.enabled
        onClicked: root.step(1)
    }
}
