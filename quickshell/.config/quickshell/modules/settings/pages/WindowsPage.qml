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
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--window-buttons", Config.windowButtons ? "on" : "off"]);
            }
        }
    }

    StyledText {
        text: "Inner: between windows. Outer: to the screen edge."
        color: Theme.overlay1
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
