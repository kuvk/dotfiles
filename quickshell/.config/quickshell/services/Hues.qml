pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Each bar item's color, by its state. The bar's icon and its dropdown's header icon both
// read it here, so they always match. Off or idle is dimmed text.
Singleton {
    readonly property color off: Theme.dimText

    readonly property color launcher: Theme.accent
    readonly property color weather: Weather.ready ? Theme.yellow : off
    readonly property color calendar: Theme.accent
    readonly property color stayAwake: System.stayAwake ? Theme.orange : off
    // Work-Game: Game orange, Work magenta
    readonly property color mode: System.mode === "game" ? Theme.orange : System.mode === "work" ? Theme.magenta : off
    // muted dimmed, quiet magenta, medium blue, loud green
    readonly property color audio: {
        if (Audio.muted)
            return off;
        if (Audio.volume <= 0.3)
            return Theme.magenta;
        if (Audio.volume <= 0.6)
            return Theme.blue;
        return Theme.green;
    }
    // off dimmed, on cyan, a device connected blue
    readonly property color bluetooth: !Bluetooth.enabled ? off : (Bluetooth.connected.length > 0 ? Theme.blue : Theme.brightCyan)
    // no internet red, connected blue, Wi-Fi on but not connected magenta, off dimmed
    readonly property color network: Network.restricted ? Theme.red : (Network.type !== "none" ? Theme.blue : (Network.wifiEnabled ? Theme.magenta : off))
    // charging or full cyan, then green, yellow, orange, red as it empties
    readonly property color battery: {
        if (Battery.charging || Battery.full)
            return Theme.cyan;
        if (Battery.percent <= 0.15)
            return Theme.red;
        if (Battery.percent <= 0.4)
            return Theme.orange;
        if (Battery.percent <= 0.6)
            return Theme.yellow;
        return Theme.green;
    }
    readonly property color system: Theme.cyan
    // do not disturb magenta, else blue
    readonly property color notifications: Notifs.dnd ? Theme.magenta : Theme.blue
    readonly property color power: Theme.red
}
