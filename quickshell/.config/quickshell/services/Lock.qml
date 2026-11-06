pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam

// Lock state and the password check, for the lock surfaces on every screen
// (modules/lock/LockScreen.qml). After Omarchy's lock (shell/plugins/lock,
// github.com/basecamp/omarchy, MIT):
// - the password goes through the system's own PAM stack (/etc/pam.d/login, root's to
//   change), the same as hyprlock used;
// - locking waits until a real screen is there: after a sleep the monitors come back one
//   by one, and with the laptop's screen off there's a moment with only Hyprland's
//   FALLBACK output;
// - the lock outlives the shell: its state is kept in the runtime folder, so a reload
//   (editing a shell file) or a restart after a crash locks again at once. Hyprland keeps
//   the session locked meanwhile (misc:allow_session_lock_restore lets the new one in).
Singleton {
    id: root

    readonly property string userName: Quickshell.env("USER")
    readonly property string stateFile: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lock"

    // Asked to lock: true from lock() until the right password. Read from the state file
    // when the shell starts, before the lock surfaces exist.
    property bool locked: lockState.text().trim() === "locked"
    // The session lock is up on every screen (WlSessionLock.secure)
    property bool secure: false
    // The monitor with the clock and password: the one focused when locking
    property string mainScreen: ""

    property string password: ""
    property bool authenticating: false
    property bool failed: false
    property bool capsLock: false

    function lock(): void {
        if (locked)
            return;
        mainScreen = Hyprland.focusedMonitor?.name ?? "";
        clearPassword();
        locked = true;
    }

    function clearPassword(): void {
        password = "";
        failed = false;
    }

    function submit(): void {
        if (!locked || authenticating || password === "")
            return;
        failed = false;
        authenticating = true;
        if (!pam.start()) {
            authenticating = false;
            failed = true;
            password = "";
        }
    }

    function checkCapsLock(): void {
        capsProc.running = true;
    }

    // No pointer on the lock screen; shown again after a reload or crash while unlocked
    function setCursorHidden(hidden: bool): void {
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ cursor = { invisible = ${hidden} } })`]);
    }

    onLockedChanged: {
        lockState.setText(locked ? "locked\n" : "unlocked\n");
        setCursorHidden(locked);
        if (locked)
            checkCapsLock();
    }

    Component.onCompleted: setCursorHidden(locked)

    FileView {
        id: lockState

        path: root.stateFile
        blockLoading: true
        printErrors: false
    }

    PamContext {
        id: pam

        config: "login"
        user: root.userName
        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }
        onCompleted: result => {
            root.authenticating = false;
            root.password = "";
            if (result === PamResult.Success) {
                root.failed = false;
                root.locked = false;
            } else {
                root.failed = true;
            }
        }
        onError: {
            root.authenticating = false;
            root.password = "";
            root.failed = true;
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
}
