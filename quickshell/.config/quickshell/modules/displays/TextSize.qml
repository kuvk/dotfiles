import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Text size for this combination of monitors (Displays)
// Global
RowLayout {
    // the Displays panel: its monitors, selection and actions
    required property var panel

    Layout.fillWidth: true
    spacing: 16

    StyledText {
        text: `${Icons.text}  Text size`
    }

    StyledText {
        Layout.fillWidth: true
        text: "Shell, GTK apps and kitty"
        color: Theme.overlay1
        font.pixelSize: Theme.fontSize - 2
    }

    // 9 .. 20 px, 13 is the default; kept per combination of monitors
    Stepper {
        text: `${panel.textSize} px${panel.textSize === 13 ? " (default)" : ""}`
        onStep: d => {
            panel.textSize = Math.max(9, Math.min(20, panel.textSize + d));
            panel.dirty = true;
        }
    }
}
