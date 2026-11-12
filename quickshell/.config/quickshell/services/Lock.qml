pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config

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
// Unlike Omarchy's, it doesn't turn the screens off while locked: on hybrid laptops Hyprland
// doesn't survive the NVIDIA GPU losing all its lit outputs (DPMS off). The screens go off
// when the machine sleeps.
// hyprdori-sleep-lock asks for the lock before every suspend and waits for `secure`.
Singleton {
    id: root

    readonly property string userName: Quickshell.env("USER")

    // Asked to lock: true from lock() until the right password
    property bool locked: false
    // The session lock is up on every screen (WlSessionLock.secure)
    property bool secure: false
    // The monitor with the avatar and password: the one focused when locking, then whichever
    // the mouse moves to (LockView), as on the login screen
    property string mainScreen: ""

    // The background: the theme's own (Theme.backgroundImage, hyprdori-theme-set) unless the user chose an
    // image in Settings > Style > Lock screen (the theme's when that can't be read). Whenever it
    // changes, `hyprdori-wallpaper lock` makes it ready to load at once (a copy scaled to the
    // largest screen when it's bigger, also given to the login screen), so locking never
    // waits for a large picture and nothing stays loaded while unlocked.
    // an image that couldn't be read; choosing another one tries again
    property string failedImage: ""
    readonly property string backgroundPath: !Config.lockFollowsTheme && Config.lockImage !== "" && Config.lockImage !== failedImage ? Config.lockImage : Theme.backgroundImage
    // file://path?v=stamp of the file to show
    property string background: ""

    property string password: ""
    property bool authenticating: false
    property bool failed: false
    property bool capsLock: false

    function prepareBackground(): void {
        if (backgroundPath === "")
            return;
        if (prepareProc.running) {
            prepareProc.again = true;
            return;
        }
        prepareProc.path = backgroundPath;
        prepareProc.running = true;
    }

    onBackgroundPathChanged: prepareBackground()

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

    onLockedChanged: if (locked) checkCapsLock()

    Component.onCompleted: {
        strandedProc.running = true;
        prepareBackground();
    }

    // a larger monitor may need a larger copy (made again only then)
    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            root.prepareBackground();
        }
    }

    Process {
        id: prepareProc

        property string path
        // asked again while running
        property bool again: false

        command: [Quickshell.env("HOME") + "/.local/bin/hyprdori-wallpaper", "lock", path]
        stdout: StdioCollector {
            onStreamFinished: {
                const [file, stamp] = text.trim().split("\t");
                if (file && stamp && prepareProc.path === root.backgroundPath)
                    root.background = `file://${file}?v=${stamp}`;
            }
        }
        onExited: code => {
            // the chosen image can't be read: the theme's background
            if (code !== 0 && path === Config.lockImage && !Config.lockFollowsTheme)
                root.failedImage = path;
            if (again || path !== root.backgroundPath) {
                again = false;
                Qt.callLater(root.prepareBackground);
            }
        }
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
