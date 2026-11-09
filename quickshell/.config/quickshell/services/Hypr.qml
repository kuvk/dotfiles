pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Hyprland helpers. With a Lua config (hl.*), dispatches are Lua expressions,
// same as `hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })'`.
Singleton {
    id: root

    property string layout: ""
    property string layoutName: ""

    function dispatch(lua: string): void {
        Hyprland.dispatch(lua);
    }

    function focusWorkspace(id: int): void {
        dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = ${id} })` : `workspace ${id}`);
    }

    // Window gaps, corners, opacity and blur from Settings, at once; hyprdori-theme-set --hypr
    // writes them to Hyprland's generated theme.lua as well, so it starts with them.
    // Work-Game has its own gaps; its square corners, opaque windows and no blur come from
    // hypr-gamemode.sh, which a config reload undoes, so it runs again then (restyle).
    function applyLook(): void {
        const inner = Theme.gamemode ? Config.gameGapsIn : Config.gapsIn;
        const outer = Theme.gamemode ? Config.gameGapsOut : Config.gapsOut;
        const look = Theme.gamemode ? "" : `, decoration = { rounding = ${Config.radius}, active_opacity = ${Config.activeOpacity}, inactive_opacity = ${Config.inactiveOpacity}, blur = { enabled = ${Config.blur} } }`;
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ general = { gaps_in = ${inner}, gaps_out = ${outer} }${look} })`]);
    }

    readonly property string lookKey: [Theme.gamemode, Config.gapsIn, Config.gapsOut, Config.gameGapsIn, Config.gameGapsOut, Config.radius, Config.activeOpacity, Config.inactiveOpacity, Config.blur].join(",")
    onLookKeyChanged: gapsDelay.restart()
    Component.onCompleted: gapsDelay.restart()

    // the normal look, for the next start; long enough for Config to save it
    readonly property string savedKey: [Config.gapsIn, Config.gapsOut, Config.radius, Config.activeOpacity, Config.inactiveOpacity, Config.blur].join(",")
    onSavedKeyChanged: saveDelay.restart()

    Timer {
        id: saveDelay

        interval: 1000
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--hypr"])
    }

    Timer {
        id: gapsDelay

        interval: 300
        onTriggered: root.applyLook()
    }

    // The shell's own windows stay floating: Hyprland has no rule that forbids
    // tiling, so when one is tiled (changefloatingmode ADDRESS,0) it is
    // reopened, and the floating rule (rules.lua) applies again
    readonly property var shellWindows: ({ "Settings": "settings", "Keybindings": "keybinds" })

    function keepFloating(data: string): void {
        const [address, floating] = data.split(",");
        if (floating !== "0")
            return;
        const norm = a => String(a ?? "").replace(/^0x/, "");
        let toplevel = null;
        const all = Hyprland.toplevels.values;
        for (let i = 0; i < all.length; i++) {
            if (norm(all[i].address) === norm(address))
                toplevel = all[i];
        }
        const flag = toplevel ? shellWindows[toplevel.title] : undefined;
        const cls = toplevel?.lastIpcObject?.class;
        if (!flag || (cls && cls !== "org.quickshell"))
            return;
        Panels[flag] = false;
        Qt.callLater(() => Panels[flag] = true);
    }

    function nextLayout(): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/switch-layout.sh"]);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout")
                devices.running = true;
            // a reload resets the gaps, corners and blur to hyprland's config
            else if (event.name === "configreloaded") {
                gapsDelay.restart();
                if (Theme.gamemode)
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/hypr-gamemode.sh", "restyle"]);
            }
            else if (event.name === "changefloatingmode")
                root.keepFloating(event.data);
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
                    root.layoutName = kb.active_keymap ?? "";
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
