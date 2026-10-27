pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colors come from ~/.config/theme/current/quickshell.json, written by
// ~/.config/scripts/theme-set.py. The file is watched, so switching themes
// recolors the shell live. Defaults below are Catppuccin Mocha.
Singleton {
    id: root

    property var colors: ({})
    property string theme: "catppuccin-mocha"
    property string themeName: "Catppuccin Mocha"
    property string mode: "dark"
    // Set by hypr-gamemode.sh over IPC: opaque surfaces, square corners, no animations
    property bool gamemode: false

    readonly property color rosewater: colors.rosewater ?? "#f5e0dc"
    readonly property color flamingo: colors.flamingo ?? "#f2cdcd"
    readonly property color pink: colors.pink ?? "#f5c2e7"
    readonly property color mauve: colors.mauve ?? "#cba6f7"
    readonly property color red: colors.red ?? "#f38ba8"
    readonly property color maroon: colors.maroon ?? "#eba0ac"
    readonly property color peach: colors.peach ?? "#fab387"
    readonly property color yellow: colors.yellow ?? "#f9e2af"
    readonly property color green: colors.green ?? "#a6e3a1"
    readonly property color teal: colors.teal ?? "#94e2d5"
    readonly property color sky: colors.sky ?? "#89dceb"
    readonly property color sapphire: colors.sapphire ?? "#74c7ec"
    readonly property color blue: colors.blue ?? "#89b4fa"
    readonly property color lavender: colors.lavender ?? "#b4befe"
    readonly property color text: colors.text ?? "#cdd6f4"
    readonly property color subtext1: colors.subtext1 ?? "#bac2de"
    readonly property color subtext0: colors.subtext0 ?? "#a6adc8"
    readonly property color overlay2: colors.overlay2 ?? "#9399b2"
    readonly property color overlay1: colors.overlay1 ?? "#7f849c"
    readonly property color overlay0: colors.overlay0 ?? "#6c7086"
    readonly property color surface2: colors.surface2 ?? "#585b70"
    readonly property color surface1: colors.surface1 ?? "#45475a"
    readonly property color surface0: colors.surface0 ?? "#313244"
    readonly property color base: colors.base ?? "#1e1e2e"
    readonly property color mantle: colors.mantle ?? "#181825"
    readonly property color crust: colors.crust ?? "#11111b"
    readonly property color accent: colors.accent ?? peach
    readonly property color accent2: colors.accent2 ?? blue

    // Surfaces
    readonly property color barBg: alpha(base, gamemode ? 1 : 0.8)
    readonly property color panelBg: alpha(base, gamemode ? 1 : 0.9)
    readonly property color cardBg: alpha(surface0, 0.6)
    readonly property color hoverBg: surface0
    readonly property color border: alpha(accent, 0.6)

    // Metrics
    readonly property string font: "SF Pro Display"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property int fontSize: 13
    readonly property int iconSize: 14
    readonly property int barHeight: 34
    readonly property int radius: gamemode ? 0 : 12
    readonly property int smallRadius: gamemode ? 0 : 8
    readonly property int spacing: 8
    readonly property int padding: 12
    readonly property int animDuration: gamemode ? 0 : 150

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function reload(): void {
        themeFile.reload();
    }

    FileView {
        id: themeFile

        path: Quickshell.env("HOME") + "/.config/theme/current/quickshell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.colors = data.colors ?? {};
                root.theme = data.theme ?? root.theme;
                root.themeName = data.name ?? root.themeName;
                root.mode = data.mode ?? "dark";
            } catch (e) {
                console.warn("Theme: could not parse", path, e);
            }
        }
        onLoadFailed: err => console.warn("Theme: no generated theme yet, run theme-set.py")
    }

    FileView {
        path: "/tmp/hypr-gamemode"
        onLoaded: root.gamemode = true
        onLoadFailed: root.gamemode = false
    }
}
