import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Night Light
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    SettingRow {
        label: "Temperature"
        hint: "Lower is warmer"

        Stepper {
            text: `${Config.nightlightTemperature} K`
            onStep: d => {
                Config.nightlightTemperature = settings.clamp(Config.nightlightTemperature + d * 100, 1000, 6500);
                nightlightApply.restart();
            }
        }
    }

    // Stepping through several values applies only the last
    Timer {
        id: nightlightApply

        interval: 400
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/nightlight-toggle.sh", "apply"])
    }

    SettingRow {
        label: "Schedule"
        hint: "A manual toggle holds until the next switch"

        Switch {
            checked: Config.nightlightSchedule
            onToggled: Config.nightlightSchedule = !Config.nightlightSchedule
        }
    }

    SettingRow {
        visible: Config.nightlightSchedule
        label: "Start"

        Stepper {
            text: Config.nightlightStart
            onStep: d => Config.nightlightStart = settings.stepTime(Config.nightlightStart, d * 15)
        }
    }

    SettingRow {
        visible: Config.nightlightSchedule
        label: "End"

        Stepper {
            text: Config.nightlightEnd
            onStep: d => Config.nightlightEnd = settings.stepTime(Config.nightlightEnd, d * 15)
        }
    }
}
