import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Settings (gear in the Control Center, ALT+CTRL+P). Sections in a sidebar;
// changes apply immediately and are saved by Config.
PanelWindow {
    id: root

    readonly property bool shown: Panels.settings
    readonly property var clockFormats: ["dddd HH:mm", "ddd HH:mm", "HH:mm", "ddd d MMM  HH:mm", "dddd h:mm AP"]
    readonly property var sections: [
        { id: "appearance", label: "Appearance", icon: Icons.palette },
        { id: "bar", label: "Bar", icon: Icons.sliders },
        { id: "windows", label: "Windows", icon: Icons.display },
        { id: "notifications", label: "Notifications", icon: Icons.bell },
        { id: "lock", label: "Lock Screen", icon: Icons.lock },
        { id: "tray", label: "Tray & Player", icon: Icons.music }
    ]
    property string section: "appearance"

    function cycle(list: var, value: var, step: int): var {
        const i = Math.max(0, list.indexOf(value));
        return list[(i + step + list.length) % list.length];
    }

    function clamp(v: real, lo: real, hi: real): real {
        return Math.max(lo, Math.min(hi, v));
    }

    screen: Panels.focusedScreen
    visible: shown
    color: "transparent"
    implicitWidth: 780
    implicitHeight: 560
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

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            spacing: 0

            // Sidebar
            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 190
                color: Theme.alpha(Theme.mantle, 0.6)
                topLeftRadius: Theme.radius
                bottomLeftRadius: Theme.radius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    StyledText {
                        Layout.bottomMargin: 10
                        Layout.leftMargin: 6
                        text: "Settings"
                        font.pixelSize: Theme.fontSize + 4
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: root.sections

                        MouseArea {
                            id: entry

                            required property var modelData
                            readonly property bool current: root.section === modelData.id

                            Layout.fillWidth: true
                            implicitHeight: 36
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.section = modelData.id

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.smallRadius
                                color: entry.current ? Theme.alpha(Theme.highlight, 0.2) : (entry.containsMouse ? Theme.hoverBg : "transparent")
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                spacing: 10

                                Icon {
                                    width: 18
                                    text: entry.modelData.icon
                                    color: entry.current ? Theme.highlight : Theme.subtext0
                                }

                                StyledText {
                                    text: entry.modelData.label
                                    color: entry.current ? Theme.highlight : Theme.text
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    TextButton {
                        Layout.fillWidth: true
                        text: "Reset to defaults"
                        onClicked: Config.reset()
                    }
                }
            }

            // Section content
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 12

                SectionHeader {
                    title: root.sections.find(s => s.id === root.section)?.label ?? ""

                    CloseButton {
                        onClicked: Panels.settings = false
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: page.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: page

                        width: parent.width
                        spacing: 12

                        // ------------------------------------------------ Appearance
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "appearance"
                            spacing: 12

                            SettingRow {
                                label: "Corner radius"
                                hint: "Hyprland windows use 6"

                                Stepper {
                                    text: `${Config.radius} px`
                                    onStep: d => Config.radius = root.clamp(Config.radius + d, 0, 20)
                                }
                            }

                            SettingRow {
                                label: "Border width"

                                Stepper {
                                    text: `${Config.borderWidth} px`
                                    onStep: d => Config.borderWidth = root.clamp(Config.borderWidth + d, 0, 4)
                                }
                            }

                            SettingRow {
                                label: "Bar opacity"
                                hint: "Below 50% Hyprland stops blurring it"

                                Stepper {
                                    text: `${Math.round(Config.barOpacity * 100)}%`
                                    onStep: d => Config.barOpacity = Math.round(root.clamp(Config.barOpacity + d * 0.05, 0.3, 1) * 100) / 100
                                }
                            }

                            SettingRow {
                                label: "Panel opacity"
                                hint: "Dropdowns, launchers, tooltips, Control Center"

                                Stepper {
                                    text: `${Math.round(Config.panelOpacity * 100)}%`
                                    onStep: d => Config.panelOpacity = Math.round(root.clamp(Config.panelOpacity + d * 0.05, 0.5, 1) * 100) / 100
                                }
                            }

                            SettingRow {
                                label: "Animations"

                                Switch {
                                    checked: Config.animations
                                    onToggled: Config.animations = !Config.animations
                                }
                            }
                        }

                        // ------------------------------------------------ Bar
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "bar"
                            spacing: 12

                            SettingRow {
                                label: "Clock"

                                Stepper {
                                    text: Qt.formatDateTime(Time.date, Config.clockFormat)
                                    onStep: d => Config.clockFormat = root.cycle(root.clockFormats, Config.clockFormat, d)
                                }
                            }

                            SettingRow {
                                label: "Weather"

                                Switch {
                                    checked: Config.showWeather
                                    onToggled: Config.showWeather = !Config.showWeather
                                }
                            }

                            SettingRow {
                                label: "Weather location"
                                hint: "City name, or empty to detect from your IP"

                                Rectangle {
                                    implicitWidth: 220
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
                                            text: "Automatic"
                                            color: Theme.overlay1
                                        }
                                    }
                                }
                            }

                            SettingRow {
                                label: "Temperature unit"

                                TextButton {
                                    text: Config.weatherFahrenheit ? "°F" : "°C"
                                    onClicked: Config.weatherFahrenheit = !Config.weatherFahrenheit
                                }
                            }
                        }

                        // ------------------------------------------------ Windows
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "windows"
                            spacing: 12

                            StyledText {
                                text: "Gaps between windows (inner) and to the screen edge (outer)."
                                color: Theme.overlay1
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            SettingRow {
                                label: "Inner gaps"

                                Stepper {
                                    text: `${Config.gapsIn} px`
                                    onStep: d => Config.gapsIn = root.clamp(Config.gapsIn + d, 0, 40)
                                }
                            }

                            SettingRow {
                                label: "Outer gaps"

                                Stepper {
                                    text: `${Config.gapsOut} px`
                                    onStep: d => Config.gapsOut = root.clamp(Config.gapsOut + d, 0, 60)
                                }
                            }

                            SettingRow {
                                label: "Inner gaps in Work-Game Mode"

                                Stepper {
                                    text: `${Config.gameGapsIn} px`
                                    onStep: d => Config.gameGapsIn = root.clamp(Config.gameGapsIn + d, 0, 40)
                                }
                            }

                            SettingRow {
                                label: "Outer gaps in Work-Game Mode"

                                Stepper {
                                    text: `${Config.gameGapsOut} px`
                                    onStep: d => Config.gameGapsOut = root.clamp(Config.gameGapsOut + d, 0, 60)
                                }
                            }
                        }

                        // ------------------------------------------------ Notifications
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "notifications"
                            spacing: 12

                            SettingRow {
                                label: "Popup timeout"
                                hint: "Critical notifications stay until closed"

                                Stepper {
                                    text: `${Config.notificationTimeout} s`
                                    onStep: d => Config.notificationTimeout = root.clamp(Config.notificationTimeout + d, 2, 60)
                                }
                            }
                        }

                        // ------------------------------------------------ Lock screen
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "lock"
                            spacing: 12

                            SettingRow {
                                label: "Digital rain"

                                Switch {
                                    checked: Config.lockMatrix
                                    onToggled: Config.lockMatrix = !Config.lockMatrix
                                }
                            }

                            SettingRow {
                                label: "Blur the desktop behind it"
                                hint: "Off: fully opaque"

                                Switch {
                                    checked: Config.lockBlur
                                    onToggled: Config.lockBlur = !Config.lockBlur
                                }
                            }

                            Repeater {
                                model: [
                                    { label: "Clock and date", key: "lockClockColor" },
                                    { label: "Digital rain", key: "lockRainColor" },
                                    { label: "Outlines and avatar ring", key: "lockOutlineColor" },
                                    { label: "Typing dots and user name", key: "lockDotsColor" },
                                    { label: "Text", key: "lockTextColor" }
                                ]

                                ColumnLayout {
                                    id: colorRow

                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 4

                                    StyledText {
                                        text: colorRow.modelData.label
                                    }

                                    ColorChoice {
                                        value: Config[colorRow.modelData.key]
                                        onPicked: name => Config[colorRow.modelData.key] = name
                                    }
                                }
                            }

                            TextButton {
                                text: "Preview (locks the screen)"
                                onClicked: {
                                    Panels.closeAll();
                                    Lock.lock();
                                }
                            }
                        }

                        // ------------------------------------------------ Tray & player
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "tray"
                            spacing: 12

                            SettingRow {
                                label: "Tray icons"
                                hint: "Tinted blends them toward the theme, monochrome draws them in one color"

                                Stepper {
                                    text: Config.trayMonochrome ? "Monochrome" : (Config.trayTint ? "Tinted" : "Original")
                                    onStep: d => {
                                        const modes = ["original", "tinted", "mono"];
                                        const now = Config.trayMonochrome ? "mono" : (Config.trayTint ? "tinted" : "original");
                                        const next = root.cycle(modes, now, d);
                                        Config.trayMonochrome = next === "mono";
                                        Config.trayTint = next === "tinted";
                                    }
                                }
                            }

                            SettingRow {
                                label: "Keep original colors for"
                                hint: "Tray apps whose icon color means something, comma separated"

                                Rectangle {
                                    implicitWidth: 220
                                    implicitHeight: 34
                                    radius: Theme.smallRadius
                                    color: Theme.cardBg
                                    border.color: keep.activeFocus ? Theme.highlight : "transparent"
                                    border.width: Theme.borderWidth

                                    TextInput {
                                        id: keep

                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.text
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
                                    onStep: d => Config.cavaBars = root.clamp(Config.cavaBars + d * 4, 8, 64)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
