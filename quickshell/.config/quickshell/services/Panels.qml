pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which overlay is open, and on which screen. Only one popout at a time.
Singleton {
    id: root

    property bool barVisible: true

    // Bar popouts: "network" | "bluetooth" | "audio" | "media" | "calendar" | ""
    property string popout: ""
    property var popoutScreen: null
    // Horizontal center of the bar item that opened the popout, in screen coordinates
    property real popoutX: 0

    property bool controlCenter: false
    property bool displays: false
    property bool powerMenu: false
    property bool settings: false
    property string wallpapers: "" // "static" | "live" | ""
    property var trayItem: null // SystemTrayItem whose menu is open

    // The click that dismisses a popout can also land on the button that
    // opened it; ignore that click instead of reopening the popout.
    property string lastClosed: ""
    property double lastClosedAt: 0

    // Bar tooltip
    property string tooltip: ""
    property var tooltipScreen: null
    property real tooltipX: 0

    function showTooltip(text: string, screen: var, x: real): void {
        tooltipScreen = screen;
        tooltipX = x;
        tooltip = text;
    }

    function hideTooltip(): void {
        tooltip = "";
    }

    function closePopout(name: string): void {
        if (popout !== name)
            return;
        lastClosed = name;
        lastClosedAt = Date.now();
        popout = "";
    }
    property bool launcher: false
    property string launcherMode: "apps" // "apps" | "themes"

    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor?.name;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function togglePopout(name: string, screen: var, x: real): void {
        hideTooltip();
        if (popout === name && popoutScreen === screen) {
            closePopout(name);
            return;
        }
        if (lastClosed === name && Date.now() - lastClosedAt < 300)
            return;
        controlCenter = false;
        launcher = false;
        displays = false;
        powerMenu = false;
        settings = false;
        wallpapers = "";
        popoutScreen = screen;
        popoutX = x;
        popout = name;
    }

    function toggleControlCenter(): void {
        const open = !controlCenter;
        closeAll();
        controlCenter = open;
    }

    function toggleDisplays(): void {
        const open = !displays;
        closeAll();
        displays = open;
    }

    function togglePowerMenu(): void {
        const open = !powerMenu;
        closeAll();
        powerMenu = open;
    }

    function toggleSettings(): void {
        const open = !settings;
        closeAll();
        settings = open;
    }

    function toggleWallpapers(kind: string): void {
        const open = wallpapers !== kind;
        closeAll();
        wallpapers = open ? kind : "";
    }

    function toggleLauncher(mode: string): void {
        const open = !(launcher && launcherMode === mode);
        closeAll();
        launcherMode = mode;
        launcher = open;
    }

    function closeAll(): void {
        popout = "";
        controlCenter = false;
        launcher = false;
        displays = false;
        powerMenu = false;
        settings = false;
        wallpapers = "";
        tooltip = "";
    }
}
