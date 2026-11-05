pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Monitor profiles through ~/.config/scripts/hypr-monitors.py: layout, modes,
// scale, workspaces, text size and brightness (backlight or DDC/CI).
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/hypr-monitors.py"

    property var info: ({ monitors: [], workspaces: {}, text_scale: 1 })
    property var brightness: ({}) // monitor name -> percent, or null if not controllable
    property bool busy: false
    property double ignoreEventsUntil: 0

    function refresh(): void {
        stateProc.running = true;
        brightnessProc.running = true;
    }

    function apply(changes: var): void {
        busy = true;
        ignoreEventsUntil = Date.now() + 5000;
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

    // Re-apply the matching profile when monitors are plugged in or out
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (!["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2"].includes(event.name))
                return;
            if (Date.now() < root.ignoreEventsUntil)
                return;
            hotplug.restart();
        }
    }

    Timer {
        id: hotplug

        interval: 1500
        onTriggered: {
            root.ignoreEventsUntil = Date.now() + 5000;
            hotplugProc.running = true;
        }
    }

    Process {
        id: hotplugProc

        command: [root.script, "apply"]
        onExited: root.refresh()
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
            root.ignoreEventsUntil = Date.now() + 3000;
            root.refresh();
        }
    }
}
