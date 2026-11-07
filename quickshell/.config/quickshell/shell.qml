//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.bar
import qs.modules.controlcenter
import qs.modules.displays
import qs.modules.keybinds
import qs.modules.launcher
import qs.modules.lock
import qs.modules.network
import qs.modules.notifications
import qs.modules.powermenu
import qs.modules.settings
import qs.modules.transition
import qs.modules.wallpaper
import qs.modules.themes

ShellRoot {
    // Terminal status lines follow the corners: square in Work-Game or at radius 0
    readonly property bool squareCorners: Theme.radius === 0

    function applyShape(): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--shape", squareCorners ? "square" : "rounded"]);
    }

    onSquareCornersChanged: applyShape()
    Component.onCompleted: {
        applyShape();
        cursorReveal.start();
    }

    // Hyprland hides the cursor while it starts (hypr/configs/startup-cursor.lua); with the
    // bar and wallpaper drawn, it may show. A no-op after that, and when the shell restarts.
    Timer {
        id: cursorReveal

        interval: 300
        onTriggered: Quickshell.execDetached(["hyprctl", "eval", "if kuvk_cursor_reveal then kuvk_cursor_reveal() end"])
    }

    // Idle lock and sleep, with the times from Settings for the power source in use
    readonly property bool idleEnabled: Idle.enabled

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Theme and wallpaper switch animation, above everything
    Variants {
        model: Quickshell.screens

        TransitionOverlay {}
    }

    NotificationPopups {}

    ControlCenter {}

    Launcher {}

    Clipboard {}

    AppMenu {}

    PowerMenu {}

    // The session lock, and Settings' preview of it
    LockScreen {}

    LockPreview {}

    // From the network dropdown
    WifiQr {}

    SpeedTest {}

    // Regular windows: created when opened and destroyed when closed, so each
    // opening starts at its default size (Hyprland keeps a resized size
    // otherwise)
    LazyLoader {
        active: Panels.displays

        DisplaysPanel {}
    }

    LazyLoader {
        active: Panels.settings

        SettingsWindow {}
    }

    LazyLoader {
        active: Panels.keybinds

        KeybindsWindow {}
    }

    WallpaperPicker {}

    WallpaperBackdrop {}

    ThemePicker {}

    // qs ipc call <target> <function> [args]
    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            Panels.toggleClipboard();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Panels.toggleLauncher("apps");
        }

        // the theme carousel
        function themes(): void {
            Panels.toggleThemes();
        }

        // the app menu dropdown with categories
        function menu(): void {
            Panels.toggleAppMenu();
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            Panels.toggleControlCenter();
        }

        function clear(): void {
            Notifs.clearAll();
        }

        function dnd(enabled: bool): void {
            Notifs.dnd = enabled;
        }

        function toggleDnd(): void {
            Notifs.dnd = !Notifs.dnd;
        }
    }

    IpcHandler {
        target: "bar"

        // SUPER+CTRL+B: full width / floating
        function floating(): void {
            Config.barFloating = !Config.barFloating;
        }

        // not "show": `qs ipc call bar show` would run qs's own `ipc show`
        function reveal(): void {
            Panels.barVisible = true;
        }

        function hide(): void {
            Panels.closeAll();
            Panels.barVisible = false;
        }

        function toggle(): void {
            Panels.barVisible = !Panels.barVisible;
        }
    }

    IpcHandler {
        target: "theme"

        function reload(): void {
            Theme.reload();
        }

        // "normal", "work" or "game", from hypr-gamemode.sh
        function mode(name: string): void {
            Theme.gamemode = name !== "normal";
            System.setMode(name);
        }
    }

    // SUPER+`, the idle timer, and scripts/sleep-lock.sh before every suspend
    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }

        function isLocked(): bool {
            return Lock.locked;
        }

        // { requested, secure }: sleep-lock.sh waits for secure before letting the machine sleep
        function status(): string {
            return JSON.stringify({ requested: Lock.locked, secure: Lock.secure });
        }
    }

    IpcHandler {
        target: "idle"

        // what idle is doing, and what holds it off
        function status(): string {
            return Idle.status();
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            Panels.togglePowerMenu();
        }
    }

    IpcHandler {
        target: "displays"

        function toggle(): void {
            Panels.toggleDisplays();
        }
    }

    IpcHandler {
        target: "wallpaper"

        function static(): void {
            Panels.toggleWallpapers("static");
        }

        function live(): void {
            Panels.toggleWallpapers("live");
        }

        // SUPER+W: opens on static wallpapers, Tab switches to live
        function toggle(): void {
            Panels.toggleWallpapers(Panels.wallpapers !== "" ? Panels.wallpapers : "static");
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            Panels.toggleSettings();
        }
    }

    IpcHandler {
        target: "themes"

        function toggle(): void {
            Panels.toggleThemes();
        }
    }

    IpcHandler {
        target: "sysinfo"

        function toggle(): void {
            System.showSysinfo();
        }
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            Panels.toggleKeybinds();
        }
    }

    IpcHandler {
        target: "panels"

        function close(): void {
            Panels.closeAll();
        }
    }
}
