import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Appearance
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    // Accent and accent2 for the running theme, from its own palette
    Repeater {
        model: [
            { role: "accent", label: "Accent" },
            { role: "accent2", label: "Second accent" },
            { role: "accent3", label: "Third accent" }
        ]

        ColumnLayout {
            id: accentRow

            required property var modelData
            readonly property string chosen: (Config.accentOverrides[Theme.theme] ?? {})[modelData.role] ?? ""

            function choose(name: string): void {
                const all = Object.assign({}, Config.accentOverrides);
                const mine = Object.assign({}, all[Theme.theme] ?? {});
                if (name)
                    mine[accentRow.modelData.role] = name;
                else
                    delete mine[accentRow.modelData.role];
                if (Object.keys(mine).length)
                    all[Theme.theme] = mine;
                else
                    delete all[Theme.theme];
                Config.accentOverrides = all;
                accentApply.restart();
            }

            Layout.fillWidth: true
            spacing: 4

            // "" is the theme's own
            ColorDropdown {
                label: accentRow.modelData.label
                hint: `In ${Theme.themeName}`
                defaultLabel: "Theme default"
                // the theme's own color is only known while it's in use
                defaultColor: accentRow.chosen === "" ? Theme[accentRow.modelData.role] : "transparent"
                names: catppuccin
                value: accentRow.chosen
                onPicked: name => accentRow.choose(name)
            }
        }
    }

    // The desktop follows the theme while it shows the theme's background
    // (picked in the wallpaper picker, or Theme's here); any other
    // wallpaper stays through theme changes
    SettingRow {
        label: "Wallpaper"
        hint: Config.wallpaperFollowsTheme ? "Follows the theme" : "Your own"

        TextButton {
            text: "Theme's"
            enabled: !Config.wallpaperFollowsTheme
            onClicked: {
                Config.wallpaperFollowsTheme = true;
                followApply.restart();
            }
        }
    }

    Timer {
        id: followApply

        interval: 800
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--follow-wallpaper"])
    }

    // Long enough for Config to save the choice; then the whole theme again
    Timer {
        id: accentApply

        interval: 800
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set"])
    }

    SettingRow {
        label: "Corner radius"
        normalOnly: true
        hint: "Windows, the shell and terminal apps"

        Stepper {
            text: `${Config.radius} px`
            onStep: d => Config.radius = settings.clamp(Config.radius + d, 0, 20)
        }
    }

    SettingRow {
        label: "Cursor"
        hint: "Restart open apps to apply"

        Stepper {
            text: Config.cursorTheme
            onStep: d => {
                Config.cursorTheme = settings.cycle(settings.cursorThemes, Config.cursorTheme, d);
                cursorApply.restart();
            }
        }
    }

    SettingRow {
        label: "Cursor size"

        Stepper {
            text: `${Config.cursorSize} px`
            onStep: d => {
                Config.cursorSize = settings.clamp(Config.cursorSize + d * 4, 16, 64);
                cursorApply.restart();
            }
        }
    }

    SettingRow {
        label: "Icons"
        hint: "Restart Qt apps to apply"

        Stepper {
            text: Config.iconTheme
            onStep: d => {
                Config.iconTheme = settings.cycle(settings.iconThemes, Config.iconTheme, d);
                iconApply.restart();
            }
        }
    }

    Timer {
        id: iconApply

        interval: 400
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--icons", Config.iconTheme])
    }

    Process {
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--icon-themes"]
        stdout: StdioCollector {
            onStreamFinished: settings.iconThemes = JSON.parse(text)
        }
    }

    // Stepping through several themes applies only the last
    Timer {
        id: cursorApply

        interval: 400
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--cursor", Config.cursorTheme, String(Config.cursorSize)])
    }

    Process {
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--cursors"]
        stdout: StdioCollector {
            onStreamFinished: settings.cursorThemes = JSON.parse(text)
        }
    }

    SettingRow {
        label: "Border width"

        Stepper {
            text: `${Config.borderWidth} px`
            onStep: d => Config.borderWidth = settings.clamp(Config.borderWidth + d, 0, 4)
        }
    }

    SettingRow {
        label: "Bar opacity"
        normalOnly: true
        hint: "No blur below 50%"

        Stepper {
            text: `${Math.round(Config.barOpacity * 100)}%`
            onStep: d => Config.barOpacity = Math.round(settings.clamp(Config.barOpacity + d * 0.05, 0.3, 1) * 100) / 100
        }
    }

    SettingRow {
        label: "Panel opacity"
        normalOnly: true
        hint: "Dropdowns, launchers, tooltips"

        Stepper {
            text: `${Math.round(Config.panelOpacity * 100)}%`
            onStep: d => Config.panelOpacity = Math.round(settings.clamp(Config.panelOpacity + d * 0.05, 0.5, 1) * 100) / 100
        }
    }

    SettingRow {
        label: "Active window opacity"
        normalOnly: true
        hint: "Fullscreen windows stay opaque"

        Stepper {
            text: `${Math.round(Config.activeOpacity * 100)}%`
            onStep: d => Config.activeOpacity = Math.round(settings.clamp(Config.activeOpacity + d * 0.01, 0.5, 1) * 100) / 100
        }
    }

    SettingRow {
        label: "Inactive window opacity"
        normalOnly: true

        Stepper {
            text: `${Math.round(Config.inactiveOpacity * 100)}%`
            onStep: d => Config.inactiveOpacity = Math.round(settings.clamp(Config.inactiveOpacity + d * 0.01, 0.5, 1) * 100) / 100
        }
    }

    SettingRow {
        label: "Blur"
        normalOnly: true
        hint: "Behind windows and the shell"

        Switch {
            checked: Config.blur
            onToggled: Config.blur = !Config.blur
        }
    }

    SettingRow {
        label: "Animations"
        normalOnly: true

        Switch {
            checked: Config.animations
            onToggled: Config.animations = !Config.animations
        }
    }
}
