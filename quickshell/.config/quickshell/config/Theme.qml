pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The current theme's colors (~/.config/theme/current/quickshell.json, written by
// hyprdori-theme-set and watched, so a switch recolors the shell live), the states every
// control draws with, and sizes. Defaults below are Catppuccin's.
//
// Chrome is neutral: surfaces and controls are the text color at a low opacity (idle,
// hover, selected). Color means something: the accent for selected text and focus, each bar
// item in its own hue (Hues.qml), red for errors.
Singleton {
    id: root

    property var colors: ({})
    property string theme: "catppuccin"
    property string themeName: "Catppuccin"
    property string mode: "dark"
    // power menu icons for this theme (theme-icons.py), "" = use glyphs
    property string iconsDir: ""
    // the theme's own background image (hyprdori-theme-set): the wallpaper and lock screen while they follow the theme
    property string backgroundImage: ""
    // Set by hypr-gamemode.sh over IPC: opaque surfaces, square corners, no animations
    property bool gamemode: false

    // The theme's colors
    readonly property color background: colors.background ?? "#1e1e2e"
    readonly property color darkBackground: colors.dark_background ?? "#161622"
    readonly property color darkerBackground: colors.darker_background ?? "#101019"
    readonly property color lighterBackground: colors.lighter_background ?? "#313244"
    readonly property color foreground: colors.foreground ?? "#cdd6f4"
    readonly property color darkForeground: colors.dark_foreground ?? "#6c7086"
    readonly property color lightForeground: colors.light_foreground ?? "#bac2de"
    readonly property color brightForeground: colors.bright_foreground ?? "#cdd6f4"
    readonly property color accent: colors.accent ?? "#89b4fa"
    readonly property color selection: colors.selection ?? "#45475a"
    readonly property color muted: colors.muted ?? "#585b70"
    readonly property color red: colors.red ?? "#f38ba8"
    readonly property color yellow: colors.yellow ?? "#fab387"
    readonly property color orange: colors.orange ?? "#f6b6ab"
    readonly property color green: colors.green ?? "#a6e3a1"
    readonly property color cyan: colors.cyan ?? "#94e2d5"
    readonly property color blue: colors.blue ?? "#89b4fa"
    readonly property color magenta: colors.magenta ?? "#cba6f7"
    readonly property color brown: colors.brown ?? "#7b5b55"
    readonly property color brightRed: colors.bright_red ?? "#f38ba8"
    readonly property color brightYellow: colors.bright_yellow ?? "#f9e2af"
    readonly property color brightGreen: colors.bright_green ?? "#a6e3a1"
    readonly property color brightCyan: colors.bright_cyan ?? "#94e2d5"
    readonly property color brightBlue: colors.bright_blue ?? "#89b4fa"
    readonly property color brightMagenta: colors.bright_magenta ?? "#f5c2e7"

    // Text: secondary (captions, values) and dim (hints, things that are off)
    readonly property color subtext: mix(foreground, background, 0.25)
    readonly property color dimText: mix(foreground, background, 0.5)
    readonly property color faintText: mix(foreground, background, 0.65)
    // section labels and the values beside them in dropdowns (the text color darkened)
    readonly property color labelText: Qt.darker(foreground, 1.4)

    // States: the text color at a low opacity, the same for every control
    readonly property color idleFill: alpha(foreground, 0.04)
    readonly property color hoverFill: alpha(foreground, 0.08)
    readonly property color selectedFill: alpha(foreground, 0.18)
    readonly property color idleBorder: alpha(foreground, 0.4)
    readonly property color hoverBorder: alpha(foreground, 0.25)
    // controls: a hairline border while idle or hovered, none when selected
    readonly property int controlBorder: 1

    // Surfaces. Gamemode turns blur off in Hyprland, so everything goes opaque.
    readonly property color barBg: alpha(background, gamemode ? 1 : Config.barOpacity)
    // Settings > Style > Shell opacity: dropdowns, the launcher, Control Center, Settings and
    // the other shell windows (Hyprland leaves them opaque, rules.lua)
    readonly property color panelBg: alpha(background, gamemode ? 1 : Config.shellOpacity)
    // Behind full-screen overlays (power menu, pickers, network): the wallpaper dimmed and blurred
    readonly property color backdrop: alpha(darkerBackground, gamemode ? 1 : 0.75)
    readonly property color cardBg: idleFill
    readonly property color hoverBg: hoverFill
    // popups and dropdowns are framed in the accent, as Hyprland frames the focused window
    readonly property color border: accent
    readonly property int borderWidth: Config.borderWidth

    // Fonts. Settings > Fonts: text in the display font, or the terminals' (monoFont) with
    // "Monospace everywhere". Icons from Symbols Nerd Font, centered in buttons whatever the
    // font; without it, the font's own (a Nerd Font's proportional "Propo" variant when installed)
    readonly property string monoFont: Config.font || "JetBrainsMono Nerd Font"
    readonly property string font: Config.monoEverywhere ? monoFont : (Config.displayFont || "SF Pro Display")
    readonly property string iconFont: {
        const families = Qt.fontFamilies();
        if (families.includes("Symbols Nerd Font"))
            return "Symbols Nerd Font";
        const propo = monoFont.replace(/ (Mono|Propo)$/, "") + " Propo";
        return families.includes(propo) ? propo : monoFont;
    }

    // Text size in px from Displays (~/.config/hypr/monitors.json): the body text, 12 by
    // default. The other sizes scale with it; at 12: caption 10, small 11,
    // subtitle 13, title 14, heading 16, display 24 and 28, icons 14 (18 large; the bar's at the text size).
    property int textSize: 12
    readonly property real textScale: textSize / 12
    readonly property int fontSize: textSize
    readonly property int captionSize: Math.round(10 * textScale)
    readonly property int smallSize: Math.round(11 * textScale)
    readonly property int subtitleSize: Math.round(13 * textScale)
    readonly property int titleSize: Math.round(14 * textScale)
    readonly property int headingSize: Math.round(16 * textScale)
    readonly property int displaySize: Math.round(24 * textScale)
    readonly property int displayLargeSize: Math.round(28 * textScale)
    readonly property int iconSize: Math.round(14 * textScale)
    readonly property int iconLargeSize: Math.round(18 * textScale)
    // the bar: icons, workspaces and text all at the text size
    readonly property int barIconSize: textSize
    // the bar's height: 26 at 12 px
    readonly property int barHeight: Math.round(26 * textScale)
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

    // a blended toward b by amount (0..1)
    function mix(a: color, b: color, amount: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount, 1);
    }

    // A color by its name in the themes (accent, magenta, ...); older names saved in
    // Settings (mauve, peach, ...) find the color that took their place
    readonly property var formerNames: ({
            base: "background", mantle: "darkBackground", crust: "darkerBackground",
            surface0: "lighterBackground", surface1: "selection", surface2: "muted",
            overlay0: "faintText", overlay1: "dimText", overlay2: "subtext", subtext0: "subtext", subtext1: "subtext",
            text: "foreground", mauve: "magenta", pink: "brightMagenta", peach: "orange", teal: "cyan",
            sky: "brightCyan", sapphire: "cyan", lavender: "brightBlue", maroon: "brightRed",
            rosewater: "brightRed", flamingo: "red", accent2: "accent", accent3: "accent"
        })

    function named(name: string): color {
        const key = formerNames[name] ?? name.replace(/_(\w)/g, (m, c) => c.toUpperCase());
        const value = root[key];
        return value !== undefined && value !== null ? value : root.foreground;
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
                root.backgroundImage = data.background ?? "";
            } catch (e) {
                console.warn("Theme: could not parse", path, e);
            }
        }
        onLoadFailed: err => console.warn("Theme: no generated theme yet, run hyprdori-theme-set")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/monitors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.textSize = JSON.parse(text()).text_size ?? 12;
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
