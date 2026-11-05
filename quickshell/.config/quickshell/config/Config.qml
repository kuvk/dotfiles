pragma Singleton

import QtQuick
import Quickshell

// User preferences for the shell
Singleton {
    // Weather: empty location means "detect from IP" (wttr.in), or e.g. "Zagreb"
    readonly property string weatherLocation: ""
    readonly property bool weatherFahrenheit: false
    readonly property int weatherInterval: 30 * 60 * 1000

    // Seconds a notification popup stays up (critical ones stay until closed)
    readonly property int notificationTimeout: 10

    // Bar clock, Qt date format: "Monday 14:32"
    readonly property string clockFormat: "dddd HH:mm"
}
