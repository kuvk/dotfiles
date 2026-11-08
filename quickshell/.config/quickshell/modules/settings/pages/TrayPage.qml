import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings > Tray & Player
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    SettingRow {
        label: "Tray icons"
        hint: "Blend with the theme, or one color"

        Stepper {
            text: Config.trayMonochrome ? "Monochrome" : (Config.trayTint ? "Tinted" : "Original")
            onStep: d => {
                const modes = ["original", "tinted", "mono"];
                const now = Config.trayMonochrome ? "mono" : (Config.trayTint ? "tinted" : "original");
                const next = settings.cycle(modes, now, d);
                Config.trayMonochrome = next === "mono";
                Config.trayTint = next === "tinted";
            }
        }
    }

    SettingRow {
        label: "Keep original colors for"
        hint: "App names, comma separated"

        Rectangle {
            implicitWidth: 220
            implicitHeight: 34
            radius: Theme.smallRadius
            color: Theme.cardBg
            border.color: keep.activeFocus ? Theme.accent : "transparent"
            border.width: Theme.borderWidth

            TextInput {
                id: keep

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                clip: true
                text: Config.trayKeepColors
                onEditingFinished: Config.trayKeepColors = text.trim()
            }
        }
    }

    SettingRow {
        label: "Audio visualizer in the player"
        hint: "Needs cava"

        Switch {
            checked: Config.cava
            onToggled: Config.cava = !Config.cava
        }
    }

    SettingRow {
        label: "Visualizer bars"

        Stepper {
            enabled: Config.cava
            text: `${Config.cavaBars}`
            onStep: d => Config.cavaBars = settings.clamp(Config.cavaBars + d * 4, 8, 64)
        }
    }
}
