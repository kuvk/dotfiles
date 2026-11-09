import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Every `qs ipc call <target> <function> [args]` command (keybindings in hypr/configs/
// bindings.lua and the scripts use them). Here rather than in each service: services are
// created on first use, and a command must exist from the start.
Scope {
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

        // a page by its sidebar id: style, fonts, bar, displays, sleep
        function open(page: string): void {
            Panels.openSettings(page);
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
