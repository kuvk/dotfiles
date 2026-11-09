pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.config

// Idle: lock after Settings > Power & Screen > Idle's lock time, sleep after its sleep time (the battery times
// while unplugged on a machine with a battery). The lock stays on screen until then: the screens
// go off when the machine sleeps (services/Lock.qml says why). After Omarchy's idle service (shell/plugins/services/idle,
// github.com/basecamp/omarchy, MIT): Hyprland reports the idle time (ext-idle-notify,
// apps' own idle inhibitors respected), one cycle per idle stretch with its deadlines set when
// it starts, any input cancels it. Stay Awake and playing media hold it off.
Singleton {
    id: root

    readonly property bool onBattery: Battery.available && UPower.onBattery
    readonly property int lockMinutes: onBattery ? Config.idleLockBattery : Config.idleLock
    readonly property int sleepMinutes: onBattery ? Config.idleSuspendBattery : Config.idleSuspend
    // 0 is never, not "at once"
    readonly property real firstMinutes: Math.min(lockMinutes || Infinity, sleepMinutes || Infinity)
    readonly property bool enabled: !System.stayAwake && !System.mediaPlaying && firstMinutes !== Infinity

    property bool inCycle: false
    // The idle monitor goes on a few seconds after the shell starts: made at once, at login, it
    // was never told about idle (after a shell reload it was)
    property bool started: false

    Timer {
        interval: 5000
        running: true
        onTriggered: root.started = true
    }

    function startCycle(): void {
        if (inCycle)
            return;
        inCycle = true;
        // the deadlines of this idle stretch: a change of settings applies from the next
        arm(lockTimer, lockMinutes);
        arm(sleepTimer, sleepMinutes);
    }

    function arm(timer: Timer, minutes: int): void {
        if (minutes <= 0)
            return;
        const ms = (minutes - firstMinutes) * 60000;
        if (ms <= 0)
            timer.triggered();
        else {
            timer.interval = ms;
            timer.restart();
        }
    }

    function cancelCycle(): void {
        inCycle = false;
        lockTimer.stop();
        sleepTimer.stop();
    }

    onEnabledChanged: if (!enabled) cancelCycle()

    // qs ipc call idle status
    function status(): string {
        return JSON.stringify({
            enabled, started, stayAwake: System.stayAwake, mediaPlaying: System.mediaPlaying, onBattery,
            lockMinutes, sleepMinutes, idleAfterSeconds: monitor.timeout, idle: monitor.isIdle, inCycle,
            lockIn: lockTimer.running ? lockTimer.interval / 1000 : null, sleepIn: sleepTimer.running ? sleepTimer.interval / 1000 : null
        });
    }

    IdleMonitor {
        id: monitor

        enabled: root.enabled && root.started
        timeout: root.enabled ? root.firstMinutes * 60 : 60
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.startCycle() : root.cancelCycle()
    }

    Timer {
        id: lockTimer

        onTriggered: if (root.inCycle) Lock.lock()
    }

    // The lock comes first: scripts/sleep-lock.sh locks before every suspend
    Timer {
        id: sleepTimer

        onTriggered: if (root.inCycle) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
