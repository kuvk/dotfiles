import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// A color row in Settings > Lock Screen, with an opacity stepper when opacityKey is set;
// `edited` after a change (the window then rewrites the login screen's colors)
ColumnLayout {
    id: lockColor

    property string label
    property string key
    property string opacityKey: ""
    signal edited

    Layout.fillWidth: true
    spacing: 4

    ColorDropdown {
        label: lockColor.label
        value: Config[lockColor.key]
        onPicked: name => {
            Config[lockColor.key] = name;
            lockColor.edited();
        }
    }

    SettingRow {
        visible: lockColor.opacityKey !== ""
        label: "Opacity"

        Stepper {
            text: lockColor.opacityKey ? `${Config[lockColor.opacityKey]}%` : ""
            onStep: d => {
                Config[lockColor.opacityKey] = Math.max(0, Math.min(100, Config[lockColor.opacityKey] + d * 5));
                lockColor.edited();
            }
        }
    }
}
