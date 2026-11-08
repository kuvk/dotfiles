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
import qs.modules.osd
import qs.modules.powermenu
import qs.modules.settings
import qs.modules.transition
import qs.modules.wallpaper
import qs.modules.themes

ShellRoot {
    // Terminal status lines follow the corners: square in Work-Game or at radius 0
    readonly property bool squareCorners: Theme.radius === 0

    function applyShape(): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--shape", squareCorners ? "square" : "rounded"]);
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
        onTriggered: Quickshell.execDetached(["hyprctl", "eval", "if hyprdori_cursor_reveal then hyprdori_cursor_reveal() end"])
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

    // volume, brightness and keyboard light changes
    OsdPopup {}

    // `qs ipc call` commands
    Ipc {}
}
