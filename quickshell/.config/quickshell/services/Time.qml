pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property date date: clock.date

    SystemClock {
        id: clock

        // nothing shows seconds: updating once a minute is enough
        precision: SystemClock.Minutes
    }
}
