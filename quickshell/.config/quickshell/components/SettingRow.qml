import QtQuick
import QtQuick.Layouts
import qs.config

// "Label ........ control" row for the Settings window
RowLayout {
    id: root

    property string label
    property string hint: ""
    default property alias control: holder.data

    Layout.fillWidth: true
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
            text: root.hint
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
