import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Style: what the shell and Hyprland share (System), the shell's own look (Shell),
// Hyprland's windows (Hyprland), and the lock and login screens (Lock screen)
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    // once the choice is saved (Config writes it on change), which hyprdori-theme-set reads
    Timer {
        id: followApply

        interval: 150
        // the theme's background again with the switch's animation, as the wallpaper picker's
        onTriggered: SwitchFx.run([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--follow-wallpaper"], 1, 100)
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

    // The lock screen's look, which the login screen shares
    SettingsSection {
        title: "Lock screen"
        hint: "Applies to login screen"

        // The theme's background (it changes with the theme) until the user chooses another image,
        // as Style > Background; choosing the theme's own follows the theme again. The login
        // screen shows the same.
        SettingRow {
            id: lockBackground

            readonly property bool theirs: Config.lockFollowsTheme || Config.lockImage === ""

            label: "Background"
            hint: theirs ? "Theme's default active" : "User's choice active"

            TextButton {
                text: lockBackground.theirs ? "Choose" : "Theme's"
                onClicked: {
                    if (lockBackground.theirs) {
                        lockImagePicker.running = true;
                    } else {
                        Config.lockFollowsTheme = true;
                        Config.lockImage = "";
                    }
                }
            }

            Process {
                id: lockImagePicker

                command: ["zenity", "--file-selection", "--title=Lock screen background",
                    `--filename=${Quickshell.env("HOME")}/.local/share/hyprdori/backgrounds/default/`,
                    "--file-filter=Images | *.png *.jpg *.jpeg *.webp"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const path = text.trim();
                        if (path === "")
                            return;
                        const theirs = path === Theme.backgroundImage;
                        Config.lockFollowsTheme = theirs;
                        Config.lockImage = theirs ? "" : path;
                    }
                }
            }
        }

        // Also on the login screen (hyprdori-theme-set --login); the colors are the theme's
        SettingRow {
            label: "Avatar"
            hint: "Your picture (~/.face)"

            Switch {
                checked: Config.lockAvatar
                onToggled: {
                    Config.lockAvatar = !Config.lockAvatar;
                    loginApply.restart();
                }
            }
        }

        // The boot splash draws its field when it's built: theme-boot.sh, which the button runs
        SettingRow {
            label: "Rounded corners"

            Switch {
                checked: Config.lockRounded
                onToggled: {
                    Config.lockRounded = !Config.lockRounded;
                    loginApply.restart();
                    settings.bootStale = true;
                }
            }
        }

        SettingSlider {
            label: "Password field opacity"
            value: Config.lockInputOpacity / 100
            onChanged: v => {
                Config.lockInputOpacity = Math.round(v * 1000) / 10;
                loginApply.restart();
            }
        }

        SettingSlider {
            label: "Power buttons opacity"
            value: Config.lockPowerOpacity / 100
            onChanged: v => {
                Config.lockPowerOpacity = Math.round(v * 1000) / 10;
                loginApply.restart();
            }
        }

        RowLayout {
            spacing: 8

            TextButton {
                text: "Preview"
                onClicked: Panels.lockPreview = true
            }

            // After a corner change: the boot splash is rebuilt with it (asks for the password)
            TextButton {
                visible: settings.bootStale
                text: "Update boot splash"
                onClicked: {
                    settings.bootStale = false;
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-boot.sh", "--window"]);
                }
            }
        }
    }

    // The login screen shares these settings. Long enough for Config to save them.
    Timer {
        id: loginApply

        interval: 800
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--login"])
    }
}
