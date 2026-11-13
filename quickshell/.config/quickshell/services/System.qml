pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Small bits of system state driven by Hyprdori's commands in ~/.local/bin
Singleton {
    id: root

    readonly property string scripts: Quickshell.env("HOME") + "/.local/bin/"

    property bool nightlight: false
    // Holds idle off: no idle lock or sleep (services/Idle.qml)
    property bool stayAwake: false
    // Work-Game: "normal", "work" or "game" (hyprdori-gamemode reports it over IPC)
    property string mode: "normal"
    readonly property bool gamemode: mode !== "normal"
    // For the bar's tooltip and the Control Center tile
    readonly property string modeLabel: ({ normal: "Off", work: "Work", game: "Game" })[mode] ?? "Off"
    // Stay Awake was switched on by Game mode, so leaving it switches it off
    property bool awakeForGamemode: false
    // Something is playing: idle is held off too
    readonly property bool mediaPlaying: Media.players.some(p => p.isPlaying)

    // Work-Game makes the bar full width; SUPER+CTRL+B can still float it while it
    // lasts, and leaving restores what it was before
    property var floatingBeforeGame: null

    function setMode(name: string): void {
        const on = name !== "normal";
        if (on && !gamemode) {
            floatingBeforeGame = Config.barFloating;
            Config.barFloating = false;
        } else if (!on && gamemode && floatingBeforeGame !== null) {
            Config.barFloating = floatingBeforeGame;
            floatingBeforeGame = null;
        }
        mode = name;
        if (name === "game" && !stayAwake) {
            stayAwake = true;
            awakeForGamemode = true;
        } else if (name !== "game" && awakeForGamemode) {
            stayAwake = false;
            awakeForGamemode = false;
        }
        Hypr.applyLook();
    }

    // Spotify's theme (hyprdori-spicetify): set up as soon as Spotify closes, once it has run
    // with an account logged in; it waits for Spotify to exit, and does nothing once done
    readonly property bool spotifyOpen: ToplevelManager.toplevels.values.some(t => (t.appId ?? "").toLowerCase() === "spotify")
    onSpotifyOpenChanged: {
        if (!spotifyOpen)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-spicetify", "--wait"]);
    }

    // The update window: the full system or the boot screens (hyprdori-update --window)
    function showUpdate(): void {
        Panels.closeAll();
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-update", "--window"]);
    }

    // Manage WebApps: list, install or uninstall web apps (hyprdori-webapp --window)
    function showWebapp(): void {
        Panels.closeAll();
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-webapp", "--window"]);
    }

    // System Information: fastfetch in a kitty window (hyprdori-sysinfo), opened or closed
    function showSysinfo(): void {
        Panels.closeAll();
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-sysinfo"]);
    }
    property bool hasBrightness: false
    property real brightness: 0

    function refresh(): void {
        statusProc.running = true;
        brightnessProc.running = true;
    }

    function inNightlightHours(): bool {
        const minutes = value => {
            const [h, m] = value.split(":").map(Number);
            return h * 60 + m;
        };
        const d = new Date();
        const now = d.getHours() * 60 + d.getMinutes();
        const start = minutes(Config.nightlightStart);
        const end = minutes(Config.nightlightEnd);
        return start <= end ? now >= start && now < end : now >= start || now < end;
    }

    // Night light schedule: acts only when the hours start or end, so a manual
    // toggle holds until then. On startup it only turns on, never off.
    property var wasInNightlightHours: null

    function checkNightlightSchedule(): void {
        if (!Config.nightlightSchedule) {
            wasInNightlightHours = null;
            return;
        }
        const inHours = inNightlightHours();
        if (inHours !== wasInNightlightHours && (inHours || wasInNightlightHours !== null)) {
            Quickshell.execDetached([scripts + "hyprdori-nightlight", inHours ? "on" : "off"]);
            nightlight = inHours;
            delayedRefresh.restart();
        }
        wasInNightlightHours = inHours;
    }

    Connections {
        target: Config

        function onNightlightScheduleChanged(): void {
            root.checkNightlightSchedule();
        }

        function onNightlightStartChanged(): void {
            root.checkNightlightSchedule();
        }

        function onNightlightEndChanged(): void {
            root.checkNightlightSchedule();
        }
    }

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.checkNightlightSchedule();
            statusProc.running = true;
        }
    }

    function toggleNightlight(): void {
        Quickshell.execDetached([scripts + "hyprdori-nightlight"]);
        nightlight = !nightlight;
        delayedRefresh.restart();
    }

    // normal, Work, Game, normal; the script reports back through `qs ipc call theme mode`
    function cycleMode(): void {
        Quickshell.execDetached([scripts + "hyprdori-gamemode", "cycle"]);
    }

    function setBrightness(value: real): void {
        const pct = Math.round(Math.max(0.01, Math.min(1, value)) * 100);
        brightness = pct / 100;
        Quickshell.execDetached(["brightnessctl", "-q", "s", `${pct}%`]);
    }

    // Shared by the power menu and the control center. `key` is the power
    // menu shortcut, `color` a Theme color name.
    readonly property var sessionActions: [
        { id: "lock", label: "Lock", icon: Icons.lock, key: "l", color: "green" },
        { id: "suspend", label: "Sleep", icon: Icons.bed, key: "u", color: "orange" },
        { id: "logout", label: "Log out", icon: Icons.signOut, key: "e", color: "cyan" },
        { id: "reboot", label: "Reboot", icon: Icons.reboot, key: "r", color: "magenta" },
        { id: "shutdown", label: "Shut down", icon: Icons.power, key: "s", color: "red" }
    ]

    function runAction(id: string): void {
        switch (id) {
        case "lock":
            Lock.lock();
            break;
        case "suspend":
            // hyprdori-sleep-lock locks before sleeping
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        // hyprshutdown asks every app to close (an app with unsaved work can ask first), exits
        // Hyprland, then runs the post command: reboot and power off happen after a clean exit.
        // --no-wall: no "The system will power off now!" on the console before Plymouth shows
        case "logout":
            Quickshell.execDetached(["hyprshutdown", "-t", "Logging out ..."]);
            break;
        case "reboot":
            Quickshell.execDetached(["hyprshutdown", "-t", "Rebooting ...", "-p", "systemctl --no-wall reboot"]);
            break;
        case "shutdown":
            Quickshell.execDetached(["hyprshutdown", "-t", "Shutting down ...", "-p", "systemctl --no-wall poweroff"]);
            break;
        }
    }

    function run(cmd: var): void {
        Quickshell.execDetached(cmd);
    }

    Component.onCompleted: refresh()

    Timer {
        id: delayedRefresh

        interval: 800
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc

        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo nightlight; test -e /tmp/hypr-gamemode && echo \"mode:$(cat /tmp/hypr-gamemode)\"; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.nightlight = text.includes("nightlight");
                const found = text.match(/mode:(\w*)/);
                root.mode = found ? (found[1] || "work") : "normal";
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
