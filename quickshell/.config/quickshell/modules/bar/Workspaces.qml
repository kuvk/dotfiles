import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Workspaces of this monitor. Only the focused workspace (on the focused
// monitor) is marked active; hovering turns an icon accent.
Row {
    id: root

    required property ShellScreen screen

    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === screen?.name).sort((a, b) => a.id - b.id)

    spacing: 0

    Repeater {
        model: root.workspaces

        BarButton {
            id: ws

            required property HyprlandWorkspace modelData
            readonly property bool current: Hyprland.focusedWorkspace === modelData

            implicitWidth: 28
            indicator: false
            onClicked: Hypr.focusWorkspace(modelData.id)

            Icon {
                text: ws.current ? Icons.workspaceActive : Icons.workspace
                color: ws.current || ws.containsMouse ? Theme.accent : (ws.modelData.urgent ? Theme.red : Theme.accent2)
                font.pixelSize: 12
            }
        }
    }
}
