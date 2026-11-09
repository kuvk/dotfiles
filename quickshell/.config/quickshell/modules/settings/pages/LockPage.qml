import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Lock Screen
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

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

    // The login screen shares these settings. Long enough for Config to save them.
    Timer {
        id: loginApply

        interval: 800
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--login"])
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
