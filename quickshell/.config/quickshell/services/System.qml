pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Small bits of system state driven by the existing scripts in ~/.config/scripts
Singleton {
    id: root

    readonly property string scripts: Quickshell.env("HOME") + "/.config/scripts/"

    property bool nightlight: false
    // Holds a systemd idle inhibitor, which hypridle respects
    property bool stayAwake: false
    // Work-Game (hypr-gamemode.sh reports its state over IPC)
    property bool gamemode: false
    // Stay Awake was switched on by Work-Game, so leaving it switches it off
    property bool awakeForGamemode: false
    // Something is playing: keep the screen awake (replaces media-inhibit.sh)
    readonly property bool mediaPlaying: Media.players.some(p => p.isPlaying)

    // Work-Game makes the bar full width; ALT+B can still float it while it
    // lasts, and leaving restores what it was before
    property var floatingBeforeGame: null

    function setGamemode(on: bool): void {
        if (on && !gamemode) {
            floatingBeforeGame = Config.barFloating;
            Config.barFloating = false;
        } else if (!on && gamemode && floatingBeforeGame !== null) {
            Config.barFloating = floatingBeforeGame;
            floatingBeforeGame = null;
        }
        gamemode = on;
        if (on && !stayAwake) {
            stayAwake = true;
            awakeForGamemode = true;
        } else if (!on && awakeForGamemode) {
            stayAwake = false;
            awakeForGamemode = false;
        }
        Hypr.applyGaps();
    }

    // System information window (modules/sysinfo)
    function showSysinfo(): void {
        Panels.toggleSysinfo();
    }
    property bool hasBrightness: false
    property real brightness: 0

    function refresh(): void {
        statusProc.running = true;
        brightnessProc.running = true;
    }

    function toggleNightlight(): void {
        Quickshell.execDetached([scripts + "nightlight-toggle.sh"]);
        nightlight = !nightlight;
        delayedRefresh.restart();
    }

    function toggleGamemode(): void {
        // the script reports back through `qs ipc call theme gamemode`
        Quickshell.execDetached([scripts + "hypr-gamemode.sh"]);
    }

    function setBrightness(value: real): void {
        const pct = Math.round(Math.max(0.01, Math.min(1, value)) * 100);
        brightness = pct / 100;
        Quickshell.execDetached(["brightnessctl", "-q", "s", `${pct}%`]);
    }

    // Shared by the power menu and the control center. `key` is the power
    // menu shortcut, `color` a Theme color name (same colors as the old wlogout icons).
    readonly property var sessionActions: [
        { id: "lock", label: "Lock", icon: Icons.lock, key: "l", color: "green" },
        { id: "suspend", label: "Sleep", icon: Icons.bed, key: "u", color: "peach" },
        { id: "logout", label: "Log out", icon: Icons.signOut, key: "e", color: "teal" },
        { id: "reboot", label: "Reboot", icon: Icons.reboot, key: "r", color: "mauve" },
        { id: "shutdown", label: "Shut down", icon: Icons.power, key: "s", color: "red" }
    ]

    function runAction(id: string): void {
        switch (id) {
        case "lock":
            Lock.lock();
            break;
        case "suspend":
            // hypridle locks before sleeping (before_sleep_cmd)
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "logout":
            Quickshell.execDetached(["hyprshutdown", "-t", "Logging out ..."]);
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "shutdown":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
    }

    function run(cmd: var): void {
        Quickshell.execDetached(cmd);
    }

    Component.onCompleted: refresh()

    Process {
        running: root.stayAwake
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Stay awake", "sleep", "infinity"]
    }

    Process {
        running: root.mediaPlaying && !root.stayAwake
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Media playing", "sleep", "infinity"]
    }

    Timer {
        id: delayedRefresh

        interval: 800
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc

        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo nightlight; test -e /tmp/hypr-gamemode && echo gamemode; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.nightlight = text.includes("nightlight");
                root.gamemode = text.includes("gamemode");
            }
        }
    }

    Process {
        id: brightnessProc

        // intel_backlight,backlight,12000,50%,24000
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                root.hasBrightness = f.length >= 5;
                if (root.hasBrightness)
                    root.brightness = parseInt(f[2]) / parseInt(f[4]);
            }
        }
    }
}
