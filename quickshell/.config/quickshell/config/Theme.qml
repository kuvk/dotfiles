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
    // power menu icons for this theme (theme-icons.py), "" = use glyphs
    property string iconsDir: ""
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
    // Highlights inside dropdowns, launchers and tooltips; their borders use accent
    readonly property color highlight: accent2

    // Surfaces. Gamemode turns blur off in Hyprland, so everything goes opaque.
    readonly property color barBg: alpha(base, gamemode ? 1 : Config.barOpacity)
    readonly property color panelBg: alpha(base, gamemode ? 1 : Config.panelOpacity)
    readonly property color cardBg: alpha(surface0, gamemode ? 1 : 0.6)
    readonly property color hoverBg: surface0
    readonly property color border: accent
    readonly property int borderWidth: Config.borderWidth

    // Metrics
    // Settings > Fonts. Text: the display font, or the Nerd Font with
    // "Nerd Fonts only". Icons: Symbols Nerd Font, or the Nerd Font's
    // proportional ("Propo") variant: in the monospaced variants wide icons
    // spill out of their cell and sit off-center in buttons.
    readonly property string nerdFamily: (Config.nerdFont || "JetBrainsMono Nerd Font").replace(/ (Mono|Propo)$/, "")
    readonly property string font: Config.nerdFontOnly ? (Config.nerdFont || nerdFamily) : (Config.displayFont || "SF Pro Display")
    readonly property string iconFont: {
        if (Config.nerdSymbols)
            return "Symbols Nerd Font";
        const propo = nerdFamily + " Propo";
        return Qt.fontFamilies().includes(propo) ? propo : nerdFamily;
    }
    readonly property string monoFont: Config.nerdFont || "JetBrainsMono Nerd Font"
    // Text size in px from the Displays panel (~/.config/hypr/monitors.json)
    property int textSize: 13
    readonly property int fontSize: textSize
    readonly property int iconSize: textSize + 1
    readonly property int barHeight: Math.max(34, Math.round(textSize * 2.6))
    // Floating bar (Settings > Bar): its own margin on the left, right and
    // top (the gap below it is Hyprland's outer gap); 0 for the full-width bar
    readonly property int barMargin: Config.barFloating ? Config.barMargin : 0
    // rounded like the other windows only while it floats (0 in Work-Game)
    readonly property int barRadius: barMargin > 0 ? radius : 0
    readonly property int radius: gamemode ? 0 : Config.radius
    readonly property int smallRadius: gamemode ? 0 : Math.max(0, Config.radius - 2)
    readonly property int spacing: 8
    readonly property int padding: 12
    readonly property int animDuration: gamemode || !Config.animations ? 0 : 150

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
                root.iconsDir = data.icons ?? "";
            } catch (e) {
                console.warn("Theme: could not parse", path, e);
            }
        }
        onLoadFailed: err => console.warn("Theme: no generated theme yet, run theme-set.py")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/monitors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.textSize = d.text_size ?? Math.round(13 * (d.text_scale ?? 1));
            } catch (e) {}
        }
    }

    FileView {
        path: "/tmp/hypr-gamemode"
        // missing simply means gamemode is off
        printErrors: false
        onLoaded: root.gamemode = true
        onLoadFailed: root.gamemode = false
    }
}
