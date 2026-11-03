import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// An on/off row in Settings > Lock Screen for a Config property
SettingRow {
    id: lockToggle

    property string key
    signal edited

    Switch {
        checked: Config[lockToggle.key]
        onToggled: {
            Config[lockToggle.key] = !Config[lockToggle.key];
            lockToggle.edited();
        }
    }
}
