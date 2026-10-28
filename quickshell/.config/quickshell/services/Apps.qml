pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Installed applications for the search launcher and the app menu: search
// scoring, categories (freedesktop main categories folded into a few
// groups, like a start menu) and launching.
Singleton {
    id: root

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // Menu groups: label, icon and the freedesktop categories they take
    readonly property var groups: [
        { id: "internet", label: "Internet", icon: Icons.globe, cats: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
        { id: "multimedia", label: "Multimedia", icon: Icons.music, cats: ["AudioVideo", "Audio", "Video", "Player", "Recorder"] },
        { id: "graphics", label: "Graphics", icon: Icons.image, cats: ["Graphics", "Photography", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics"] },
        { id: "office", label: "Office", icon: Icons.document, cats: ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "Viewer"] },
        { id: "development", label: "Development", icon: Icons.code, cats: ["Development", "IDE", "TextEditor"] },
        { id: "games", label: "Games", icon: Icons.gamepad, cats: ["Game"] },
        { id: "education", label: "Education", icon: Icons.school, cats: ["Education", "Science"] },
        { id: "utilities", label: "Utilities", icon: Icons.tools, cats: ["Utility", "Accessories", "Archiving", "Compression", "FileManager", "TerminalEmulator"] },
        { id: "settings", label: "Settings", icon: Icons.cog, cats: ["Settings", "DesktopSettings", "HardwareSettings"] },
        { id: "system", label: "System", icon: Icons.chip, cats: ["System", "Monitor", "PackageManager", "Security"] }
    ]

    // The first group whose categories an app lists ("other" if none)
    function groupOf(app: var): string {
        const cats = app.categories ?? [];
        for (const g of groups) {
            if (g.cats.some(c => cats.includes(c)))
                return g.id;
        }
        return "other";
    }

    // group id -> apps, only groups that have apps (with "other" last)
    readonly property var byGroup: {
        const out = {};
        for (const app of apps) {
            const g = groupOf(app);
            (out[g] = out[g] ?? []).push(app);
        }
        return out;
    }

    readonly property var menuGroups: {
        const list = [{ id: "all", label: "All apps", icon: Icons.grid }];
        for (const g of groups) {
            if (byGroup[g.id])
                list.push(g);
        }
        if (byGroup.other)
            list.push({ id: "other", label: "Other", icon: Icons.box });
        return list;
    }

    function inGroup(id: string): var {
        return id === "all" ? apps : (byGroup[id] ?? []);
    }

    // Best matches first: name start, word start, name, then other fields
    function search(query: string, from: var): var {
        const q = query.trim().toLowerCase();
        const list = from ?? apps;
        if (!q)
            return list;
        const scored = [];
        for (const app of list) {
            const name = app.name.toLowerCase();
            let score = 0;
            if (name.startsWith(q))
                score = 4;
            else if (name.split(/[\s-]/).some(w => w.startsWith(q)))
                score = 3;
            else if (name.includes(q))
                score = 2;
            else if ([app.genericName, app.comment, app.id, ...(app.keywords ?? [])].some(s => s && s.toLowerCase().includes(q)))
                score = 1;
            if (score > 0)
                scored.push({ app, score });
        }
        return scored.sort((a, b) => b.score - a.score).map(s => s.app);
    }

    function launch(app: var): void {
        if (app.runInTerminal) {
            // DesktopEntry.execute() ignores Terminal=true
            const cmd = (app.command ?? []).filter(arg => !/^%[fFuUdDnNickvm]$/.test(arg));
            Quickshell.execDetached(["kitty", "-e", ...cmd]);
        } else {
            app.execute();
        }
    }
}
