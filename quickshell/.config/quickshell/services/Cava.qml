pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Audio visualizer data for the player: runs cava (raw text output) while
// something plays. `values` holds 0..1 per bar; Settings > Tray & Player sets
// the number of bars.
Singleton {
    id: root

    readonly property bool active: Config.cava && (Media.active?.isPlaying ?? false)
    readonly property int bars: Config.cavaBars
    property var values: []

    readonly property string configText: `# Written by Quickshell (services/Cava.qml)
[general]
framerate = 30
autosens = 1
bars = ${bars}
sleep_timer = 3

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
channels = mono

[smoothing]
noise_reduction = 60
`

    function restart(): void {
        proc.running = false;
        configFile.setText(configText);
        Qt.callLater(() => proc.running = root.active);
    }

    onActiveChanged: active ? restart() : (proc.running = false, values = [])
    onBarsChanged: if (active) restart()

    FileView {
        id: configFile

        path: Quickshell.statePath("cava.conf")
    }

    Process {
        id: proc

        command: ["cava", "-p", configFile.path]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";").filter(p => p !== "");
                root.values = parts.map(p => Math.min(1, parseInt(p) / 100));
            }
        }
    }
}
