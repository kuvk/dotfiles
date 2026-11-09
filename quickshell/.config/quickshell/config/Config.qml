pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User preferences, edited in the Settings window (gear in the control
// center) and saved to ~/.local/state/quickshell/.../settings.json.
Singleton {
    id: root

    // The aliases follow the Settings pages and their sections.

    // Style > System: what the shell and Hyprland share
    // per theme, another of its colors as the accent: { "catppuccin": "magenta" }, read by hyprdori-theme-set
    property alias accentOverrides: adapter.accentOverrides
    // the theme's background on the desktop, redrawn on theme change; set by the wallpaper picker
    property alias wallpaperFollowsTheme: adapter.wallpaperFollowsTheme
    property alias radius: adapter.radius
    property alias borderWidth: adapter.borderWidth
    // read by hyprdori-theme-set, like the fonts and colors
    property alias cursorTheme: adapter.cursorTheme
    property alias cursorSize: adapter.cursorSize
    property alias iconTheme: adapter.iconTheme
    // Hyprland's blur in normal mode (Work-Game has none); services/Hypr.qml
    property alias blur: adapter.blur
    property alias animations: adapter.animations
    property alias windowButtons: adapter.windowButtons

    // Style > Shell
    property alias barOpacity: adapter.barOpacity
    property alias shellOpacity: adapter.shellOpacity
    // seconds a popup stays up; critical ones stay until closed
    property alias notificationTimeout: adapter.notificationTimeout

    // Style > Hyprland: windows in normal mode (fullscreen ones stay opaque), gaps normal and in
    // Work-Game
    property alias activeOpacity: adapter.activeOpacity
    property alias inactiveOpacity: adapter.inactiveOpacity
    property alias gapsIn: adapter.gapsIn
    property alias gapsOut: adapter.gapsOut
    property alias gameGapsIn: adapter.gameGapsIn
    property alias gameGapsOut: adapter.gameGapsOut

    // Style > Lock screen, also the login screen's (hyprdori-theme-set --login); the colors are
    // the theme's
    // the background: the theme's own (Theme.backgroundImage) until an image is chosen
    property alias lockFollowsTheme: adapter.lockFollowsTheme
    property alias lockImage: adapter.lockImage
    property alias lockAvatar: adapter.lockAvatar
    // the password field's corners, also on the login and boot screens, and the login screen's buttons
    property alias lockRounded: adapter.lockRounded
    // percent, to a tenth
    property alias lockInputOpacity: adapter.lockInputOpacity
    // the login screen's power buttons
    property alias lockPowerOpacity: adapter.lockPowerOpacity

    // Fonts (hyprdori-theme-set --fonts): the terminals' font, monospaced; the display font for
    // the shell's and apps' text unless monoEverywhere puts the font there too
    property alias font: adapter.font
    property alias displayFont: adapter.displayFont
    property alias monoEverywhere: adapter.monoEverywhere
    property alias fontHinting: adapter.fontHinting
    property alias fontAntialiasing: adapter.fontAntialiasing

    // Bar > General
    // margins around the bar and rounded corners
    property alias barFloating: adapter.barFloating
    property alias barMargin: adapter.barMargin
    property alias clockFormat: adapter.clockFormat
    // empty: detect from IP (wttr.in)
    property alias weatherLocation: adapter.weatherLocation
    property alias weatherFahrenheit: adapter.weatherFahrenheit
    property alias trayMonochrome: adapter.trayMonochrome
    property alias trayTint: adapter.trayTint
    // tray apps whose icon colors carry meaning (the ROG dGPU state) stay original when
    // monochrome or tinted; comma separated
    property alias trayKeepColors: adapter.trayKeepColors
    property alias cava: adapter.cava
    property alias cavaBars: adapter.cavaBars

    // Bar > Per monitor: modules hidden per monitor, by its connector name
    // ({ "HDMI-A-1": ["displays"] }); a monitor not in it shows every module
    property alias barHidden: adapter.barHidden

    // Screen & Sleep > Idle: minutes until the screen locks and the machine sleeps, 0 is never;
    // *Battery on battery (services/Idle.qml)
    property alias idleLock: adapter.idleLock
    property alias idleSuspend: adapter.idleSuspend
    property alias idleLockBattery: adapter.idleLockBattery
    property alias idleSuspendBattery: adapter.idleSuspendBattery

    // Screen & Sleep > Night light
    property alias nightlightSchedule: adapter.nightlightSchedule
    // the schedule may cross midnight
    property alias nightlightStart: adapter.nightlightStart
    property alias nightlightEnd: adapter.nightlightEnd
    // kelvin, read by scripts/nightlight-toggle.sh
    property alias nightlightTemperature: adapter.nightlightTemperature

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

    function barShows(monitor: string, id: string): bool {
        return !(barHidden[monitor] ?? []).includes(id);
    }

    function setBarModule(monitor: string, id: string, shown: bool): void {
        const all = Object.assign({}, barHidden);
        const list = (all[monitor] ?? []).filter(m => m !== id);
        if (!shown)
            list.push(id);
        if (list.length > 0)
            all[monitor] = list;
        else
            delete all[monitor];
        barHidden = all;
    }

    // How often the weather refreshes
    readonly property int weatherInterval: 30 * 60 * 1000

    // Reset (and a first start): defaults.json, saved with "Save as defaults", written in one
    // go (setting values one at a time saves after each, and the reload that causes can undo
    // the later ones). Without it the settings keep their starting values below.
    function reset(): void {
        try {
            const saved = JSON.parse(defaultsFile.text());
            saved.version = root.version;
            settingsFile.setText(JSON.stringify(saved, null, 2) + "\n");
        } catch (e) {
            console.warn("Config: no usable defaults.json; keeping the built-in defaults", e);
        }
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
            // The settings, by Settings page, with their built-in defaults (defaults.json overrides them)

            // Style > System
            property var accentOverrides: ({})
            property bool wallpaperFollowsTheme: true
            property int radius: 10
            property int borderWidth: 2
            property string cursorTheme: "Adwaita"
            property int cursorSize: 24
            property string iconTheme: "Papirus"
            property bool blur: true
            property bool animations: true
            property bool windowButtons: false

            // Style > Shell
            property real barOpacity: 0.92
            property real shellOpacity: 0.92
            property int notificationTimeout: 5

            // Style > Hyprland
            property real activeOpacity: 0.95
            property real inactiveOpacity: 0.85
            property int gapsIn: 5
            property int gapsOut: 10
            property int gameGapsIn: 2
            property int gameGapsOut: 4

            // Style > Lock screen
            property bool lockFollowsTheme: true
            property string lockImage: ""
            property bool lockAvatar: true
            property bool lockRounded: true
            property real lockInputOpacity: 80
            property real lockPowerOpacity: 85

            // Fonts
            property string font: "JetBrainsMono Nerd Font"
            property string displayFont: "SF Pro Display"
            property bool monoEverywhere: false
            property string fontHinting: "slight"
            property string fontAntialiasing: "rgba"

            // Bar > General
            property bool barFloating: false
            property int barMargin: 6
            property string clockFormat: "dddd HH:mm"
            property string weatherLocation: ""
            property bool weatherFahrenheit: false
            property bool trayMonochrome: false
            property bool trayTint: false
            property string trayKeepColors: ""
            property bool cava: true
            property int cavaBars: 40

            // Bar > Per monitor
            property var barHidden: ({})

            // Screen & Sleep > Idle
            property int idleLock: 5
            property int idleSuspend: 20
            property int idleLockBattery: 3
            property int idleSuspendBattery: 10

            // Screen & Sleep > Night light
            property bool nightlightSchedule: false
            property string nightlightStart: "20:00"
            property string nightlightEnd: "07:00"
            property int nightlightTemperature: 4500
        }
    }
}
