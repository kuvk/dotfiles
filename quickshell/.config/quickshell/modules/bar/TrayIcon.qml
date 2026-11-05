import QtQuick
import QtQuick.Effects
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config

// A tray app's icon in one of three styles (Settings > Tray & Player):
// original, tinted toward the theme, or monochrome (a solid theme-colored
// silhouette cut out by the icon's own transparency, so it stays readable).
// Apps listed in "Keep original colors" always keep theirs, for icons whose
// color means something (e.g. ROG Control Center's dGPU state).
Item {
    id: root

    required property SystemTrayItem item
    property int size: 15

    readonly property bool keepColors: {
        const norm = s => (s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const id = norm(item.id), title = norm(item.title);
        return Config.trayKeepColors.split(",").map(norm).filter(k => k).some(k => id.includes(k) || title.includes(k));
    }
    readonly property string mode: keepColors ? "original" : Config.trayMonochrome ? "mono" : Config.trayTint ? "tinted" : "original"

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: icon

        anchors.fill: parent
        source: {
            // Some apps (Steam, Discord, ...) send "name?path=/dir"
            let src = root.item.icon;
            if (src.includes("?path=")) {
                const [name, path] = src.split("?path=");
                src = `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
            }
            return src;
        }
        // in monochrome mode it only serves as the mask below
        visible: root.mode !== "mono"
        layer.enabled: root.mode !== "original"
        layer.effect: MultiEffect {
            colorization: root.mode === "tinted" ? 0.5 : 0
            colorizationColor: Theme.highlight
        }
    }

    Rectangle {
        id: fill

        anchors.fill: parent
        visible: false
        layer.enabled: root.mode === "mono"
        color: Theme.text
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.mode === "mono"
        source: fill
        maskEnabled: true
        maskSource: icon
        maskThresholdMin: 0.2
        maskSpreadAtMin: 0.3
    }
}
