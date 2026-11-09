import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Style: what the shell and Hyprland share (System), the shell's own look (Shell)
// and Hyprland's windows (Hyprland)
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

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

    SettingsSection {
        title: "System"
        foldable: false

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

        // The desktop follows the theme while it shows the theme's background; Choose opens the
        // wallpaper picker, and any other wallpaper stays through theme changes
        SettingRow {
            label: "Background"
            hint: Config.wallpaperFollowsTheme ? "Theme's default active" : "User's choice active"

            TextButton {
                text: Config.wallpaperFollowsTheme ? "Choose" : "Theme's"
                onClicked: {
                    if (Config.wallpaperFollowsTheme) {
                        Panels.toggleWallpapers("static");
                    } else {
                        Config.wallpaperFollowsTheme = true;
                        followApply.restart();
                    }
                }
            }
        }

        SettingRow {
            label: "Corner radius"
            normalOnly: true

            Stepper {
                text: `${Config.radius} px`
                onStep: d => Config.radius = settings.clamp(Config.radius + d, 0, 20)
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

        SettingRow {
            label: "Blur"
            normalOnly: true

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

        SettingRow {
            label: "Window buttons"

            Switch {
                checked: Config.windowButtons
                onToggled: {
                    Config.windowButtons = !Config.windowButtons;
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--window-buttons", Config.windowButtons ? "on" : "off"]);
                }
            }
        }
    }

    SettingsSection {
        title: "Shell"
        foldable: false

        SettingSlider {
            label: "Bar opacity"
            normalOnly: true
            from: 0.3
            value: Config.barOpacity
            onChanged: v => Config.barOpacity = v
        }

        SettingSlider {
            label: "Shell opacity"
            normalOnly: true
            from: 0.5
            value: Config.shellOpacity
            onChanged: v => Config.shellOpacity = v
        }

        SettingRow {
            label: "Shadow"
            normalOnly: true

            Switch {
                checked: Config.shadow
                onToggled: Config.shadow = !Config.shadow
            }
        }

        SettingRow {
            label: "Notification timeout"
            hint: "Critical ones stay until closed"

            Stepper {
                text: `${Config.notificationTimeout} s`
                onStep: d => Config.notificationTimeout = settings.clamp(Config.notificationTimeout + d, 2, 60)
            }
        }
    }

    SettingsSection {
        title: "Hyprland"
        foldable: false

        SettingSlider {
            label: "Active window opacity"
            normalOnly: true
            from: 0.5
            value: Config.activeOpacity
            onChanged: v => Config.activeOpacity = v
        }

        SettingSlider {
            label: "Inactive window opacity"
            normalOnly: true
            from: 0.5
            value: Config.inactiveOpacity
            onChanged: v => Config.inactiveOpacity = v
        }

        SettingRow {
            label: "Inner gaps"
            normalOnly: true

            Stepper {
                text: `${Config.gapsIn} px`
                onStep: d => Config.gapsIn = settings.clamp(Config.gapsIn + d, 0, 40)
            }
        }
        SettingRow {
            label: "Outer gaps"
            normalOnly: true

            Stepper {
                text: `${Config.gapsOut} px`
                onStep: d => Config.gapsOut = settings.clamp(Config.gapsOut + d, 0, 60)
            }
        }
        SettingRow {
            label: "Inner gaps in Work-Game"

            Stepper {
                text: `${Config.gameGapsIn} px`
                onStep: d => Config.gameGapsIn = settings.clamp(Config.gameGapsIn + d, 0, 40)
            }
        }
        SettingRow {
            label: "Outer gaps in Work-Game"

            Stepper {
                text: `${Config.gameGapsOut} px`
                onStep: d => Config.gameGapsOut = settings.clamp(Config.gameGapsOut + d, 0, 60)
            }
        }
    }
}
