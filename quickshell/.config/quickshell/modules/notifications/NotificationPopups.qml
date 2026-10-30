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
    // the cards sit 10px in, leaving room for their shadow
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: 420
    implicitHeight: Math.ceil(column.implicitHeight + 20)
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Notifs.replying ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    ColumnLayout {
        id: column

        x: 10
        y: 4
        width: parent.width - 20
        spacing: Theme.spacing

        Repeater {
            // newest on top, at most 5 at a time. ScriptModel keeps existing
            // cards (and their countdowns) when one is added or removed
            model: ScriptModel {
                values: Notifs.popups.slice(-5).reverse()
            }

            NotificationCard {
                required property var modelData

                Layout.fillWidth: true
                notification: modelData
                popup: true
            }
        }
    }
}
