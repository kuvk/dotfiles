import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Settings, Displays, Keybindings, Update, Manage WebApps and System information as a row of
// icon buttons of one width (the Control Center), or some of them (`only`: the app menu has
// Settings). Each opens its window and closes the menu it sits in.
RowLayout {
    id: root

    property int buttonHeight: 34
    // the buttons' ids to show, all of them when empty
    property var only: []

    spacing: 6

    Repeater {
        model: [
            { id: "settings", icon: Icons.cog, label: "Settings", run: () => Panels.toggleSettings() },
            { id: "displays", icon: Icons.display, label: "Displays", run: () => Panels.openSettings("displays") },
            { id: "keybinds", icon: Icons.keyboard, label: "Keybindings", run: () => Panels.toggleKeybinds() },
            { id: "update", icon: Icons.update, label: "Update", run: () => System.showUpdate() },
            { id: "webapp", icon: Icons.web, label: "Manage WebApps", run: () => System.showWebapp() },
            { id: "sysinfo", icon: Icons.info, label: "System information", run: () => System.showSysinfo() }
        ].filter(b => root.only.length === 0 || root.only.includes(b.id))

        MouseArea {
            id: button

            required property var modelData

            Layout.fillWidth: true
            implicitHeight: root.buttonHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: modelData.run()
            // the keyboard: Enter or Space opens it
            activeFocusOnTab: true
            Keys.onPressed: event => {
                if (Nav.isActivate(event)) {
                    button.modelData.run();
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.smallRadius
                color: button.containsMouse ? Theme.hoverBg : Theme.cardBg
            }

            FocusRing {}

            Icon {
                anchors.centerIn: parent
                text: button.modelData.icon
                color: button.containsMouse ? Theme.accent : Theme.subtext
            }
        }
    }
}
