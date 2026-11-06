pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

// The idle times from Settings > Idle, for hypridle: lock, screens off, sleep. hypridle.conf
// (in the repo) has the rest and sources the listeners written here. On a machine with a
// battery, the battery times apply while unplugged. hypridle reads its config only when it
// starts, so a change of times or of power source restarts it, which also counts idle time
// from then on: unplugging after 7 idle minutes locks 5 minutes later, not never.
Singleton {
    id: root

    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/configs/generated/hypridle.conf"
    readonly property bool onBattery: Battery.available && UPower.onBattery

    readonly property int lockMinutes: onBattery ? Config.idleLockBattery : Config.idleLock
    readonly property int screenOffMinutes: onBattery ? Config.idleScreenOffBattery : Config.idleScreenOff
    readonly property int suspendMinutes: onBattery ? Config.idleSuspendBattery : Config.idleSuspend

    readonly property string listeners: {
        const out = [`# Written by Quickshell (services/Idle.qml) from Settings > Idle${onBattery ? ", on battery" : ""}; sourced by hypridle.conf\n`];
        const listener = (minutes, timeout, resume) => {
            if (minutes > 0)
                out.push(`listener {\n    timeout = ${minutes * 60}\n    on-timeout = ${timeout}\n${resume ? `    on-resume = ${resume}\n` : ""}}\n`);
        };
        listener(lockMinutes, "loginctl lock-session");
        listener(screenOffMinutes, `hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'`, `sleep 1; hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'`);
        listener(suspendMinutes, "systemctl suspend");
        return out.join("\n");
    }

    // Steppers change the times one step at a time: write once they settle
    onListenersChanged: applyDelay.restart()
    Component.onCompleted: applyDelay.restart()

    Timer {
        id: applyDelay

        interval: 1000
        onTriggered: {
            if (generated.text() !== root.listeners) {
                generated.setText(root.listeners);
                Quickshell.execDetached(["sh", "-c", "pkill -x hypridle; while pgrep -x hypridle >/dev/null; do sleep 0.1; done; exec hypridle"]);
            } else {
                // after a shell restart, or a first start with the file already right
                Quickshell.execDetached(["sh", "-c", "pgrep -x hypridle >/dev/null || exec hypridle"]);
            }
        }
    }

    FileView {
        id: generated

        path: root.file
        blockLoading: true
        printErrors: false
    }
}
