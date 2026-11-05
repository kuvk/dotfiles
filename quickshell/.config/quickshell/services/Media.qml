pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

// The "current" MPRIS player: whichever is playing, unless the user picked one.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer pinned: null

    readonly property MprisPlayer active: {
        if (pinned && players.includes(pinned))
            return pinned;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }

    readonly property string title: active?.trackTitle || fileName(active?.metadata?.["xesam:url"]) || ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string label: artist && title ? `${artist} - ${title}` : title

    function fileName(url: var): string {
        if (!url)
            return "";
        const s = String(url);
        return decodeURIComponent(s.slice(s.lastIndexOf("/") + 1));
    }

    function iconFor(player: MprisPlayer): string {
        const id = ((player?.identity ?? "") + (player?.dbusName ?? "")).toLowerCase();
        if (id.includes("spotify"))
            return Icons.spotify;
        if (id.includes("vlc"))
            return Icons.vlc;
        if (id.includes("firefox"))
            return Icons.firefox;
        if (id.includes("brave"))
            return Icons.globe;
        if (id.includes("chrom"))
            return Icons.chrome;
        return Icons.music;
    }

    function cyclePlayer(): void {
        if (players.length < 2)
            return;
        const i = players.indexOf(active);
        pinned = players[(i + 1) % players.length];
    }

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const s = Math.floor(seconds);
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // MPRIS doesn't push position updates; poke them while something plays
    Timer {
        running: root.active?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.active.positionChanged()
    }
}
