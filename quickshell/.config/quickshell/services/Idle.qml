pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.config

// Idle: lock after Settings > Screen & Sleep > Idle's lock time, sleep after its sleep time (the battery times
// while unplugged on a machine with a battery). The lock stays on screen until then: the screens
// go off when the machine sleeps (services/Lock.qml says why). After Omarchy's idle service (shell/plugins/services/idle,
// github.com/basecamp/omarchy, MIT): Hyprland reports the idle time (ext-idle-notify,
// apps' own idle inhibitors respected), one cycle per idle stretch with its deadlines set when
// it starts, any input cancels it. Stay Awake and playing media hold it off, and a program
// holding logind's idle lock (systemd-inhibit --what=idle: hyprdori-awake for Hyprdori's long
// scripts) postpones the lock and the sleep while it holds it.
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
        lockDue = false;
        sleepDue = false;
        idleLockRetry.stop();
    }

    onEnabledChanged: if (!enabled) cancelCycle()

    // qs ipc call idle status
    function status(): string {
        return JSON.stringify({
            enabled, started, stayAwake: System.stayAwake, mediaPlaying: System.mediaPlaying, onBattery,
            lockMinutes, sleepMinutes, idleAfterSeconds: monitor.timeout, idle: monitor.isIdle, inCycle,
            lockIn: lockTimer.running ? lockTimer.interval / 1000 : null, sleepIn: sleepTimer.running ? sleepTimer.interval / 1000 : null,
            heldByIdleLock: idleLockRetry.running
        });
    }

    // A due lock or sleep waits while a program holds logind's idle lock: asked once when it's
    // due (one systemd-inhibit --list), then every minute until the lock is let go; nothing runs
    // before a deadline. When the list can't be read, it goes ahead as before.
    property bool lockDue: false
    property bool sleepDue: false

    function due(lock: bool): void {
        if (lock)
            lockDue = true;
        else
            sleepDue = true;
        if (!idleLockCheck.running)
            idleLockCheck.running = true;
    }

    Process {
        id: idleLockCheck

        command: ["systemd-inhibit", "--list", "--json=short", "--no-pager"]
        stdout: StdioCollector {
            id: idleLocks
        }
        onExited: {
            if (!root.inCycle)
                return;
            let held = false;
            try {
                held = JSON.parse(idleLocks.text || "[]").some(i => i.mode === "block" && String(i.what).split(":").includes("idle"));
            } catch (e) {}
            if (held) {
                idleLockRetry.restart();
                return;
            }
            if (root.lockDue) {
                root.lockDue = false;
                Lock.lock();
            }
            if (root.sleepDue) {
                root.sleepDue = false;
                Quickshell.execDetached(["systemctl", "suspend"]);
            }
        }
    }

    Timer {
        id: idleLockRetry

        interval: 60000
        onTriggered: if (root.inCycle && !idleLockCheck.running) idleLockCheck.running = true
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

        onTriggered: if (root.inCycle) root.due(true)
    }

    // The lock comes first: hyprdori-sleep-lock locks before every suspend
    Timer {
        id: sleepTimer

        onTriggered: if (root.inCycle) root.due(false)
    }
}
