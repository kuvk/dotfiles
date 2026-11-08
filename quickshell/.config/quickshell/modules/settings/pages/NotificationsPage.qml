import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Notifications
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    SettingRow {
        label: "Popup timeout"
        hint: "Critical ones stay until closed"

        Stepper {
            text: `${Config.notificationTimeout} s`
            onStep: d => Config.notificationTimeout = settings.clamp(Config.notificationTimeout + d, 2, 60)
        }
    }

    SettingRow {
        label: "Border"
        hint: "Accent outline on screen"

        Switch {
            checked: Config.notificationBorder
            onToggled: Config.notificationBorder = !Config.notificationBorder
        }
    }

    SettingRow {
        label: "Shadow"
        normalOnly: true

        Switch {
            checked: Config.notificationShadow
            onToggled: Config.notificationShadow = !Config.notificationShadow
        }
    }
}
