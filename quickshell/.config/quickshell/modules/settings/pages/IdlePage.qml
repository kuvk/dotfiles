import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Idle
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    StyledText {
        Layout.fillWidth: true
        text: "Minutes without input. Stay Awake and playing media hold both off."
        color: Theme.subtext
        wrapMode: Text.Wrap
    }

    Repeater {
        // the battery set only where there is a battery
        model: Battery.available ? [
            { title: "Plugged in", now: !Idle.onBattery, keys: ["idleLock", "idleSuspend"] },
            { title: "On battery", now: Idle.onBattery, keys: ["idleLockBattery", "idleSuspendBattery"] }
        ] : [
            { title: "", now: true, keys: ["idleLock", "idleSuspend"] }
        ]

        ColumnLayout {
            id: idleSet

            required property var modelData

            Layout.fillWidth: true
            spacing: 12

            // with no battery, no heading: the times show as they are
            SettingsSection {
                title: idleSet.modelData.title
                hint: idleSet.modelData.now ? "Now" : ""
                foldable: false

                Repeater {
                    model: [
                        { label: "Lock the screen", key: idleSet.modelData.keys[0] },
                        { label: "Sleep", key: idleSet.modelData.keys[1] }
                    ]

                    SettingRow {
                        id: idleRow

                        required property var modelData

                        label: modelData.label

                        Stepper {
                            text: settings.minutesText(Config[idleRow.modelData.key])
                            onStep: d => Config[idleRow.modelData.key] = settings.cycle(settings.idleSteps, Config[idleRow.modelData.key], d)
                        }
                    }
                }
            }
        }
    }
}
