pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: sink?.ready ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property bool micMuted: source?.audio?.muted ?? true

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)

    // Application streams feeding the default sink
    readonly property var streams: linkTracker.linkGroups.map(g => g.source).filter(n => n?.audio && n.isStream)

    readonly property string icon: {
        if (muted)
            return Icons.volumeMuted;
        const name = (sink?.name ?? "") + (sink?.description ?? "");
        if (/head(set|phone)|bluez/i.test(name))
            return Icons.headphones;
        if (volume < 0.34)
            return Icons.volumeOff;
        if (volume < 0.67)
            return Icons.volumeLow;
        return Icons.volumeHigh;
    }

    // Bar icon color: muted disabled (like Bluetooth off), quiet mauve, medium blue, loud green
    readonly property color color: {
        if (muted)
            return Theme.overlay1;
        if (volume <= 0.3)
            return Theme.mauve;
        if (volume <= 0.6)
            return Theme.blue;
        return Theme.green;
    }

    function setVolume(node: PwNode, value: real): void {
        if (!node?.ready || !node.audio)
            return;
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1.2, value));
    }

    function toggleMute(node: PwNode): void {
        if (node?.ready && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    function setDefaultSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function nodeName(node: PwNode): string {
        return node?.description || node?.nickname || node?.properties?.["application.name"] || node?.name || "Unknown";
    }

    PwNodeLinkTracker {
        id: linkTracker

        node: root.sink
    }

    // Bind every node we read volume from, otherwise pipewire won't report it
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.streams]
    }
}
