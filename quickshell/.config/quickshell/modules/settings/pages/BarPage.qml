import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings > Bar: the bar's look, clock, weather, tray and player (General), and which modules
// each connected monitor's bar shows (Per monitor)
ColumnLayout {
    // the Settings window: its helpers (clamp, cycle, minutesText, ...) and shared state
    required property var settings

    Layout.fillWidth: true
    spacing: 12

    SettingsSection {
        title: "General"

        SettingRow {
            label: "Floating bar"

            Switch {
                checked: Config.barFloating
                onToggled: Config.barFloating = !Config.barFloating
            }
        }

        SettingRow {
            visible: Config.barFloating
            label: "Bar margin"

            Stepper {
                text: `${Config.barMargin} px`
                onStep: d => Config.barMargin = settings.clamp(Config.barMargin + d * 2, 0, 40)
            }
        }

        SettingRow {
            label: "Clock"

            Stepper {
                text: Qt.formatDateTime(Time.date, Config.clockFormat)
                onStep: d => Config.clockFormat = settings.cycle(settings.clockFormats, Config.clockFormat, d)
            }
        }

        SettingRow {
            label: "Weather location"

            InputField {
                Layout.fillWidth: false
                implicitWidth: Math.round(220 * Theme.textScale)
                placeholder: "Automatic"
                text: Config.weatherLocation
                onEdited: value => Config.weatherLocation = value
            }
        }

        SettingRow {
            label: "Temperature unit"

            TextButton {
                text: Config.weatherFahrenheit ? "°F" : "°C"
                onClicked: Config.weatherFahrenheit = !Config.weatherFahrenheit
            }
        }

        SettingRow {
            label: "Tray icons"

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
            label: "Tray apps in their own colors"

            InputField {
                Layout.fillWidth: false
                implicitWidth: Math.round(220 * Theme.textScale)
                placeholder: "App names, with commas"
                text: Config.trayKeepColors
                onEdited: value => Config.trayKeepColors = value
            }
        }

        SettingRow {
            label: "Player visualizer"

            Switch {
                checked: Config.cava
                onToggled: Config.cava = !Config.cava
            }
        }

        SettingRow {
            visible: Config.cava
            label: "Visualizer bars"

            Stepper {
                text: `${Config.cavaBars}`
                onStep: d => Config.cavaBars = settings.clamp(Config.cavaBars + d * 4, 8, 64)
            }
        }
    }

    // A column per connected monitor; one without a choice yet shows every module
    SettingsSection {
        title: "Per monitor"

        GridLayout {
            Layout.fillWidth: true
            columns: Quickshell.screens.length + 1
            columnSpacing: 16
            rowSpacing: 12

            Caption {
                Layout.fillWidth: true
                text: "Module"
            }

            Repeater {
                model: Quickshell.screens

                Caption {
                    required property ShellScreen modelData

                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.name
                }
            }

            Repeater {
                model: Config.barModules

                // the module's name, then its switch on each monitor
                Caption {
                    required property var modelData
                    required property int index

                    Layout.row: index + 1
                    Layout.column: 0
                    Layout.fillWidth: true
                    text: modelData.label
                }
            }

            Repeater {
                model: Quickshell.screens.length * Config.barModules.length

                Switch {
                    required property int index
                    readonly property var module: Config.barModules[Math.floor(index / Quickshell.screens.length)]
                    readonly property string monitor: Quickshell.screens[index % Quickshell.screens.length]?.name ?? ""

                    Layout.row: Math.floor(index / Quickshell.screens.length) + 1
                    Layout.column: index % Quickshell.screens.length + 1
                    Layout.alignment: Qt.AlignHCenter
                    checked: Config.barShows(monitor, module.id)
                    onToggled: Config.setBarModule(monitor, module.id, !checked)
                }
            }
        }
    }
}
