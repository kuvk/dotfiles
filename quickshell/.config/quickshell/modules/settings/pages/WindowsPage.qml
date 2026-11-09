import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Windows
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    SettingRow {
        label: "Window buttons"
        hint: "Close button on shell and GTK windows"

        Switch {
            checked: Config.windowButtons
            onToggled: {
                Config.windowButtons = !Config.windowButtons;
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-theme-set", "--window-buttons", Config.windowButtons ? "on" : "off"]);
            }
        }
    }

    SettingRow {
        label: "Border width"

        Stepper {
            text: `${Config.borderWidth} px`
            onStep: d => Config.borderWidth = settings.clamp(Config.borderWidth + d, 0, 4)
        }
    }

    SettingSlider {
        label: "Active window opacity"
        normalOnly: true
        hint: "Other apps' windows; browsers and fullscreen windows stay opaque"
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
        label: "Blur"
        normalOnly: true
        hint: "Behind windows and the shell"

        Switch {
            checked: Config.blur
            onToggled: Config.blur = !Config.blur
        }
    }

    StyledText {
        text: "Inner: between windows. Outer: to the screen edge."
        color: Theme.dimText
        wrapMode: Text.Wrap
        Layout.fillWidth: true
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
