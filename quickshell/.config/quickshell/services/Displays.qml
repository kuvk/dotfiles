pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Monitor profiles through ~/.config/scripts/hypr-monitors.py: layout, modes,
// scale, workspaces, text size and brightness (backlight or DDC/CI).
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/hypr-monitors.py"

    property var info: ({ monitors: [], workspaces: {}, text_scale: 1 })
    property var brightness: ({}) // monitor name -> percent, or null if not controllable
    property bool busy: false
    // connector name (e.g. DP-1) of the profile's primary monitor, "" if unknown
    readonly property string primaryName: info.monitors.find(m => m.id === info.primary)?.name ?? ""

    Component.onCompleted: refresh()

    function refresh(): void {
        stateProc.running = true;
        brightnessProc.running = true;
    }

    function apply(changes: var): void {
        busy = true;
        applyProc.command = [script, "set", JSON.stringify(changes)];
        applyProc.running = true;
    }

    function setBrightness(name: string, pct: int): void {
        const b = Object.assign({}, brightness);
        b[name] = pct;
        brightness = b;
        pending[name] = pct;
        brightnessDebounce.restart();
    }

    property var pending: ({})

    Timer {
        id: brightnessDebounce

        interval: 250
        onTriggered: {
            for (const name in root.pending)
                Quickshell.execDetached([root.script, "brightness", name, String(root.pending[name])]);
            root.pending = {};
        }
    }

    // Hyprland runs `hypr-monitors.py hotplug` itself when monitors change
    // (configs/autostart.lua); just refresh what the panel shows.
    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            refreshDelay.restart();
        }
    }

    Timer {
        id: refreshDelay

        interval: 4000
        onTriggered: root.refresh()
    }

    Process {
        id: stateProc

        command: [root.script, "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = JSON.parse(text);
                } catch (e) {
                    console.warn("Displays: bad state from hypr-monitors.py", e);
                }
            }
        }
    }

    Process {
        id: brightnessProc

        command: [root.script, "brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.brightness = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: applyProc

        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("hypr-monitors.py:", text.trim())
        }
        onExited: {
            root.busy = false;
            root.refresh();
        }
    }
}
