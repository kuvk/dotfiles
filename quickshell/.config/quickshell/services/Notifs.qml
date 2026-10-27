pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon (replaces swaync). Tracked notifications are the
// history shown in the control center; `popups` are the ones on screen.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []
    property var arrivals: ({}) // notification id -> Date

    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    function dismissPopup(n: Notification): void {
        popups = popups.filter(p => p !== n);
    }

    function clearAll(): void {
        for (const n of list.slice())
            n.dismiss();
        popups = [];
    }

    // Seconds a popup stays up, mirrors the old swaync config
    function timeoutFor(n: Notification): int {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout > 0)
            return n.expireTimeout;
        return n.urgency === NotificationUrgency.Low ? 4 : 8;
    }

    function relativeTime(n: Notification, now: date): string {
        const t = arrivals[n.id];
        if (!t)
            return "";
        const mins = Math.floor((now - t) / 60000);
        if (mins < 1)
            return "now";
        if (mins < 60)
            return `${mins}m`;
        const hours = Math.floor(mins / 60);
        return hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`;
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const arrivals = Object.assign({}, root.arrivals);
            arrivals[n.id] = new Date();
            root.arrivals = arrivals;
            n.closed.connect(() => root.dismissPopup(n));
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [...root.popups.filter(p => p.id !== n.id), n];
        }
    }
}
