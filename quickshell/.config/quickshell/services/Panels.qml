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
        if (popout === name && popoutScreen === screen) {
            popout = "";
            return;
        }
        controlCenter = false;
        launcher = false;
        displays = false;
        powerMenu = false;
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
    }
}
