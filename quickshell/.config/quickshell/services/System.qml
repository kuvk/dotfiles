pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Small bits of system state driven by the existing scripts in ~/.config/scripts
Singleton {
    id: root

    readonly property string scripts: Quickshell.env("HOME") + "/.config/scripts/"

    property bool nightlight: false
    property bool gamemode: false
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
        Quickshell.execDetached([scripts + "hypr-gamemode.sh"]);
        gamemode = !gamemode;
        delayedRefresh.restart();
    }

    function setBrightness(value: real): void {
        const pct = Math.round(Math.max(0.01, Math.min(1, value)) * 100);
        brightness = pct / 100;
        Quickshell.execDetached(["brightnessctl", "-q", "s", `${pct}%`]);
    }

    function powerMenu(): void {
        Quickshell.execDetached([scripts + "wlogout-dynamic.sh"]);
    }

    function lock(): void {
        Quickshell.execDetached([scripts + "lockscreen.sh"]);
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
