import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Settings (gear in the Control Center, SUPER+CTRL+S). Sections in a sidebar;
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
        { id: "idle", label: "Idle", icon: Icons.bed },
        { id: "nightlight", label: "Night Light", icon: Icons.nightlight },
        { id: "tray", label: "Tray & Player", icon: Icons.music }
    ]
    property string section: "appearance"
    property var cursorThemes: ["Adwaita"]
    property var iconThemes: ["Papirus"]

    function cycle(list: var, value: var, step: int): var {
        const i = Math.max(0, list.indexOf(value));
        return list[(i + step + list.length) % list.length];
    }

    // Settings > Idle: minutes, 0 is never
    readonly property var idleSteps: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180]

    function minutesText(minutes: int): string {
        if (minutes === 0)
            return "Never";
        if (minutes < 60)
            return `${minutes} min`;
        return `${Math.floor(minutes / 60)} h` + (minutes % 60 ? ` ${minutes % 60} min` : "");
    }

    // "HH:mm" moved by some minutes, wrapping around midnight
    function stepTime(value: string, minutes: int): string {
        const [h, m] = value.split(":").map(Number);
        const total = (h * 60 + m + minutes + 1440) % 1440;
        return String(Math.floor(total / 60)).padStart(2, "0") + ":" + String(total % 60).padStart(2, "0");
    }

    function clamp(v: real, lo: real, hi: real): real {
        return Math.max(lo, Math.min(hi, v));
    }

    visible: shown
    title: "Settings"
    color: Theme.panelBg
    implicitWidth: 780
    implicitHeight: 560
    // can grow, not shrink below the default size
    minimumSize: Qt.size(implicitWidth, implicitHeight)

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
                        text: defaultsSaved.running ? "Saved" : "Save as defaults"
                        onClicked: {
                            Config.saveDefaults();
                            defaultsSaved.restart();
                        }

                        Timer {
                            id: defaultsSaved

                            interval: 1500
                        }
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

                            // Accent and accent2 for the running theme, from its own palette
                            Repeater {
                                model: [
                                    { role: "accent", label: "Accent" },
                                    { role: "accent2", label: "Second accent" },
                                    { role: "accent3", label: "Third accent" }
                                ]

                                ColumnLayout {
                                    id: accentRow

                                    required property var modelData
                                    readonly property string chosen: (Config.accentOverrides[Theme.theme] ?? {})[modelData.role] ?? ""

                                    function choose(name: string): void {
                                        const all = Object.assign({}, Config.accentOverrides);
                                        const mine = Object.assign({}, all[Theme.theme] ?? {});
                                        if (name)
                                            mine[accentRow.modelData.role] = name;
                                        else
                                            delete mine[accentRow.modelData.role];
                                        if (Object.keys(mine).length)
                                            all[Theme.theme] = mine;
                                        else
                                            delete all[Theme.theme];
                                        Config.accentOverrides = all;
                                        accentApply.restart();
                                    }

                                    Layout.fillWidth: true
                                    spacing: 4

                                    SettingRow {
                                        label: accentRow.modelData.label
                                        hint: `${accentRow.chosen ? accentRow.chosen[0].toUpperCase() + accentRow.chosen.slice(1) : "The theme's own"} in ${Theme.themeName}`

                                        TextButton {
                                            text: "Theme default"
                                            enabled: accentRow.chosen !== ""
                                            onClicked: accentRow.choose("")
                                        }
                                    }

                                    ColorChoice {
                                        Layout.fillWidth: true
                                        names: ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]
                                        value: accentRow.chosen
                                        onPicked: name => accentRow.choose(name)
                                    }
                                }
                            }

                            // The desktop follows the theme while it shows the theme's background
                            // (picked in the wallpaper picker, or Theme's here); any other
                            // wallpaper stays through theme changes
                            SettingRow {
                                label: "Wallpaper"
                                hint: Config.wallpaperFollowsTheme ? "The theme's background, changes with the theme" : "Your own, kept when the theme changes"

                                TextButton {
                                    text: "Theme's"
                                    enabled: !Config.wallpaperFollowsTheme
                                    onClicked: {
                                        Config.wallpaperFollowsTheme = true;
                                        followApply.restart();
                                    }
                                }
                            }

                            Timer {
                                id: followApply

                                interval: 800
                                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--follow-wallpaper"])
                            }

                            // Long enough for Config to save the choice; then the whole theme again
                            Timer {
                                id: accentApply

                                interval: 800
                                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py"])
                            }

                            SettingRow {
                                label: "Corner radius"
                                normalOnly: true
                                hint: "Windows, the shell and terminal apps"

                                Stepper {
                                    text: `${Config.radius} px`
                                    onStep: d => Config.radius = root.clamp(Config.radius + d, 0, 20)
                                }
                            }

                            SettingRow {
                                label: "Cursor"
                                hint: "Restart open apps to apply"

                                Stepper {
                                    text: Config.cursorTheme
                                    onStep: d => {
                                        Config.cursorTheme = root.cycle(root.cursorThemes, Config.cursorTheme, d);
                                        cursorApply.restart();
                                    }
                                }
                            }

                            SettingRow {
                                label: "Cursor size"

                                Stepper {
                                    text: `${Config.cursorSize} px`
                                    onStep: d => {
                                        Config.cursorSize = root.clamp(Config.cursorSize + d * 4, 16, 64);
                                        cursorApply.restart();
                                    }
                                }
                            }

                            SettingRow {
                                label: "Icons"
                                hint: "Restart Qt apps to apply"

                                Stepper {
                                    text: Config.iconTheme
                                    onStep: d => {
                                        Config.iconTheme = root.cycle(root.iconThemes, Config.iconTheme, d);
                                        iconApply.restart();
                                    }
                                }
                            }

                            Timer {
                                id: iconApply

                                interval: 400
                                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--icons", Config.iconTheme])
                            }

                            Process {
                                running: true
                                command: [Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--icon-themes"]
                                stdout: StdioCollector {
                                    onStreamFinished: root.iconThemes = JSON.parse(text)
                                }
                            }

                            // Stepping through several themes applies only the last
                            Timer {
                                id: cursorApply

                                interval: 400
                                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--cursor", Config.cursorTheme, String(Config.cursorSize)])
                            }

                            Process {
                                running: true
                                command: [Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--cursors"]
                                stdout: StdioCollector {
                                    onStreamFinished: root.cursorThemes = JSON.parse(text)
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
                                normalOnly: true
                                hint: "No blur below 50%"

                                Stepper {
                                    text: `${Math.round(Config.barOpacity * 100)}%`
                                    onStep: d => Config.barOpacity = Math.round(root.clamp(Config.barOpacity + d * 0.05, 0.3, 1) * 100) / 100
                                }
                            }

                            SettingRow {
                                label: "Panel opacity"
                                normalOnly: true
                                hint: "Dropdowns, launchers, tooltips"

                                Stepper {
                                    text: `${Math.round(Config.panelOpacity * 100)}%`
                                    onStep: d => Config.panelOpacity = Math.round(root.clamp(Config.panelOpacity + d * 0.05, 0.5, 1) * 100) / 100
                                }
                            }

                            SettingRow {
                                label: "Active window opacity"
                                normalOnly: true
                                hint: "Fullscreen windows stay opaque"

                                Stepper {
                                    text: `${Math.round(Config.activeOpacity * 100)}%`
                                    onStep: d => Config.activeOpacity = Math.round(root.clamp(Config.activeOpacity + d * 0.01, 0.5, 1) * 100) / 100
                                }
                            }

                            SettingRow {
                                label: "Inactive window opacity"
                                normalOnly: true

                                Stepper {
                                    text: `${Math.round(Config.inactiveOpacity * 100)}%`
                                    onStep: d => Config.inactiveOpacity = Math.round(root.clamp(Config.inactiveOpacity + d * 0.01, 0.5, 1) * 100) / 100
                                }
                            }

                            SettingRow {
                                label: "Blur"
                                normalOnly: true
                                hint: "Behind windows and the shell"

                                Switch {
                                    checked: Config.blur
                                    onToggled: Config.blur = !Config.blur
                                }
                            }

                            SettingRow {
                                label: "Animations"
                                normalOnly: true

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
                                label: "Floating bar"
                                hint: "Off: full width, square"

                                Switch {
                                    checked: Config.barFloating
                                    onToggled: Config.barFloating = !Config.barFloating
                                }
                            }

                            SettingRow {
                                visible: Config.barFloating
                                label: "Bar margin"
                                hint: "Space around the floating bar"

                                Stepper {
                                    text: `${Config.barMargin} px`
                                    onStep: d => Config.barMargin = root.clamp(Config.barMargin + d * 2, 0, 40)
                                }
                            }

                            SettingRow {
                                label: "Clock"

                                Stepper {
                                    text: Qt.formatDateTime(Time.date, Config.clockFormat)
                                    onStep: d => Config.clockFormat = root.cycle(root.clockFormats, Config.clockFormat, d)
                                }
                            }

                            SettingRow {
                                label: "Weather location"
                                hint: "Empty: detect from IP"

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
                                text: "Modules for each bar, in their order on it."
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
                                hint: "Close button on shell and GTK windows"

                                Switch {
                                    checked: Config.windowButtons
                                    onToggled: {
                                        Config.windowButtons = !Config.windowButtons;
                                        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--window-buttons", Config.windowButtons ? "on" : "off"]);
                                    }
                                }
                            }

                            StyledText {
                                text: "Inner: between windows. Outer: to the screen edge."
                                color: Theme.overlay1
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            SettingRow {
                                label: "Inner gaps"
                                normalOnly: true

                                Stepper {
                                    text: `${Config.gapsIn} px`
                                    onStep: d => Config.gapsIn = root.clamp(Config.gapsIn + d, 0, 40)
                                }
                            }

                            SettingRow {
                                label: "Outer gaps"
                                normalOnly: true

                                Stepper {
                                    text: `${Config.gapsOut} px`
                                    onStep: d => Config.gapsOut = root.clamp(Config.gapsOut + d, 0, 60)
                                }
                            }

                            SettingRow {
                                label: "Inner gaps in Work-Game"

                                Stepper {
                                    text: `${Config.gameGapsIn} px`
                                    onStep: d => Config.gameGapsIn = root.clamp(Config.gameGapsIn + d, 0, 40)
                                }
                            }

                            SettingRow {
                                label: "Outer gaps in Work-Game"

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
                                hint: "Critical ones stay until closed"

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

                            // The theme's background (it changes with the theme) until the user chooses
                            // another image; choosing the theme's own follows the theme again.
                            // The login screen shows the same.
                            SettingRow {
                                label: "Image"
                                hint: Config.lockFollowsTheme || Config.lockImage === "" ? "The theme's background, on the lock and login screens" : Config.lockImage.slice(Config.lockImage.lastIndexOf("/") + 1)

                                RowLayout {
                                    spacing: 8

                                    TextButton {
                                        visible: !Config.lockFollowsTheme && Config.lockImage !== ""
                                        text: "Theme's"
                                        onClicked: {
                                            Config.lockFollowsTheme = true;
                                            Config.lockImage = "";
                                        }
                                    }

                                    TextButton {
                                        text: "Choose…"
                                        onClicked: lockImagePicker.running = true
                                    }
                                }

                                Process {
                                    id: lockImagePicker

                                    command: ["zenity", "--file-selection", "--title=Lock screen image",
                                        `--filename=${Quickshell.env("HOME")}/.local/share/dotfiles/backgrounds/default/`,
                                        "--file-filter=Images | *.png *.jpg *.jpeg *.webp"]
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            const path = text.trim();
                                            if (path === "")
                                                return;
                                            const theirs = path === Theme.background;
                                            Config.lockFollowsTheme = theirs;
                                            Config.lockImage = theirs ? "" : path;
                                        }
                                    }
                                }
                            }

                            // Sections: each part of the lock screen, and the login screen's power
                            // buttons. Colors also go to the login screen (theme-set.py --login).
                            SettingsHeading {
                                text: "Clock and date"
                            }

                            LockToggle {
                                label: "Show"
                                hint: "Top right, on the lock and login screens"
                                key: "lockClock"
                                onEdited: loginApply.restart()
                            }

                            LockColor {
                                visible: Config.lockClock
                                label: "Color"
                                key: "lockClockColor"
                                onEdited: loginApply.restart()
                            }

                            SettingsHeading {
                                text: "Avatar"
                            }

                            LockToggle {
                                label: "Show"
                                hint: "Your picture (~/.face)"
                                key: "lockAvatar"
                                onEdited: loginApply.restart()
                            }

                            LockColor {
                                visible: Config.lockAvatar
                                label: "Outline"
                                key: "lockAvatarColor"
                                onEdited: loginApply.restart()
                            }

                            SettingsHeading {
                                text: "Box"
                            }

                            LockToggle {
                                label: "Show"
                                hint: "A card behind the avatar and password"
                                key: "lockBox"
                                onEdited: loginApply.restart()
                            }

                            LockColor {
                                visible: Config.lockBox
                                label: "Outline"
                                key: "lockBoxOutlineColor"
                                onEdited: loginApply.restart()
                            }

                            LockColor {
                                visible: Config.lockBox
                                label: "Background"
                                key: "lockBoxColor"
                                opacityKey: "lockBoxOpacity"
                                onEdited: loginApply.restart()
                            }

                            SettingsHeading {
                                text: "Password field"
                            }

                            Repeater {
                                model: [
                                    { label: "Outline", key: "lockInputOutlineColor" },
                                    { label: "Background", key: "lockInputColor", opacity: "lockInputOpacity" },
                                    { label: "Typing dots", key: "lockDotsColor" },
                                    { label: "User name", key: "lockUserColor" },
                                    { label: "Text", key: "lockTextColor" },
                                    { label: "Checking password", key: "lockCheckColor" },
                                    { label: "Wrong password", key: "lockFailColor" },
                                    { label: "Caps Lock on", key: "lockCapsColor" }
                                ]

                                LockColor {
                                    required property var modelData

                                    label: modelData.label
                                    key: modelData.key
                                    opacityKey: modelData.opacity ?? ""
                                    onEdited: loginApply.restart()
                                }
                            }

                            SettingsHeading {
                                text: "Power buttons (login screen)"
                            }

                            LockColor {
                                label: "Background"
                                key: "lockPowerColor"
                                opacityKey: "lockPowerOpacity"
                                onEdited: loginApply.restart()
                            }

                            LockColor {
                                label: "Icons"
                                key: "lockPowerIconColor"
                                onEdited: loginApply.restart()
                            }

                            LockColor {
                                label: "Outline"
                                key: "lockPowerOutlineColor"
                                onEdited: loginApply.restart()
                            }

                            // The login screen shares these colors. Long enough for Config to save them.
                            Timer {
                                id: loginApply

                                interval: 800
                                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--login"])
                            }

                            TextButton {
                                text: "Preview"
                                onClicked: Panels.lockPreview = true
                            }
                        }

                        // ------------------------------------------------ Idle
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "idle"
                            spacing: 12

                            StyledText {
                                Layout.fillWidth: true
                                text: "Idle time until each happens, counted from the last key or mouse movement. The lock screen stays up until the machine sleeps, which turns the screens off. Stay Awake and playing media hold both off."
                                color: Theme.subtext0
                                wrapMode: Text.Wrap
                            }

                            Repeater {
                                // the battery set only where there is a battery
                                model: Battery.available ? [
                                    { title: "Plugged in", now: !Idle.onBattery, keys: ["idleLock", "idleSuspend"] },
                                    { title: "On battery", now: Idle.onBattery, keys: ["idleLockBattery", "idleSuspendBattery"] }
                                ] : [
                                    { title: "", now: true, keys: ["idleLock", "idleSuspend"] }
                                ]

                                ColumnLayout {
                                    id: idleSet

                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 12

                                    SettingsHeading {
                                        visible: idleSet.modelData.title !== ""
                                        text: idleSet.modelData.title + (idleSet.modelData.now ? "  (now)" : "")
                                    }

                                    Repeater {
                                        model: [
                                            { label: "Lock the screen", key: idleSet.modelData.keys[0] },
                                            { label: "Sleep", key: idleSet.modelData.keys[1] }
                                        ]

                                        SettingRow {
                                            id: idleRow

                                            required property var modelData

                                            label: modelData.label

                                            Stepper {
                                                text: root.minutesText(Config[idleRow.modelData.key])
                                                onStep: d => Config[idleRow.modelData.key] = root.cycle(root.idleSteps, Config[idleRow.modelData.key], d)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ------------------------------------------------ Night light
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "nightlight"
                            spacing: 12

                            SettingRow {
                                label: "Temperature"
                                hint: "Lower is warmer"

                                Stepper {
                                    text: `${Config.nightlightTemperature} K`
                                    onStep: d => {
                                        Config.nightlightTemperature = root.clamp(Config.nightlightTemperature + d * 100, 1000, 6500);
                                        nightlightApply.restart();
                                    }
                                }
                            }

                            // Stepping through several values applies only the last
                            Timer {
                                id: nightlightApply

                                interval: 400
                                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/nightlight-toggle.sh", "apply"])
                            }

                            SettingRow {
                                label: "Schedule"
                                hint: "A manual toggle holds until the next change"

                                Switch {
                                    checked: Config.nightlightSchedule
                                    onToggled: Config.nightlightSchedule = !Config.nightlightSchedule
                                }
                            }

                            SettingRow {
                                visible: Config.nightlightSchedule
                                label: "Start"

                                Stepper {
                                    text: Config.nightlightStart
                                    onStep: d => Config.nightlightStart = root.stepTime(Config.nightlightStart, d * 15)
                                }
                            }

                            SettingRow {
                                visible: Config.nightlightSchedule
                                label: "End"

                                Stepper {
                                    text: Config.nightlightEnd
                                    onStep: d => Config.nightlightEnd = root.stepTime(Config.nightlightEnd, d * 15)
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
                                        text: Distro.logo
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
                                text: "Used everywhere but terminals. Reopen apps to apply."
                                color: Theme.overlay1
                                font.pixelSize: Theme.fontSize - 1
                                wrapMode: Text.Wrap
                            }

                            SettingRow {
                                label: "Nerd Fonts only"
                                hint: "Nerd Font for all text"

                                Switch {
                                    checked: Config.nerdFontOnly
                                    onToggled: {
                                        Config.nerdFontOnly = !Config.nerdFontOnly;
                                        fontApply.restart();
                                    }
                                }
                            }

                            SettingRow {
                                label: "Use Nerd Symbols font"
                                hint: "Off: icons from the Nerd Font"

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
                                sample: Distro.logo + " " + Icons.cog + " 0O1lI"
                                onPicked: family => {
                                    Config.nerdFont = family;
                                    fontApply.restart();
                                }
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
                                onPicked: family => {
                                    Config.displayFont = family;
                                    fontApply.restart();
                                }
                            }

                            SettingRow {
                                Layout.topMargin: 4
                                label: "Hinting"
                                hint: "Slight suits most screens"

                                Stepper {
                                    text: Config.fontHinting.charAt(0).toUpperCase() + Config.fontHinting.slice(1)
                                    onStep: d => {
                                        Config.fontHinting = root.cycle(["none", "slight", "medium", "full"], Config.fontHinting, d);
                                        fontApply.restart();
                                    }
                                }
                            }

                            SettingRow {
                                label: "Antialiasing"
                                hint: "Grayscale avoids color fringes"

                                Stepper {
                                    text: ({ none: "None", grayscale: "Grayscale", rgba: "Subpixel" })[Config.fontAntialiasing]
                                    onStep: d => {
                                        Config.fontAntialiasing = root.cycle(["none", "grayscale", "rgba"], Config.fontAntialiasing, d);
                                        fontApply.restart();
                                    }
                                }
                            }

                            // Stepping through several options applies only the last
                            Timer {
                                id: fontApply

                                interval: 400
                                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/scripts/theme-set.py", "--fonts", Config.nerdFont, Config.displayFont, Config.nerdFontOnly ? "on" : "off", Config.fontHinting, Config.fontAntialiasing])
                            }
                        }

                        // ------------------------------------------------ Tray & player
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.section === "tray"
                            spacing: 12

                            SettingRow {
                                label: "Tray icons"
                                hint: "Blend with the theme, or one color"

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
                                hint: "App names, comma separated"

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
