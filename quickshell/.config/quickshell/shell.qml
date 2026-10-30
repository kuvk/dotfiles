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
import qs.modules.notifications
import qs.modules.powermenu
import qs.modules.settings
import qs.modules.sysinfo
import qs.modules.transition
import qs.modules.wallpaper
import qs.modules.themes

ShellRoot {
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

    // Regular windows: created when opened and destroyed when closed, so each
    // opening starts at its default size (Hyprland keeps a resized size
    // otherwise)
    LazyLoader {
        active: Panels.displays

        DisplaysPanel {}
    }

    LockScreen {}

    LazyLoader {
        active: Panels.settings

        SettingsWindow {}
    }

    LazyLoader {
        active: Panels.sysinfo

        SysinfoWindow {}
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

        // the theme carousel (kept here for old bindings)
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

        // ALT+B: full width / floating
        function floating(): void {
            Config.barFloating = !Config.barFloating;
        }

        function show(): void {
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

        function gamemode(enabled: bool): void {
            Theme.gamemode = enabled;
            System.setGamemode(enabled);
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }

        // No slide animation, for before_sleep_cmd
        function lockNow(): void {
            Lock.lockNow();
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

        // ALT+W: opens on static wallpapers, Tab switches to live
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
            Panels.toggleSysinfo();
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
