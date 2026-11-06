pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User preferences, edited in the Settings window (gear in the control
// center) and saved to ~/.local/state/quickshell/.../settings.json.
Singleton {
    id: root

    // Look
    property alias radius: adapter.radius
    property alias cursorTheme: adapter.cursorTheme
    property alias cursorSize: adapter.cursorSize
    property alias iconTheme: adapter.iconTheme
    property alias nightlightSchedule: adapter.nightlightSchedule
    property alias nightlightStart: adapter.nightlightStart
    property alias nightlightEnd: adapter.nightlightEnd
    property alias nightlightTemperature: adapter.nightlightTemperature
    property alias lockStyle: adapter.lockStyle
    property alias lockImage: adapter.lockImage
    property alias lockClockColor: adapter.lockClockColor
    property alias lockAvatarColor: adapter.lockAvatarColor
    property alias lockBoxOutlineColor: adapter.lockBoxOutlineColor
    property alias lockBoxColor: adapter.lockBoxColor
    property alias lockInputOutlineColor: adapter.lockInputOutlineColor
    property alias lockInputColor: adapter.lockInputColor
    property alias lockUserColor: adapter.lockUserColor
    property alias lockCheckColor: adapter.lockCheckColor
    property alias lockFailColor: adapter.lockFailColor
    property alias lockCapsColor: adapter.lockCapsColor
    property alias lockBoxOpacity: adapter.lockBoxOpacity
    property alias lockBox: adapter.lockBox
    property alias lockClock: adapter.lockClock
    property alias lockAvatar: adapter.lockAvatar
    property alias lockPowerColor: adapter.lockPowerColor
    property alias lockPowerOpacity: adapter.lockPowerOpacity
    property alias lockPowerIconColor: adapter.lockPowerIconColor
    property alias lockPowerOutlineColor: adapter.lockPowerOutlineColor
    property alias accentOverrides: adapter.accentOverrides
    property alias wallpaperFollowsTheme: adapter.wallpaperFollowsTheme
    property alias lockInputOpacity: adapter.lockInputOpacity
    property alias lockDotsColor: adapter.lockDotsColor
    property alias lockTextColor: adapter.lockTextColor
    property alias borderWidth: adapter.borderWidth
    property alias barOpacity: adapter.barOpacity
    // Floating bar: margins around it and rounded corners
    property alias barFloating: adapter.barFloating
    property alias barMargin: adapter.barMargin
    property alias panelOpacity: adapter.panelOpacity
    property alias animations: adapter.animations

    // Bar
    property alias clockFormat: adapter.clockFormat
    // Bar modules hidden on the primary monitor's bar and on the others
    property alias barHiddenPrimary: adapter.barHiddenPrimary
    property alias barHiddenOthers: adapter.barHiddenOthers
    // In the bar's order, left to right
    readonly property var barModules: [
        { id: "launcher", label: "App launcher" },
        { id: "workspaces", label: "Workspaces" },
        { id: "windowTitle", label: "Window title" },
        { id: "layout", label: "Keyboard layout" },
        { id: "clock", label: "Clock" },
        { id: "weather", label: "Weather" },
        { id: "media", label: "Media player" },
        { id: "tray", label: "System tray" },
        { id: "stayAwake", label: "Stay Awake" },
        { id: "workGame", label: "Work-Game" },
        { id: "audio", label: "Volume" },
        { id: "bluetooth", label: "Bluetooth" },
        { id: "network", label: "Network" },
        { id: "battery", label: "Battery" },
        { id: "displays", label: "Displays" },
        { id: "controlCenter", label: "Control Center" },
        { id: "power", label: "Power menu" }
    ]

    function barShows(primary: bool, id: string): bool {
        return !(primary ? barHiddenPrimary : barHiddenOthers).includes(id);
    }

    function setBarModule(primary: bool, id: string, shown: bool): void {
        const list = (primary ? barHiddenPrimary : barHiddenOthers).filter(m => m !== id);
        if (!shown)
            list.push(id);
        if (primary)
            barHiddenPrimary = list;
        else
            barHiddenOthers = list;
    }

    // Weather: empty location means "detect from IP" (wttr.in)
    property alias weatherLocation: adapter.weatherLocation
    property alias weatherFahrenheit: adapter.weatherFahrenheit
    readonly property int weatherInterval: 30 * 60 * 1000

    // Notifications: seconds a popup stays up (critical ones stay until closed)
    property alias notificationTimeout: adapter.notificationTimeout

    // Lock screen

    // Tray and player
    property alias trayMonochrome: adapter.trayMonochrome
    property alias trayTint: adapter.trayTint
    property alias trayKeepColors: adapter.trayKeepColors
    property alias cava: adapter.cava
    property alias cavaBars: adapter.cavaBars

    // Idle (hypridle, through services/Idle.qml): minutes until the screen locks, the screens
    // go off and the machine sleeps; 0 is never. The *Battery ones apply on battery.
    property alias idleLock: adapter.idleLock
    property alias idleScreenOff: adapter.idleScreenOff
    property alias idleSuspend: adapter.idleSuspend
    property alias idleLockBattery: adapter.idleLockBattery
    property alias idleScreenOffBattery: adapter.idleScreenOffBattery
    property alias idleSuspendBattery: adapter.idleSuspendBattery

    // Window gaps (Hyprland), normal and in Work-Game
    // Fonts (Settings > Fonts): a Nerd Font, a display font for text, and
    // whether text uses the Nerd Font too and icons come from Symbols Nerd Font
    property alias nerdFont: adapter.nerdFont
    property alias displayFont: adapter.displayFont
    property alias nerdFontOnly: adapter.nerdFontOnly
    property alias fontHinting: adapter.fontHinting
    property alias fontAntialiasing: adapter.fontAntialiasing
    property alias nerdSymbols: adapter.nerdSymbols
    property alias windowButtons: adapter.windowButtons
    property alias gapsIn: adapter.gapsIn
    property alias gapsOut: adapter.gapsOut
    property alias gameGapsIn: adapter.gameGapsIn
    property alias gameGapsOut: adapter.gameGapsOut

    // Lock screen colors, as theme color names (green, blue, accent, ...)

    function reset(): void {
        // Saved with "Save as defaults", written in one go: setting values one at a
        // time saves after each, and the reload that causes can undo the later ones
        try {
            const saved = JSON.parse(defaultsFile.text());
            saved.version = root.version;
            settingsFile.setText(JSON.stringify(saved, null, 2) + "\n");
            return;
        } catch (e) {
            console.warn("Config: no usable defaults.json, using the built-in defaults", e);
        }
        adapter.radius = 6;
        adapter.borderWidth = 2;
        adapter.barOpacity = 0.85;
        adapter.barFloating = false;
        adapter.barMargin = 6;
        adapter.panelOpacity = 0.85;
        adapter.animations = true;
        adapter.cursorTheme = "Adwaita";
        adapter.cursorSize = 24;
        adapter.iconTheme = "Papirus";
        adapter.nightlightSchedule = false;
        adapter.nightlightStart = "20:00";
        adapter.nightlightEnd = "07:00";
        adapter.nightlightTemperature = 4400;
        adapter.lockStyle = "picture";
        adapter.lockImage = "/home/kuvk/Pictures/Wallpapers/dori-theme-catppuccin-mocha-cba6f7-on-1e1e2e.png";
        adapter.lockClockColor = "accent";
        adapter.lockAvatarColor = "accent";
        adapter.lockBoxOutlineColor = "accent";
        adapter.lockBoxColor = "base";
        adapter.lockInputOutlineColor = "accent";
        adapter.lockInputColor = "subtext0";
        adapter.lockUserColor = "accent";
        adapter.lockCheckColor = "green";
        adapter.lockFailColor = "red";
        adapter.lockCapsColor = "peach";
        adapter.lockBoxOpacity = 90;
        adapter.lockBox = false;
        adapter.lockClock = false;
        adapter.lockAvatar = true;
        adapter.lockPowerColor = "base";
        adapter.lockPowerOpacity = 85;
        adapter.lockPowerIconColor = "accent2";
        adapter.lockPowerOutlineColor = "accent";
        adapter.accentOverrides = {"gruvbox": {"accent": "blue", "accent2": "peach", "accent3": "mauve"}, "tokyo-night": {"accent": "teal", "accent2": "peach", "accent3": "mauve"}};
        adapter.wallpaperFollowsTheme = true;
        adapter.lockInputOpacity = 30;
        adapter.lockDotsColor = "accent2";
        adapter.lockTextColor = "text";
        adapter.clockFormat = "dddd HH:mm";
        adapter.barHiddenPrimary = ["displays"];
        adapter.barHiddenOthers = ["power", "layout", "media", "displays", "weather", "clock"];
        adapter.weatherLocation = "Knez Do, Montenegro";
        adapter.weatherFahrenheit = false;
        adapter.notificationTimeout = 4;
        adapter.trayMonochrome = false;
        adapter.trayTint = false;
        adapter.trayKeepColors = "";
        adapter.cava = true;
        adapter.cavaBars = 40;
        adapter.nerdFont = "JetBrainsMono Nerd Font";
        adapter.displayFont = "SF Pro Display";
        adapter.nerdFontOnly = true;
        adapter.fontHinting = "slight";
        adapter.fontAntialiasing = "rgba";
        adapter.nerdSymbols = true;
        adapter.windowButtons = false;
        adapter.gapsIn = 3;
        adapter.gapsOut = 6;
        adapter.gameGapsIn = 3;
        adapter.gameGapsOut = 6;
        adapter.idleLock = 10;
        adapter.idleScreenOff = 20;
        adapter.idleSuspend = 30;
        adapter.idleLockBattery = 5;
        adapter.idleScreenOffBattery = 10;
        adapter.idleSuspendBattery = 15;
        adapter.version = root.version;
    }

    // Current settings become what Reset (and a first start) applies
    function saveDefaults(): void {
        const current = JSON.parse(settingsFile.text());
        delete current.version;
        defaultsFile.setText(JSON.stringify(current, null, 2) + "\n");
    }

    // Bump when defaults change; older settings files are reset once
    readonly property int version: 2

    FileView {
        id: defaultsFile

        path: Quickshell.shellPath("config/defaults.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: settingsFile

        path: Quickshell.statePath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            if (adapter.version < root.version)
                root.reset();
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.reset();
            }
        }

        JsonAdapter {
            id: adapter

            property int version: 0
            property int radius: 6
            // read by scripts/theme-set.py
            property string cursorTheme: "Adwaita"
            property int cursorSize: 24
            property string iconTheme: "Papirus"
            property bool nightlightSchedule: false
            property string nightlightStart: "20:00" // the schedule may cross midnight
            property string nightlightEnd: "07:00"
            property int nightlightTemperature: 4400 // kelvin, read by scripts/nightlight-toggle.sh
            // the lock screen (modules/lock); the colors also go to the login screen (theme-set.py)
            property string lockStyle: "picture" // "picture" (the wallpaper) | "image" (lockImage)
            property string lockImage: "/home/kuvk/Pictures/Wallpapers/dori-theme-catppuccin-mocha-cba6f7-on-1e1e2e.png"
            // theme color names
            property string lockClockColor: "accent"
            property string lockAvatarColor: "accent"
            property string lockBoxOutlineColor: "accent"
            property string lockBoxColor: "base"
            property string lockInputOutlineColor: "accent"
            property string lockInputColor: "subtext0"
            property string lockUserColor: "accent"
            property string lockCheckColor: "green"
            property string lockFailColor: "red"
            property string lockCapsColor: "peach"
            property int lockBoxOpacity: 90 // percent
            // per theme: { "catppuccin-mocha": { accent: "mauve", accent2: "blue" } }, read by theme-set.py
            property var accentOverrides: ({"gruvbox": {"accent": "blue", "accent2": "peach", "accent3": "mauve"}, "tokyo-night": {"accent": "teal", "accent2": "peach", "accent3": "mauve"}})
            // the logo wallpaper in the theme's colors, redrawn on theme change (theme-set.py)
            property bool wallpaperFollowsTheme: true
            property bool lockClock: false // clock and date, one color (lockClockColor)
            property bool lockAvatar: true
            // the login screen's power buttons, apart from the box
            property string lockPowerColor: "base"
            property int lockPowerOpacity: 85 // percent
            property string lockPowerIconColor: "accent2"
            property string lockPowerOutlineColor: "accent"
            property bool lockBox: false // the card behind the avatar and password (lock and login screens)
            property int lockInputOpacity: 30 // percent
            property string lockDotsColor: "accent2"
            property string lockTextColor: "text"
            property int borderWidth: 2
            property real barOpacity: 0.85
            property bool barFloating: false
            property int barMargin: 6
            property real panelOpacity: 0.85
            property bool animations: true
            property string clockFormat: "dddd HH:mm"
            property var barHiddenPrimary: ["displays"]
            property var barHiddenOthers: ["power", "layout", "media", "displays", "weather", "clock"]
            property string weatherLocation: "Knez Do, Montenegro"
            property bool weatherFahrenheit: false
            property int notificationTimeout: 4
            property bool trayMonochrome: false
            property bool trayTint: false
            // tray apps whose icon colors carry meaning (e.g. the ROG dGPU
            // state) and stay original in monochrome/tinted mode; comma separated
            property string trayKeepColors: ""
            property bool cava: true
            property int cavaBars: 40
            property string nerdFont: "JetBrainsMono Nerd Font"
            property string displayFont: "SF Pro Display"
            property bool nerdFontOnly: true
            property string fontHinting: "slight"
            property string fontAntialiasing: "rgba"
            property bool nerdSymbols: true
            property bool windowButtons: false
            property int gapsIn: 3
            property int gapsOut: 6
            property int gameGapsIn: 3
            property int gameGapsOut: 6
            property int idleLock: 10
            property int idleScreenOff: 20
            property int idleSuspend: 30
            property int idleLockBattery: 5
            property int idleScreenOffBattery: 10
            property int idleSuspendBattery: 15
        }
    }
}
