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
import qs.modules.launcher
import qs.modules.lock
import qs.modules.notifications
import qs.modules.powermenu

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    NotificationPopups {}

    ControlCenter {}

    Launcher {}

    PowerMenu {}

    DisplaysPanel {}

    LockScreen {}

    // qs ipc call <target> <function> [args]
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Panels.toggleLauncher("apps");
        }

        function themes(): void {
            Panels.toggleLauncher("themes");
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
        target: "panels"

        function close(): void {
            Panels.closeAll();
        }
    }
}
