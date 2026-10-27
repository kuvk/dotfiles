import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Toasts in the top-right corner of the focused screen
PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: Notifs.popups.length > 0 && !Panels.controlCenter
    color: "transparent"
    anchors {
        top: true
        right: true
    }
    margins {
        top: 6
        right: 6
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: 400
    implicitHeight: column.implicitHeight
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing

        Repeater {
            // newest on top, at most 5 at a time
            model: Notifs.popups.slice(-5).reverse()

            NotificationCard {
                required property var modelData

                Layout.fillWidth: true
                notification: modelData
                popup: true
            }
        }
    }
}
