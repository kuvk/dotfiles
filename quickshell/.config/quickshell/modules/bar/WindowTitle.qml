import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components

// Name of the focused app, shown on the focused monitor (like waybar's separate-outputs)
Row {
    id: root

    required property ShellScreen screen

    readonly property Toplevel toplevel: ToplevelManager.activeToplevel
    readonly property var entry: toplevel ? DesktopEntries.heuristicLookup(toplevel.appId) : null

    visible: Config.showWindowTitle && toplevel !== null && toplevel.activated && Hyprland.focusedMonitor?.name === screen?.name
    spacing: 8
    leftPadding: 8

    IconImage {
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 15
        source: Quickshell.iconPath(root.entry?.icon ?? "", true)
        visible: source != ""
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 220)
        text: root.entry?.name || root.toplevel?.appId || root.toplevel?.title || ""
        color: Theme.accent
    }
}
