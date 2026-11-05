import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Settings, Displays, Keybindings and System information as a row of icon
// buttons (app menu sidebar, Control Center). Each opens its window and
// closes the menu it sits in.
RowLayout {
    id: root

    property int buttonHeight: 34

    spacing: 6

    Repeater {
        model: [
            { icon: Icons.cog, label: "Settings", run: () => Panels.toggleSettings() },
            { icon: Icons.display, label: "Displays", run: () => Panels.toggleDisplays() },
            { icon: Icons.keyboard, label: "Keybindings", run: () => Panels.toggleKeybinds() },
            { icon: Icons.info, label: "System information", run: () => System.showSysinfo() }
        ]

        MouseArea {
            id: button

            required property var modelData

            Layout.fillWidth: true
            implicitHeight: root.buttonHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: modelData.run()

            Rectangle {
                anchors.fill: parent
                radius: Theme.smallRadius
                color: button.containsMouse ? Theme.hoverBg : Theme.cardBg
            }

            Icon {
                anchors.centerIn: parent
                text: button.modelData.icon
                color: button.containsMouse ? Theme.highlight : Theme.subtext0
            }
        }
    }
}
