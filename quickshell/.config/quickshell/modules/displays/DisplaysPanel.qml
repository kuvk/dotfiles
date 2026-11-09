import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Display settings: drag monitors to arrange them (they snap edge to edge),
// pick resolution and scale, turn monitors on/off, assign workspaces, set
// brightness and text size. Changes are saved per setup by hyprdori-monitors.
FloatingWindow {
    id: root

    readonly property bool shown: Panels.displays
    readonly property var scalePresets: [1, 1.25, 1.333333, 1.5, 1.6, 1.666667, 1.75, 2, 2.5, 3, 4]
    // Hyprland's per-monitor vrr values, and color modes (cm)
    readonly property var vrrNames: ["Off", "Always", "Fullscreen", "Games and video"]
    readonly property var colorNames: ({
            srgb: "sRGB",
            edid: "Built-in"
        })
    readonly property var colorModes: ["srgb", "edid"]

    // Editable copy of Displays.info
    property var mons: []
    property var workspaces: ({})
    property int textSize: 12
    property string primary: ""
    property int selected: 0
    property bool dirty: false

    readonly property var current: mons[selected] ?? null
    readonly property var enabledMons: mons.filter(m => m.enabled)

    function load(): void {
        const s = Displays.info;
        mons = (s.monitors ?? []).map(m => Object.assign({}, m));
        workspaces = Object.assign({}, s.workspaces ?? {});
        textSize = s.text_size ?? 12;
        primary = s.primary ?? "";
        selected = Math.min(selected, Math.max(0, mons.length - 1));
        dirty = false;
    }

    // Logical size follows mode and scale (rotated outputs swap sides)
    function sized(m: var): var {
        const r = /(\d+)x(\d+)/.exec(m.mode);
        let w = r ? parseInt(r[1]) : 1920, h = r ? parseInt(r[2]) : 1080;
        if (m.transform % 2 === 1)
            [w, h] = [h, w];
        return Object.assign({}, m, {
            width: w / m.scale,
            height: h / m.scale
        });
    }

    function overlaps(a: var, b: var): bool {
        const e = 0.5;
        return a.x < b.x + b.width - e && a.x + a.width > b.x + e && a.y < b.y + b.height - e && a.y + a.height > b.y + e;
    }

    // Closest position touching another monitor without overlapping any
    function snap(m: var, x: real, y: real, others: var): var {
        if (others.length === 0)
            return { x: 0, y: 0 };
        const near = (v, target, range) => Math.abs(v - target) < range ? target : v;
        const candidates = [];
        for (const o of others) {
            // beside: keep vertical overlap, snap to top/bottom alignment when close
            let cy = Math.max(o.y - m.height + 1, Math.min(o.y + o.height - 1, y));
            cy = near(near(cy, o.y, o.height * 0.1), o.y + o.height - m.height, o.height * 0.1);
            candidates.push({ x: o.x + o.width, y: cy }, { x: o.x - m.width, y: cy });
            // above/below: keep horizontal overlap, snap to left/right/center
            let cx = Math.max(o.x - m.width + 1, Math.min(o.x + o.width - 1, x));
            cx = near(near(near(cx, o.x, o.width * 0.1), o.x + o.width - m.width, o.width * 0.1), o.x + (o.width - m.width) / 2, o.width * 0.05);
            candidates.push({ x: cx, y: o.y + o.height }, { x: cx, y: o.y - m.height });
        }
        let best = null, bestDist = Infinity;
        for (const c of candidates) {
            const placed = Object.assign({}, m, { x: c.x, y: c.y });
            if (others.some(o => overlaps(placed, o)))
                continue;
            const d = Math.hypot(c.x - x, c.y - y);
            if (d < bestDist) {
                best = c;
                bestDist = d;
            }
        }
        return best ?? { x: m.x, y: m.y };
    }

    // Shift so the layout starts at 0,0, then resolve overlaps left to right
    function normalize(list: var): var {
        let out = list.map(m => sized(m));
        const on = out.filter(m => m.enabled).sort((a, b) => a.x - b.x || a.y - b.y);
        const placed = [];
        for (const m of on) {
            if (placed.some(o => overlaps(m, o))) {
                const p = snap(m, m.x, m.y, placed);
                m.x = p.x;
                m.y = p.y;
            }
            placed.push(m);
        }
        if (placed.length > 0) {
            const minX = Math.min(...placed.map(m => m.x));
            const minY = Math.min(...placed.map(m => m.y));
            for (const m of placed) {
                m.x = Math.round(m.x - minX);
                m.y = Math.round(m.y - minY);
            }
        }
        return out;
    }

    function update(index: int, changes: var): void {
        const list = mons.slice();
        list[index] = Object.assign({}, list[index], changes);
        mons = normalize(list);
        dirty = true;
    }

    function move(index: int, x: real, y: real): void {
        const m = mons[index];
        const others = mons.filter((o, i) => i !== index && o.enabled);
        const p = snap(m, x, y, others);
        update(index, { x: p.x, y: p.y });
    }

    function setEnabled(index: int, on: bool): void {
        if (!on && enabledMons.length <= 1)
            return; // keep at least one screen
        if (on) {
            // place a re-enabled monitor to the right of the others
            const right = Math.max(0, ...enabledMons.map(m => m.x + m.width));
            update(index, { enabled: true, x: right, y: 0 });
        } else {
            update(index, { enabled: false });
        }
    }

    // Hyprland accepts only scales that divide the mode into whole logical
    // pixels, in 1/120 steps; round up to the next one
    function cleanScale(scale: real, mode: string): real {
        const r = /(\d+)x(\d+)/.exec(mode);
        if (!r)
            return scale;
        const gcd = (a, b) => b ? gcd(b, a % b) : a;
        const g = gcd(parseInt(r[1]) * 120, parseInt(r[2]) * 120);
        let k = Math.max(1, Math.min(g, Math.round(scale * 120)));
        while (g % k !== 0)
            k++;
        return Math.round(k / 120 * 1e6) / 1e6;
    }

    function validScales(mode: string): var {
        const out = [];
        for (const p of scalePresets) {
            const c = cleanScale(p, mode);
            if (!out.some(v => Math.abs(v - c) < 1e-4))
                out.push(c);
        }
        return out;
    }

    function setMode(index: int, mode: string): void {
        update(index, { mode: mode, scale: cleanScale(mons[index].scale, mode) });
    }

    // Primary first, then left to right; at most 5 each (1-5 / 6-10, or 3 each with three)
    function defaultWorkspaces(): void {
        const on = enabledMons.slice().sort((a, b) => (b.id === primary) - (a.id === primary) || a.x - b.x || a.y - b.y);
        const per = on.length ? Math.min(5, Math.floor(10 / on.length)) : 0;
        const w = {};
        let ws = 1;
        for (const m of on)
            for (let i = 0; i < per; i++)
                w[String(ws++)] = m.id;
        workspaces = w;
        dirty = true;
    }

    function cycle(list: var, value: var, step: int): var {
        let i = list.findIndex(v => Math.abs(Number(v) - Number(value)) < 0.001 || v === value);
        if (i < 0)
            i = 0;
        return list[(i + step + list.length) % list.length];
    }

    // Click: assign to the selected monitor, or unassign if it already is
    function toggleWorkspace(ws: int): void {
        const w = Object.assign({}, workspaces);
        if (w[String(ws)] === current.id)
            delete w[String(ws)];
        else
            w[String(ws)] = current.id;
        workspaces = w;
        dirty = true;
    }

    function monitorName(id: string): string {
        return mons.find(m => m.id === id)?.name ?? "";
    }

    function applyChanges(): void {
        Displays.apply({
            monitors: mons.map(m => ({ id: m.id, enabled: m.enabled, mode: m.mode, x: m.x, y: m.y, scale: m.scale, transform: m.transform, vrr: m.vrr, cm: m.cm, bitdepth: m.bitdepth })),
            workspaces: workspaces,
            text_size: textSize,
            primary: primary
        });
        dirty = false;
    }

    visible: shown
    title: "Displays"
    color: Theme.panelBg
    // grows with wider fonts (e.g. a monospaced Nerd Font) so the content
    // never runs into the right edge
    implicitWidth: Math.max(Math.round(760 * Theme.textScale), Math.ceil(content.implicitWidth + 32))
    implicitHeight: Math.ceil(content.implicitHeight + 32)
    // can grow, not shrink below the default size
    minimumSize: Qt.size(implicitWidth, implicitHeight)

    // created on each opening (LazyLoader in shell.qml)
    Component.onCompleted: {
        load();
        Displays.refresh();
        background.forceActiveFocus();
    }

    Connections {
        target: Displays

        function onInfoChanged(): void {
            if (!root.dirty)
                root.load();
        }
    }

    // A regular window (floating and centered by a Hyprland rule, can be
    // tiled); closing it from Hyprland updates the panel state
    onClosed: Panels.displays = false

    Rectangle {
        id: background

        anchors.fill: parent
        color: Theme.panelBg
        focus: root.shown
        Keys.onEscapePressed: Panels.displays = false

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            SectionHeader {
                title: "Displays"

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Displays.busy
                    text: "Applying…"
                    color: Theme.subtext
                }

                CloseButton {
                    onClicked: Panels.displays = false
                }
            }

            MonitorCanvas {
                panel: root
            }

            MonitorPicker {
                panel: root
            }

            MonitorOptions {
                panel: root
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.selection
            }

            TextSize {
                panel: root
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: "Saved for this combination of monitors"
                    color: Theme.dimText
                    font.pixelSize: Theme.captionSize
                }

                TextButton {
                    text: "Revert"
                    enabled: root.dirty
                    onClicked: root.load()
                }

                TextButton {
                    text: "Apply"
                    primary: true
                    enabled: root.dirty && !Displays.busy
                    onClicked: root.applyChanges()
                }
            }
        }
    }
}
