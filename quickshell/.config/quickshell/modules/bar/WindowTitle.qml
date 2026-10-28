import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Name of the focused app, shown on the focused monitor (like waybar's separate-outputs)
Row {
    id: root

    required property ShellScreen screen

    readonly property Toplevel toplevel: ToplevelManager.activeToplevel
    // The shell's own windows all have Quickshell's app id: show their title
    // and a matching icon instead of "Quickshell"
    readonly property bool shellWindow: toplevel?.appId === "org.quickshell"
    readonly property var shellIcons: ({ "Settings": Icons.cog, "Displays": Icons.display, "Keybindings": Icons.keyboard })
    readonly property var entry: toplevel && !shellWindow ? DesktopEntries.heuristicLookup(toplevel.appId) : null

    property bool shown: true

    visible: shown && toplevel !== null && toplevel.activated && Hyprland.focusedMonitor?.name === screen?.name
    spacing: 8
    leftPadding: 8

    IconImage {
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 15
        source: root.shellWindow ? "" : Apps.iconSource(root.entry?.icon ?? "", "")
        visible: source != ""
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.shellWindow
        text: root.shellIcons[root.toplevel?.title] ?? Icons.arch
        color: Theme.accent
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 220)
        text: root.shellWindow ? (root.toplevel?.title ?? "") : (root.entry?.name || root.toplevel?.appId || root.toplevel?.title || "")
        color: Theme.accent
    }
}
