pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Animated theme and wallpaper switches: every monitor is captured, the
// capture covers the screen while the command runs underneath, then it opens
// from the middle out along a diagonal (modules/transition/TransitionOverlay). Not named
// "Transition": that is a QtQuick type.
// Without animations (Settings, or Work-Game Mode) the command just runs.
Singleton {
    id: root

    // "idle" | "capture" | "run" | "reveal"
    property string phase: "idle"
    property int screensReady: 0
    property int settleMs: 300
    readonly property int revealMs: 900

    // `delayMs`: let a closing picker fade out before the capture.
    // `settle`: wait after the command so the new look has been drawn.
    function run(command: var, delayMs: int, settle: int): void {
        if (!Config.animations || Theme.gamemode || phase !== "idle") {
            Quickshell.execDetached(command);
            return;
        }
        proc.command = command;
        settleMs = settle;
        screensReady = 0;
        startDelay.interval = Math.max(1, delayMs);
        startDelay.restart();
    }

    function screenReady(): void {
        if (phase !== "capture")
            return;
        screensReady++;
        if (screensReady >= Quickshell.screens.length)
            startCommand();
    }

    function startCommand(): void {
        captureTimeout.stop();
        phase = "run";
        proc.running = true;
        runTimeout.restart();
    }

    // never leave the old look covering the screens if the command hangs
    Timer {
        id: runTimeout

        interval: 8000
        onTriggered: if (root.phase === "run") settleTimer.restart()
    }

    Timer {
        id: startDelay

        onTriggered: {
            root.phase = "capture";
            captureTimeout.restart();
        }
    }

    // a monitor that never delivers a frame doesn't hold the switch up
    Timer {
        id: captureTimeout

        interval: 600
        onTriggered: if (root.phase === "capture") root.startCommand()
    }

    Process {
        id: proc

        onExited: {
            runTimeout.stop();
            settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer

        interval: root.settleMs
        onTriggered: {
            root.phase = "reveal";
            doneTimer.restart();
        }
    }

    Timer {
        id: doneTimer

        interval: root.revealMs + 50
        onTriggered: root.phase = "idle"
    }
}
