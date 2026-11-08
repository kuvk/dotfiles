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
                `--filename=${Quickshell.env("HOME")}/.local/share/dotfiles/backgrounds/default/`,
                "--file-filter=Images | *.png *.jpg *.jpeg *.webp"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const path = text.trim();
                    if (path === "")
                        return;
                    const theirs = path === Theme.background;
                    Config.lockFollowsTheme = theirs;
                    Config.lockImage = theirs ? "" : path;
                }
            }
        }
    }

    // Each part of the lock screen, and the login screen's power buttons.
    // Colors also go to the login screen (theme-set.py --login).
    SettingsSection {
        title: "Clock and date"
        hint: "Top right, on the lock and login screens"
        key: "lockClock"
        onEdited: loginApply.restart()

        LockColor {
            label: "Color"
            key: "lockClockColor"
            onEdited: loginApply.restart()
        }
    }

    SettingsSection {
        title: "Avatar"
        hint: "Your picture (~/.face)"
        key: "lockAvatar"
        onEdited: loginApply.restart()

        LockColor {
            label: "Outline"
            key: "lockAvatarColor"
            onEdited: loginApply.restart()
        }
    }

    SettingsSection {
        title: "Box"
        hint: "A card behind the avatar and password"
        key: "lockBox"
        onEdited: loginApply.restart()

        LockColor {
            label: "Outline"
            key: "lockBoxOutlineColor"
            onEdited: loginApply.restart()
        }

        LockColor {
            label: "Background"
            key: "lockBoxColor"
            opacityKey: "lockBoxOpacity"
            onEdited: loginApply.restart()
        }
    }

    SettingsSection {
        title: "Password field"
        hint: "Colors of the field and its text"

        Repeater {
            model: [
                { label: "Outline", key: "lockInputOutlineColor" },
                { label: "Background", key: "lockInputColor", opacity: "lockInputOpacity" },
                { label: "Typing dots", key: "lockDotsColor" },
                { label: "User name", key: "lockUserColor" },
                { label: "Text", key: "lockTextColor" },
                { label: "Checking password", key: "lockCheckColor" },
                { label: "Wrong password", key: "lockFailColor" },
                { label: "Caps Lock on", key: "lockCapsColor" }
            ]

            LockColor {
                required property var modelData

                label: modelData.label
                key: modelData.key
                opacityKey: modelData.opacity ?? ""
                onEdited: loginApply.restart()
            }
        }
    }

    SettingsSection {
        title: "Power buttons"
        hint: "On the login screen"

        LockColor {
            label: "Background"
            key: "lockPowerColor"
            opacityKey: "lockPowerOpacity"
            onEdited: loginApply.restart()
        }

        LockColor {
            label: "Icons"
            key: "lockPowerIconColor"
            onEdited: loginApply.restart()
        }

        LockColor {
            label: "Outline"
            key: "lockPowerOutlineColor"
            onEdited: loginApply.restart()
        }
    }

    // The login screen shares these colors. Long enough for Config to save them.
    Timer {
        id: loginApply

        interval: 800
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--login"])
    }

    TextButton {
        text: "Preview"
        onClicked: Panels.lockPreview = true
    }
}
