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
    property bool keybinds: false
    property string wallpapers: "" // "static" | "live" | ""
    property bool themes: false // theme carousel
    property bool appMenu: false // app menu dropdown with categories
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

    // Bar windows (one per monitor). Dropdowns, the app menu and the Control
    // Center include them in their focus grab, so a click on another bar icon
    // reaches it (switching straight to that dropdown) instead of only
    // closing the open one.
    property var bars: []

    function registerBar(bar: var): void {
        bars = bars.concat([bar]);
    }

    function unregisterBar(bar: var): void {
        bars = bars.filter(b => b !== bar);
    }

    // Switching workspaces (keys or mouse) closes the dropdowns
    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged(): void {
            root.popout = "";
            root.appMenu = false;
            root.controlCenter = false;
            root.tooltip = "";
        }
    }

    // Screen of the open overlay (launcher, control center, wallpapers, ...),
    // fixed when it opens. Following the focused monitor live would move a
    // shown window, and Quickshell recreates a moved layer window, which
    // drops its focus grab and keyboard focus (and blanked the wallpaper cards).
    property var overlayScreen: null

    function pinScreen(open: bool): void {
        if (open)
            overlayScreen = focusedScreen;
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
        appMenu = false;
        powerMenu = false;
        wallpapers = "";
        themes = false;
        popoutScreen = screen;
        popoutX = x;
        popout = name;
    }

    function toggleControlCenter(): void {
        const open = !controlCenter;
        closeAll();
        pinScreen(open);
        controlCenter = open;
    }

    // Settings and Displays are regular windows: opening them closes the
    // overlays, but nothing else closes them
    function toggleDisplays(): void {
        const open = !displays;
        closeAll();
        displays = open;
    }

    function togglePowerMenu(): void {
        const open = !powerMenu;
        closeAll();
        pinScreen(open);
        powerMenu = open;
    }

    function toggleSettings(): void {
        const open = !settings;
        closeAll();
        settings = open;
    }

    function toggleKeybinds(): void {
        const open = !keybinds;
        closeAll();
        keybinds = open;
    }

    function toggleAppMenu(): void {
        const open = !appMenu;
        closeAll();
        pinScreen(open);
        appMenu = open;
    }

    function toggleThemes(): void {
        const open = !themes;
        closeAll();
        pinScreen(open);
        themes = open;
    }

    function toggleWallpapers(kind: string): void {
        const open = wallpapers !== kind;
        closeAll();
        pinScreen(open);
        wallpapers = open ? kind : "";
    }

    function toggleLauncher(mode: string): void {
        const open = !(launcher && launcherMode === mode);
        closeAll();
        pinScreen(open);
        launcherMode = mode;
        launcher = open;
    }

    function closeAll(): void {
        popout = "";
        controlCenter = false;
        launcher = false;
        appMenu = false;
        powerMenu = false;
        wallpapers = "";
        themes = false;
        tooltip = "";
    }
}
