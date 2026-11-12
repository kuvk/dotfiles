import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Session actions: lock, log out, sleep, reboot, shut down (Control Center)
ColumnLayout {
    Layout.fillWidth: true
    spacing: 14

    // Session actions
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: System.sessionActions

            MouseArea {
                id: action

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 44
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Panels.closeAll();
                    System.runAction(modelData.id);
                }
                // the keyboard: Enter or Space runs it
                activeFocusOnTab: true
                Keys.onPressed: event => {
                    if (Nav.isActivate(event)) {
                        action.clicked(null);
                        event.accepted = true;
                    }
                }

                FocusRing {}

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.smallRadius
                    color: action.containsMouse ? Theme.hoverBg : Theme.cardBg
                }

                SessionIcon {
                    anchors.centerIn: parent
                    entry: action.modelData
                    size: 18
                }
            }
        }
    }
}
