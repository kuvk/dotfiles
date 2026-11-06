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
// - the lock outlives the shell: Hyprland keeps the session locked when the shell goes
//   away (a reload, or a crash), and a shell starting while Hyprland holds a lock nobody
//   else draws locks again at once (misc:allow_session_lock_restore lets it in).
// Unlike Omarchy's, it doesn't turn the screens off while locked: with Hyprland on the
// laptop's Intel + NVIDIA, the NVIDIA GPU left without a lit output crashed Hyprland (DPMS off,
// or a monitor dropping out on wake). The screens go off when the machine sleeps.
// scripts/sleep-lock.sh asks for the lock before every suspend and waits for `secure`.
Singleton {
    id: root

    readonly property string userName: Quickshell.env("USER")

    // Asked to lock: true from lock() until the right password
    property bool locked: false
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
        setCursorHidden(locked);
        if (locked)
            checkCapsLock();
    }

    Component.onCompleted: {
        setCursorHidden(false);
        strandedProc.running = true;
    }

    // Hyprland lists a held session lock (LOCK) among the reasons a monitor can't go
    // solitary, and keeps it when the lock screen's program is gone. Held with no other
    // lock program running, it's this shell's from before a reload or crash: lock again.
    Process {
        id: strandedProc

        command: ["sh", "-c", "! pgrep -x hyprlock >/dev/null && hyprctl -j monitors | jq -e 'any(.[]; (.solitaryBlockedBy // []) | index(\"LOCK\"))' >/dev/null"]
        onExited: code => {
            if (code === 0)
                root.lock();
        }
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
