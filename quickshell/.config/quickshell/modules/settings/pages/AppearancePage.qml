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

    // The running theme's accent: its own, or another of its colors (hyprdori-theme-set reads
    // accentOverrides; older saves hold { accent: name })
    ColumnLayout {
        id: accentRow

        readonly property var saved: Config.accentOverrides[Theme.theme]
        readonly property string chosen: typeof saved === "string" ? saved : (saved?.accent ?? "")

        function choose(name: string): void {
            const all = Object.assign({}, Config.accentOverrides);
            if (name)
                all[Theme.theme] = name;
            else
                delete all[Theme.theme];
            Config.accentOverrides = all;
            accentApply.restart();
        }

        Layout.fillWidth: true
        spacing: 4

        // "" is the theme's own
        ColorDropdown {
            id: accentPicker

            label: "Accent"
            hint: `In ${Theme.themeName}`
            defaultLabel: "Theme default"
            // the theme's own color is only known while it's in use
            defaultColor: accentRow.chosen === "" ? Theme.accent : "transparent"
            names: palette
            value: accentRow.chosen
            onPicked: name => accentRow.choose(name)
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

    SettingSlider {
        label: "Bar opacity"
        normalOnly: true
        hint: "No blur below 50%"
        from: 0.3
        value: Config.barOpacity
        onChanged: v => Config.barOpacity = v
    }

    SettingSlider {
        label: "Shell opacity"
        normalOnly: true
        hint: "Dropdowns, launchers, Control Center, Settings and the other shell windows"
        from: 0.5
        value: Config.shellOpacity
        onChanged: v => Config.shellOpacity = v
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
