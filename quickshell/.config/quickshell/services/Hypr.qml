pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Hyprland helpers. The config is Lua (hl.*), so dispatches are Lua
// expressions, same as `hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })'`.
Singleton {
    id: root

    property string layout: ""

    function dispatch(lua: string): void {
        Hyprland.dispatch(lua);
    }

    function focusWorkspace(id: int): void {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    function nextLayout(): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/switch-layout.sh"]);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout")
                devices.running = true;
        }
    }

    Process {
        id: devices

        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? [];
                    const kb = keyboards.find(k => k.main) ?? keyboards[0];
                    if (!kb)
                        return;
                    const layouts = (kb.layout ?? "").split(",");
                    const idx = kb.active_layout_index ?? -1;
                    root.layout = idx >= 0 && idx < layouts.length ? layouts[idx] : (kb.active_keymap ?? "").slice(0, 2).toLowerCase();
                } catch (e) {
                    console.warn("Hypr: could not parse hyprctl devices", e);
                }
            }
        }
    }
}
