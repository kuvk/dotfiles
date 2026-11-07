import QtQuick
import QtQuick.Layouts
import qs.config

// "Label ........ control" row for the Settings window
RowLayout {
    id: root

    property string label
    property string hint: ""
    // Only used in normal mode: dimmed and locked in Work and Game
    property bool normalOnly: false
    default property alias control: holder.data

    Layout.fillWidth: true
    enabled: !normalOnly || !Theme.gamemode
    opacity: enabled ? 1 : 0.4
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: root.label
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.enabled ? root.hint : "Not used in Work and Game modes"
            color: Theme.overlay1
            font.pixelSize: Theme.fontSize - 2
        }
    }

    Item {
        id: holder

        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
