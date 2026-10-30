pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam

// Lock state and password check, shared by the lock surfaces on every screen.
// The lock itself is modules/lock/LockScreen.qml.
Singleton {
    id: root

    property bool locked: false
    // true while the curtain slides away after a correct password
    property bool unlocking: false
    // skip the drop animation (before suspend, so nothing shows on resume)
    property bool instant: false
    // monitor that shows the clock and password field
    property string mainScreen: ""

    property string password: ""
    property bool authenticating: false
    property bool failed: false
    property bool capsLock: false

    function setCursorHidden(hidden: bool): void {
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ cursor = { invisible = ${hidden} } })`]);
    }

    // No pointer on the lock screen; also clears it after a crash while locked
    onLockedChanged: setCursorHidden(locked)
    Component.onCompleted: setCursorHidden(locked)

    function lock(): void {
        if (locked)
            return;
        instant = false;
        mainScreen = Hyprland.focusedMonitor?.name ?? "";
        locked = true;
    }

    function lockNow(): void {
        instant = true;
        mainScreen = Hyprland.focusedMonitor?.name ?? "";
        locked = true;
    }

    function checkCapsLock(): void {
        capsProc.running = true;
    }

    function submit(): void {
        if (authenticating || password.length === 0)
            return;
        failed = false;
        authenticating = true;
        pam.start();
    }

    PamContext {
        id: pam

        configDirectory: Quickshell.shellDir + "/pam"
        config: "password.conf"

        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: result => {
            root.authenticating = false;
            if (result === PamResult.Success) {
                root.password = "";
                root.unlocking = true;
                unlockTimer.start();
            } else {
                root.password = "";
                root.failed = true;
            }
        }
    }

    Process {
        id: capsProc

        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.capsLock = (JSON.parse(text).keyboards ?? []).some(k => k.main && k.capsLock);
                } catch (e) {}
            }
        }
    }

    // Let the curtain slide up before releasing the lock
    Timer {
        id: unlockTimer

        interval: 380
        onTriggered: {
            root.locked = false;
            root.unlocking = false;
            root.failed = false;
        }
    }
}
