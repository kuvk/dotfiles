import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Shell preferences (the gear in the control center). Changes apply
// immediately and are saved by Config.
PanelWindow {
    id: root

    readonly property bool shown: Panels.settings
    readonly property var clockFormats: ["dddd HH:mm", "ddd HH:mm", "HH:mm", "ddd d MMM  HH:mm", "dddd h:mm AP"]

    function cycle(list: var, value: var, step: int): var {
        const i = Math.max(0, list.indexOf(value));
        return list[(i + step + list.length) % list.length];
    }

    screen: Panels.focusedScreen
    visible: shown
    color: "transparent"
    implicitWidth: 560
    implicitHeight: content.implicitHeight + 32
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.shown
        windows: [root]
        onCleared: Panels.settings = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        radius: Theme.radius
        border.color: Theme.border
        border.width: Theme.borderWidth
        focus: root.shown
        Keys.onEscapePressed: Panels.settings = false

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            SectionHeader {
                title: "Settings"

                CloseButton {
                    onClicked: Panels.settings = false
                }
            }

            StyledText {
                text: "Appearance"
                color: Theme.highlight
                font.weight: Font.Bold
            }

            SettingRow {
                label: "Corner radius"
                hint: "Hyprland windows use 6"

                Stepper {
                    text: `${Config.radius} px`
                    onStep: d => Config.radius = Math.max(0, Math.min(20, Config.radius + d))
                }
            }

            SettingRow {
                label: "Border width"

                Stepper {
                    text: `${Config.borderWidth} px`
                    onStep: d => Config.borderWidth = Math.max(0, Math.min(4, Config.borderWidth + d))
                }
            }

            SettingRow {
                label: "Bar opacity"
                hint: "Below 50% Hyprland stops blurring it"

                Stepper {
                    text: `${Math.round(Config.barOpacity * 100)}%`
                    onStep: d => Config.barOpacity = Math.round(Math.max(0.3, Math.min(1, Config.barOpacity + d * 0.05)) * 100) / 100
                }
            }

            SettingRow {
                label: "Panel opacity"
                hint: "Dropdowns, launchers, tooltips, control center"

                Stepper {
                    text: `${Math.round(Config.panelOpacity * 100)}%`
                    onStep: d => Config.panelOpacity = Math.round(Math.max(0.5, Math.min(1, Config.panelOpacity + d * 0.05)) * 100) / 100
                }
            }

            SettingRow {
                label: "Animations"

                Switch {
                    checked: Config.animations
                    onToggled: Config.animations = !Config.animations
                }
            }

            StyledText {
                Layout.topMargin: 6
                text: "Bar"
                color: Theme.highlight
                font.weight: Font.Bold
            }

            SettingRow {
                label: "Clock"

                Stepper {
                    text: Qt.formatDateTime(Time.date, Config.clockFormat)
                    onStep: d => Config.clockFormat = root.cycle(root.clockFormats, Config.clockFormat, d)
                }
            }

            SettingRow {
                label: "Weather"
                hint: "City name, or empty to detect from your IP"

                Switch {
                    checked: Config.showWeather
                    onToggled: Config.showWeather = !Config.showWeather
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Theme.smallRadius
                    color: Theme.cardBg
                    border.color: location.activeFocus ? Theme.highlight : "transparent"
                    border.width: Theme.borderWidth

                    TextInput {
                        id: location

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        clip: true
                        text: Config.weatherLocation
                        onEditingFinished: Config.weatherLocation = text.trim()

                        StyledText {
                            anchors.fill: parent
                            visible: location.text === "" && !location.activeFocus
                            text: "Automatic location"
                            color: Theme.overlay1
                        }
                    }
                }

                TextButton {
                    text: Config.weatherFahrenheit ? "°F" : "°C"
                    onClicked: Config.weatherFahrenheit = !Config.weatherFahrenheit
                }
            }

            StyledText {
                Layout.topMargin: 6
                text: "Notifications and lock screen"
                color: Theme.highlight
                font.weight: Font.Bold
            }

            SettingRow {
                label: "Popup timeout"
                hint: "Critical notifications stay until closed"

                Stepper {
                    text: `${Config.notificationTimeout} s`
                    onStep: d => Config.notificationTimeout = Math.max(2, Math.min(60, Config.notificationTimeout + d))
                }
            }

            SettingRow {
                label: "Digital rain"

                Switch {
                    checked: Config.lockMatrix
                    onToggled: Config.lockMatrix = !Config.lockMatrix
                }
            }

            SettingRow {
                label: "Blur desktop behind the lock screen"

                Switch {
                    checked: Config.lockBlur
                    onToggled: Config.lockBlur = !Config.lockBlur
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: "Reset to defaults"
                    onClicked: Config.reset()
                }
            }
        }
    }
}
