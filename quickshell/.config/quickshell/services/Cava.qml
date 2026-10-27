pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Audio visualizer data for the player: runs cava with cava.conf (12 bars,
// raw text output) while something plays. `values` holds 0..1 per bar.
Singleton {
    id: root

    readonly property bool active: Config.cava && (Media.active?.isPlaying ?? false)
    property var values: []

    onActiveChanged: if (!active) values = []

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";").filter(p => p !== "");
                root.values = parts.map(p => Math.min(1, parseInt(p) / 100));
            }
        }
    }
}
