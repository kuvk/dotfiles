import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings > Screen & Sleep: when the screen locks and the machine sleeps (Idle; a second pair
// on battery where there is one), and the night light's warmth and schedule (Night light)
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    SettingsSection {
        title: "Idle"

        Repeater {
            model: [
                { label: "Lock", key: "idleLock", battery: false },
                { label: "Sleep", key: "idleSuspend", battery: false },
                { label: "Lock on battery", key: "idleLockBattery", battery: true },
                { label: "Sleep on battery", key: "idleSuspendBattery", battery: true }
            ]

            SettingRow {
                id: idleRow

                required property var modelData

                visible: !modelData.battery || Battery.available
                label: modelData.label

                Stepper {
                    text: settings.minutesText(Config[idleRow.modelData.key])
                    onStep: d => Config[idleRow.modelData.key] = settings.cycle(settings.idleSteps, Config[idleRow.modelData.key], d)
                }
            }
        }
    }

    SettingsSection {
        title: "Night light"

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

        SettingRow {
            label: "Schedule"
            hint: "Holds until the next switch"

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

    // Stepping through several values applies only the last
    Timer {
        id: nightlightApply

        interval: 400
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprdori-nightlight", "apply"])
    }
}
