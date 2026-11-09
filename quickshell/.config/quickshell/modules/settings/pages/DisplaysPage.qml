import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.displays

// Settings > Displays: the display settings, as in the bar's Displays dropdown
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    DisplaysEditor {}
}
