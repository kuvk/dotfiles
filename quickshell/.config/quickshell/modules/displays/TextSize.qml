import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Text size for this combination of monitors: the shell, GTK and Qt apps and kitty. A setting
// slider that snaps to fixed steps, its size in px beside the label. Applied with the panel's
// other changes.
ColumnLayout {
    id: root

    // the Displays panel: its monitors, selection and actions
    required property var panel
    // the steps, in px; 12 is the default
    readonly property var stops: [9, 10, 11, 12, 14, 16, 20]
    // the step at the panel's size, or the nearest
    readonly property int index: {
        let best = 0;
        for (let i = 1; i < stops.length; i++)
            if (Math.abs(stops[i] - panel.textSize) < Math.abs(stops[best] - panel.textSize))
                best = i;
        return best;
    }

    Layout.fillWidth: true
    spacing: 6

    SettingSlider {
        label: "Text size"
        valueText: `${root.panel.textSize}px`
        to: root.stops.length - 1
        value: root.index
        onChanged: v => {
            const step = Math.round(v);
            if (root.stops[step] !== root.panel.textSize) {
                root.panel.textSize = root.stops[step];
                root.panel.dirty = true;
            }
        }
    }
}
