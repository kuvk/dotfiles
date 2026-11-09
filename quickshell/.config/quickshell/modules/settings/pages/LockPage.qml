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

    // The theme's background (it changes with the theme) until the user chooses
    // another image; choosing the theme's own follows the theme again.
    // The login screen shows the same.
    SettingsSection {
        title: "Background"
        hint: Config.lockFollowsTheme || Config.lockImage === "" ? "The theme's, also on the login screen" : Config.lockImage.slice(Config.lockImage.lastIndexOf("/") + 1)
        controls: [
            TextButton {
                visible: !Config.lockFollowsTheme && Config.lockImage !== ""
                text: "Theme's"
                onClicked: {
                    Config.lockFollowsTheme = true;
                    Config.lockImage = "";
                }
            },
            TextButton {
                text: "Choose…"
                onClicked: lockImagePicker.running = true
            }
        ]

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

    // What the lock screen shows, also on the login screen (hyprdori-theme-set --login); the
    // colors are the theme's
    SettingsSection {
        title: "Clock and date"
        hint: "Top right, on the lock and login screens"
        key: "lockClock"
        onEdited: loginApply.restart()
    }

    SettingsSection {
        title: "Avatar"
        hint: "Your picture (~/.face)"
        key: "lockAvatar"
        onEdited: loginApply.restart()
    }

    SettingsSection {
        title: "Box"
        hint: "A card behind the avatar and password"
        key: "lockBox"
        onEdited: loginApply.restart()

        SettingSlider {
            label: "Box opacity"
            value: Config.lockBoxOpacity / 100
            onChanged: v => {
                Config.lockBoxOpacity = Math.round(v * 1000) / 10;
                loginApply.restart();
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
        hint: "On the login screen"
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

    TextButton {
        text: "Preview"
        onClicked: Panels.lockPreview = true
    }
}
