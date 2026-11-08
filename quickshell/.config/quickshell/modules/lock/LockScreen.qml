import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The session lock: a surface on every screen, the clock and password on the main one.
// It goes up once a real screen exists (not only Hyprland's FALLBACK, which a wake with
// the laptop's screen off can leave for a moment) and stays up until the right password,
// whatever the monitors do meanwhile.
Scope {
    id: root

    readonly property bool hasRealScreen: Quickshell.screens.some(s => s.name && s.name !== "FALLBACK" && s.width > 0)
    // Once up, only an unlock takes it down
    property bool engaged: Lock.locked && hasRealScreen

    onHasRealScreenChanged: if (Lock.locked && hasRealScreen) engaged = true

    Connections {
        target: Lock

        function onLockedChanged(): void {
            root.engaged = Lock.locked && root.hasRealScreen;
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: root.engaged
        onSecureStateChanged: Lock.secure = secure
        onLockStateChanged: if (!locked) Lock.secure = false

        WlSessionLockSurface {
            id: surface

            color: Theme.background

            LockView {
                anchors.fill: parent
                screen: surface.screen
            }
        }
    }
}
