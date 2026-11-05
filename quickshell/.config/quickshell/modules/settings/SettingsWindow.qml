import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings (gear in the Control Center, ALT+CTRL+P). Sections in a sidebar;
// changes apply immediately and are saved by Config.
FloatingWindow {
    id: root

    readonly property bool shown: Panels.settings
    readonly property var clockFormats: ["dddd HH:mm", "ddd HH:mm", "HH:mm", "ddd d MMM  HH:mm", "dddd h:mm AP"]
    readonly property var sections: [
        { id: "appearance", label: "Appearance", icon: Icons.palette },
        { id: "fonts", label: "Fonts", icon: Icons.font },
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

    visible: shown
    title: "Settings"
    color: Theme.panelBg
    implicitWidth: 780
    implicitHeight: 560

    // A regular window (floating and centered by a Hyprland rule, can be
    // tiled); closing it from Hyprland updates the panel state
    onClosed: Panels.settings = false

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        focus: root.shown
        Keys.onEscapePressed: Panels.settings = false

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Sidebar
            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 190
                color: Theme.alpha(Theme.mantle, 0.6)

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
                    id: settingsFlick

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: page.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar {
                        parent: settingsFlick
                        flick: settingsFlick
                    }

                    ColumnLayout {
                        id: page

                        // room for the scroll bar
                        width: settingsFlick.width - 14
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

                            // Modules per bar: the primary monitor's and the others'
                            StyledText {
                                Layout.topMargin: 8
                                Layout.fillWidth: true
                                text: "Modules on the primary monitor's bar and on the other bars. The clock is always shown."
                                color: Theme.overlay1
                                wrapMode: Text.Wrap
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 16
                                rowSpacing: 8

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Module"
                                    color: Theme.subtext0
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Primary"
                                    color: Theme.subtext0
                                    font.weight: Font.DemiBold
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Others"
                                    color: Theme.subtext0
                                    font.weight: Font.DemiBold
                                }

                                Repeater {
                                    model: Config.barModules

                                    StyledText {
                                        required property var modelData
                                        required property int index

                                        Layout.row: index + 1
                                        Layout.column: 0
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: Theme.text
                                    }
                                }

                                Repeater {
                                    model: Config.barModules

                                    Switch {
                                        required property var modelData
                                        required property int index

                                        Layout.row: index + 1
                                        Layout.column: 1
                                        Layout.alignment: Qt.AlignHCenter
                                        checked: Config.barShows(true, modelData.id)
                                        onToggled: Config.setBarModule(true, modelData.id, !checked)
                                    }
                                }

                                Repeater {
                                    model: Config.barModules

                                    Switch {
                                        required property var modelData
                                        required property int index

                                        Layout.row: index + 1
                                        Layout.column: 2
                                        Layout.alignment: Qt.AlignHCenter
                                        checked: Config.barShows(false, modelData.id)
                                        onToggled: Config.setBarModule(false, modelData.id, !checked)
                                    }
                                }
                            }
                        }

                        // ------------------------------------------------ Windows
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "windows"
                            spacing: 12

                            SettingRow {
                                label: "Window buttons"
                                hint: "Close button on the shell's windows (Settings, Displays)"

                                Switch {
                                    checked: Config.windowButtons
                                    onToggled: Config.windowButtons = !Config.windowButtons
                                }
                            }

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

                        // ------------------------------------------------ Fonts
                        ColumnLayout {
                            id: fontsPage

                            readonly property var families: Qt.fontFamilies()
                            // full Nerd Fonts, one entry per family (no Mono/Propo
                            // variants, no Symbols): letters and icons
                            readonly property var nerdFonts: families.filter(f => /Nerd Font$/.test(f) && !f.startsWith("Symbols Nerd Font"))
                            // everything else, for the display font
                            readonly property var displayFonts: families.filter(f => !/Nerd Font/.test(f))

                            Layout.fillWidth: true
                            visible: root.section === "fonts"
                            spacing: 12

                            // How the bar's text and icons look with these fonts
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: preview.implicitHeight + 24
                                radius: Theme.smallRadius
                                color: Theme.barBg

                                Row {
                                    id: preview

                                    anchors.centerIn: parent
                                    spacing: 12

                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Icons.arch
                                        color: Theme.accent2
                                        font.pixelSize: 17
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Qt.formatDateTime(Time.date, Config.clockFormat)
                                        font.weight: Font.DemiBold
                                    }

                                    Repeater {
                                        model: [Icons.music, Icons.coffee, Icons.bluetooth, Icons.font, Icons.cog, Icons.power]

                                        Icon {
                                            required property string modelData

                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData
                                            color: Theme.subtext1
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Terminals keep their own fonts (kitty.conf); these are for the bar, panels and the shell's windows."
                                color: Theme.overlay1
                                font.pixelSize: Theme.fontSize - 1
                                wrapMode: Text.Wrap
                            }

                            SettingRow {
                                label: "Nerd Fonts only"
                                hint: "Text uses the Nerd Font too; the display font is not used"

                                Switch {
                                    checked: Config.nerdFontOnly
                                    onToggled: Config.nerdFontOnly = !Config.nerdFontOnly
                                }
                            }

                            SettingRow {
                                label: "Use Nerd Symbols font"
                                hint: "Icons from Symbols Nerd Font; off: from the Nerd Font"

                                Switch {
                                    checked: Config.nerdSymbols
                                    onToggled: Config.nerdSymbols = !Config.nerdSymbols
                                }
                            }

                            StyledText {
                                Layout.topMargin: 4
                                text: "Nerd Font"
                                font.weight: Font.DemiBold
                            }

                            FontDropdown {
                                value: Config.nerdFont
                                options: fontsPage.nerdFonts
                                sample: Icons.arch + " " + Icons.cog + " 0O1lI"
                                onPicked: family => Config.nerdFont = family
                            }

                            StyledText {
                                Layout.topMargin: 4
                                text: "Display font"
                                font.weight: Font.DemiBold
                                opacity: Config.nerdFontOnly ? 0.4 : 1
                            }

                            FontDropdown {
                                enabled: !Config.nerdFontOnly
                                value: Config.displayFont
                                options: fontsPage.displayFonts
                                onPicked: family => Config.displayFont = family
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
