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
    property alias panelOpacity: adapter.panelOpacity
    property alias animations: adapter.animations

    // Bar
    property alias clockFormat: adapter.clockFormat
    property alias showWeather: adapter.showWeather

    // Weather: empty location means "detect from IP" (wttr.in)
    property alias weatherLocation: adapter.weatherLocation
    property alias weatherFahrenheit: adapter.weatherFahrenheit
    readonly property int weatherInterval: 30 * 60 * 1000

    // Notifications: seconds a popup stays up (critical ones stay until closed)
    property alias notificationTimeout: adapter.notificationTimeout

    // Lock screen
    property alias lockMatrix: adapter.lockMatrix
    property alias lockBlur: adapter.lockBlur

    // Tray and player
    property alias trayMonochrome: adapter.trayMonochrome
    property alias cava: adapter.cava

    function reset(): void {
        adapter.radius = 8;
        adapter.borderWidth = 1;
        adapter.barOpacity = 0.9;
        adapter.panelOpacity = 0.9;
        adapter.animations = true;
        adapter.clockFormat = "dddd HH:mm";
        adapter.showWeather = true;
        adapter.weatherLocation = "";
        adapter.weatherFahrenheit = false;
        adapter.notificationTimeout = 10;
        adapter.lockMatrix = true;
        adapter.lockBlur = false;
        adapter.trayMonochrome = false;
        adapter.cava = true;
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
            property real panelOpacity: 0.9
            property bool animations: true
            property string clockFormat: "dddd HH:mm"
            property bool showWeather: true
            property string weatherLocation: ""
            property bool weatherFahrenheit: false
            property int notificationTimeout: 10
            property bool lockMatrix: true
            property bool lockBlur: false
            property bool trayMonochrome: false
            property bool cava: true
        }
    }
}
