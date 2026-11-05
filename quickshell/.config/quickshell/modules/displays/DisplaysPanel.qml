import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Display settings: drag monitors to arrange them (they snap edge to edge),
// pick resolution and scale, turn monitors on/off, assign workspaces, set
// brightness and text size. Changes are saved per setup by hypr-monitors.py.
FloatingWindow {
    id: root

    readonly property bool shown: Panels.displays
    readonly property var scalePresets: [1, 1.25, 1.333333, 1.5, 1.6, 1.666667, 1.75, 2, 2.5, 3, 4]

    // Editable copy of Displays.info
    property var mons: []
    property var workspaces: ({})
    property int textSize: 13
    property string primary: ""
    property int selected: 0
    property bool dirty: false

    readonly property var current: mons[selected] ?? null
    readonly property var enabledMons: mons.filter(m => m.enabled)

    function load(): void {
        const s = Displays.info;
        mons = (s.monitors ?? []).map(m => Object.assign({}, m));
        workspaces = Object.assign({}, s.workspaces ?? {});
        textSize = s.text_size ?? 13;
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
    // pixels, in 1/120 steps (same rule Omarchy uses); round up to the next one
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
            monitors: mons.map(m => ({ id: m.id, enabled: m.enabled, mode: m.mode, x: m.x, y: m.y, scale: m.scale, transform: m.transform })),
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
    implicitWidth: Math.max(760, Math.ceil(content.implicitWidth + 32))
    implicitHeight: Math.ceil(content.implicitHeight + 32)

    onShownChanged: {
        if (shown) {
            load();
            Displays.refresh();
            background.forceActiveFocus();
        }
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
                    color: Theme.subtext0
                }

                CloseButton {
                    onClicked: Panels.displays = false
                }
            }

            // Arrangement
            Rectangle {
                id: area

                readonly property var bounds: {
                    const on = root.enabledMons;
                    if (on.length === 0)
                        return { x: 0, y: 0, w: 1, h: 1 };
                    const x = Math.min(...on.map(m => m.x)), y = Math.min(...on.map(m => m.y));
                    return {
                        x: x,
                        y: y,
                        w: Math.max(...on.map(m => m.x + m.width)) - x,
                        h: Math.max(...on.map(m => m.y + m.height)) - y
                    };
                }
                readonly property real factor: Math.min((width - 60) / bounds.w, (height - 40) / bounds.h)
                readonly property real offsetX: (width - bounds.w * factor) / 2
                readonly property real offsetY: (height - bounds.h * factor) / 2

                Layout.fillWidth: true
                implicitHeight: 230
                radius: Theme.smallRadius
                color: Theme.alpha(Theme.crust, 0.6)

                Repeater {
                    model: root.mons

                    Item {
                        id: tile

                        required property var modelData
                        required property int index
                        property real dragX: 0
                        property real dragY: 0

                        visible: modelData.enabled
                        x: area.offsetX + (modelData.x - area.bounds.x) * area.factor + dragX
                        y: area.offsetY + (modelData.y - area.bounds.y) * area.factor + dragY
                        width: modelData.width * area.factor
                        height: modelData.height * area.factor
                        z: dragArea.pressed ? 2 : 1

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: tile.index === root.selected ? Theme.alpha(Theme.highlight, 0.3) : Theme.surface0
                            border.color: tile.index === root.selected ? Theme.highlight : Theme.surface2
                            border.width: 2

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tile.modelData.name
                                    font.weight: Font.Bold
                                    color: tile.index === root.selected ? Theme.highlight : Theme.text
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: `${Math.round(tile.modelData.width)}×${Math.round(tile.modelData.height)}`
                                    color: Theme.subtext0
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }
                        }

                        MouseArea {
                            id: dragArea

                            property point start

                            anchors.fill: parent
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: mouse => {
                                root.selected = tile.index;
                                start = mapToItem(area, mouse.x, mouse.y);
                            }
                            onPositionChanged: mouse => {
                                const p = mapToItem(area, mouse.x, mouse.y);
                                tile.dragX += p.x - start.x;
                                tile.dragY += p.y - start.y;
                                start = p;
                            }
                            onReleased: {
                                const m = tile.modelData;
                                const x = m.x + tile.dragX / area.factor;
                                const y = m.y + tile.dragY / area.factor;
                                tile.dragX = 0;
                                tile.dragY = 0;
                                if (Math.abs(x - m.x) > 1 || Math.abs(y - m.y) > 1)
                                    root.move(tile.index, x, y);
                            }
                        }
                    }
                }

                StyledText {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 6
                    text: "Drag to arrange"
                    color: Theme.overlay0
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // Monitor picker (also lists disabled monitors)
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.mons

                    MouseArea {
                        id: chip

                        required property var modelData
                        required property int index

                        width: chipText.implicitWidth + 24
                        height: 30
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected = index

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: chip.index === root.selected ? Theme.highlight : Theme.cardBg
                        }

                        StyledText {
                            id: chipText

                            anchors.centerIn: parent
                            text: chip.modelData.name + (chip.modelData.enabled ? "" : " (off)")
                            color: chip.index === root.selected ? Theme.base : (chip.modelData.enabled ? Theme.text : Theme.overlay1)
                        }
                    }
                }
            }

            // Selected monitor
            GridLayout {
                Layout.fillWidth: true
                visible: root.current !== null
                columns: 2
                columnSpacing: 16
                rowSpacing: 10

                StyledText {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    text: root.current ? (root.current.description || root.current.name) : ""
                    color: Theme.subtext0
                }

                StyledText {
                    text: "Enabled"
                }

                Switch {
                    checked: root.current?.enabled ?? false
                    onToggled: root.setEnabled(root.selected, !checked)
                }

                StyledText {
                    text: "Primary"
                }

                RowLayout {
                    spacing: 10

                    Switch {
                        checked: root.current !== null && root.current.id === root.primary
                        onToggled: {
                            root.primary = root.current.id;
                            root.dirty = true;
                        }
                    }

                    StyledText {
                        text: "Gets the first workspaces with Default"
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                StyledText {
                    text: "Resolution"
                }

                Stepper {
                    enabled: root.current?.enabled ?? false
                    text: root.current ? root.current.mode.replace("@", " @ ") + " Hz" : ""
                    onStep: delta => root.setMode(root.selected, root.cycle(root.current.modes, root.current.mode, delta))
                }

                StyledText {
                    text: "Scale"
                }

                Stepper {
                    enabled: root.current?.enabled ?? false
                    text: root.current ? `${Math.round(root.current.scale * 1000) / 10}%  (${Math.round(root.current.width)}×${Math.round(root.current.height)})` : ""
                    onStep: delta => root.update(root.selected, { scale: root.cycle(root.validScales(root.current.mode), root.current.scale, delta) })
                }

                StyledText {
                    text: "Brightness"
                    visible: brightnessSlider.visible
                }

                RowLayout {
                    id: brightnessSlider

                    readonly property var value: root.current ? Displays.brightness[root.current.name] : undefined

                    Layout.fillWidth: true
                    visible: !!root.current?.enabled && value !== undefined && value !== null
                    spacing: 10

                    StyledSlider {
                        Layout.fillWidth: true
                        value: (brightnessSlider.value ?? 0) / 100
                        color: Theme.yellow
                        onMoved: v => Displays.setBrightness(root.current.name, Math.max(1, Math.round(v * 100)))
                    }

                    StyledText {
                        Layout.preferredWidth: 40
                        text: `${brightnessSlider.value ?? 0}%`
                        color: Theme.subtext0
                    }
                }

                StyledText {
                    text: "Workspaces"
                }

                ColumnLayout {
                    spacing: 4

                    RowLayout {
                        spacing: 4

                        Repeater {
                            model: 10

                            MouseArea {
                                id: wsChip

                                required property int index
                                readonly property int ws: index + 1
                                readonly property string owner: root.workspaces[String(ws)] ?? ""
                                readonly property bool mine: root.current !== null && owner === root.current.id

                                implicitWidth: 30
                                implicitHeight: 30
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleWorkspace(ws)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.smallRadius
                                    color: wsChip.mine ? Theme.highlight : (wsChip.containsMouse ? Theme.hoverBg : Theme.cardBg)
                                    // assigned to another monitor
                                    border.color: !wsChip.mine && wsChip.owner !== "" ? Theme.surface2 : "transparent"
                                    border.width: Theme.borderWidth
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: wsChip.ws
                                    color: wsChip.mine ? Theme.base : (wsChip.owner !== "" ? Theme.overlay0 : Theme.subtext0)
                                    font.weight: wsChip.mine ? Font.Bold : Font.Normal
                                }
                            }
                        }

                        TextButton {
                            text: "Default"
                            onClicked: root.defaultWorkspaces()
                        }
                    }

                    StyledText {
                        text: "Click to assign to this monitor, click again to unassign. Outlined ones belong to another monitor."
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.surface1
            }

            // Global
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                StyledText {
                    text: `${Icons.text}  Text size`
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Shell, GTK apps and kitty"
                    color: Theme.overlay1
                    font.pixelSize: Theme.fontSize - 2
                }

                // 9 .. 20 px, 13 is the default
                Stepper {
                    text: `${root.textSize} px${root.textSize === 13 ? " (default)" : ""}`
                    onStep: d => {
                        root.textSize = Math.max(9, Math.min(20, root.textSize + d));
                        root.dirty = true;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: "Saved for this combination of monitors"
                    color: Theme.overlay1
                    font.pixelSize: Theme.fontSize - 2
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
