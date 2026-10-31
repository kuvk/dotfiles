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
    readonly property var barModules: [
        { id: "launcher", label: "App launcher" },
        { id: "workspaces", label: "Workspaces" },
        { id: "windowTitle", label: "Window title" },
        { id: "layout", label: "Keyboard layout" },
        { id: "weather", label: "Weather" },
        { id: "media", label: "Media player" },
        { id: "tray", label: "System tray" },
        { id: "workGame", label: "Work-Game" },
        { id: "stayAwake", label: "Stay Awake" },
        { id: "audio", label: "Volume" },
        { id: "bluetooth", label: "Bluetooth" },
        { id: "network", label: "Network" },
        { id: "battery", label: "Battery" },
        { id: "controlCenter", label: "Control Center" },
        { id: "displays", label: "Displays" },
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

    // Window gaps (Hyprland), normal and in Work-Game
    // Fonts (Settings > Fonts): a Nerd Font, a display font for text, and
    // whether text uses the Nerd Font too and icons come from Symbols Nerd Font
    property alias nerdFont: adapter.nerdFont
    property alias displayFont: adapter.displayFont
    property alias nerdFontOnly: adapter.nerdFontOnly
    property alias nerdSymbols: adapter.nerdSymbols
    property alias windowButtons: adapter.windowButtons
    property alias gapsIn: adapter.gapsIn
    property alias gapsOut: adapter.gapsOut
    property alias gameGapsIn: adapter.gameGapsIn
    property alias gameGapsOut: adapter.gameGapsOut

    // Lock screen colors, as theme color names (green, blue, accent, ...)

    function reset(): void {
        adapter.radius = 8;
        adapter.borderWidth = 1;
        adapter.barOpacity = 0.9;
        adapter.barFloating = false;
        adapter.barMargin = 6;
        adapter.panelOpacity = 0.9;
        adapter.animations = true;
        adapter.clockFormat = "dddd HH:mm";
        adapter.barHiddenPrimary = [];
        adapter.barHiddenOthers = [];
        adapter.weatherLocation = "";
        adapter.weatherFahrenheit = false;
        adapter.notificationTimeout = 10;
        adapter.trayMonochrome = false;
        adapter.trayTint = false;
        adapter.trayKeepColors = "rog-control-center";
        adapter.cava = true;
        adapter.cavaBars = 24;
        adapter.nerdFont = "JetBrainsMono Nerd Font";
        adapter.displayFont = "SF Pro Display";
        adapter.nerdFontOnly = false;
        adapter.nerdSymbols = true;
        adapter.windowButtons = false;
        adapter.gapsIn = 2;
        adapter.gapsOut = 4;
        adapter.gameGapsIn = 0;
        adapter.gameGapsOut = 0;
        adapter.version = root.version;
    }

    // Bump when defaults change; older settings files are reset once
    readonly property int version: 2

    FileView {
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
                adapter.version = root.version;
                writeAdapter();
            }
        }

        JsonAdapter {
            id: adapter

            property int version: 0
            property int radius: 8
            property int borderWidth: 1
            property real barOpacity: 0.9
            property bool barFloating: false
            property int barMargin: 6
            property real panelOpacity: 0.9
            property bool animations: true
            property string clockFormat: "dddd HH:mm"
            property var barHiddenPrimary: []
            property var barHiddenOthers: []
            property string weatherLocation: ""
            property bool weatherFahrenheit: false
            property int notificationTimeout: 10
            property bool trayMonochrome: false
            property bool trayTint: false
            // tray apps whose icon colors carry meaning (e.g. the ROG dGPU
            // state) and stay original in monochrome/tinted mode; comma separated
            property string trayKeepColors: "rog-control-center"
            property bool cava: true
            property int cavaBars: 24
            property string nerdFont: "JetBrainsMono Nerd Font"
            property string displayFont: "SF Pro Display"
            property bool nerdFontOnly: false
            property bool nerdSymbols: true
            property bool windowButtons: false
            property int gapsIn: 2
            property int gapsOut: 4
            property int gameGapsIn: 0
            property int gameGapsOut: 0
        }
    }
}
