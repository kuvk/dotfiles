pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Notification daemon (replaces swaync). Tracked notifications are the
// history shown in the control center; `popups` are the ones on screen.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []
    // a popup's reply box has the keyboard (the popups window takes focus)
    property bool replying: false
    property var arrivals: ({}) // notification id -> Date

    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    // Notifications grouped by app, newest group and newest first:
    // [{ app, icon, list: [Notification] }]
    readonly property var groups: {
        const byApp = new Map();
        for (const n of list.slice().reverse()) {
            const app = appNameOf(n);
            if (!byApp.has(app))
                byApp.set(app, { app: app, icon: appIconOf(n), list: [] });
            byApp.get(app).list.push(n);
        }
        return Array.from(byApp.values());
    }

    function clearGroup(app: string): void {
        for (const n of list.slice())
            if (appNameOf(n) === app)
                n.dismiss();
    }

    // Web apps (webapp.py) notify as their browser ("Brave"), with the site
    // ("web.whatsapp.com", sometimes as a link) on the body's first line.
    // That site names the web app, whose name and icon are shown instead,
    // and the line is dropped. Sites without a web app stay as they are.
    readonly property var siteLine: /^\s*(<a\b[^>]*>)?(https?:\/\/)?((?:[\w-]+\.)+[a-z]{2,})(:\d+)?(\/\S*)?(<\/a>)?((\s*(\n|<br\s*\/?>))+|\s*$)/i

    function webAppOf(n: Notification): var {
        if (!/chrom|brave|vivaldi|edge|opera/i.test(n.appName + " " + n.desktopEntry))
            return null;
        const m = n.body.match(siteLine);
        if (!m)
            return null;
        const host = m[3].toLowerCase().replace(/^www\./, "");
        return DesktopEntries.applications.values.find(e => e.execString.includes(" launch ") && e.execString.toLowerCase().includes(host)) ?? null;
    }

    function appNameOf(n: Notification): string {
        return webAppOf(n)?.name || n.appName || "Notifications";
    }

    function appIconOf(n: Notification): string {
        return webAppOf(n)?.icon || n.appIcon;
    }

    function bodyOf(n: Notification): string {
        return webAppOf(n) ? n.body.replace(siteLine, "").trim() : n.body;
    }

    function dismissPopup(n: Notification): void {
        popups = popups.filter(p => p !== n);
    }

    function clearAll(): void {
        for (const n of list.slice())
            n.dismiss();
        popups = [];
    }

    // Seconds a popup stays up; critical ones stay until closed
    function timeoutFor(n: Notification): int {
        return n.urgency === NotificationUrgency.Critical ? 0 : Config.notificationTimeout;
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
        // a reply box for apps that ask for one (Notification.hasInlineReply)
        inlineReplySupported: true
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
