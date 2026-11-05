import QtQuick
import QtQuick.Layouts
import qs.config

// Control center tile: icon + label, highlighted when on
MouseArea {
    id: root

    property string icon
    property string label
    property string sublabel: ""
    property bool checked: false

    Layout.fillWidth: true
    implicitHeight: 56
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: Theme.smallRadius
        color: root.checked ? Theme.alpha(Theme.accent, root.containsMouse ? 0.35 : 0.25) : (root.containsMouse ? Theme.hoverBg : Theme.cardBg)

        Behavior on color {
            ColorAnimation {
                duration: Theme.animDuration
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Icon {
            text: root.icon
            color: root.checked ? Theme.accent : Theme.subtext0
            font.pixelSize: 18
            Layout.preferredWidth: 22
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
