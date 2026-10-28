import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Omarchy-style wallpaper carousel: the selected wallpaper is a large slanted
// card in the middle, the others are narrow slanted slices to the left and
// right. Same picker for static (~/Pictures/Wallpapers) and live
// (~/Pictures/WallpapersLive) wallpapers; Tab switches between them.
//
// ←/→ or scroll: move   type: search   Enter: all monitors
// Shift+Enter: this monitor   Tab: static/live   Delete: stop live   Esc: close
PanelWindow {
    id: root

    readonly property string kind: Panels.wallpapers
    readonly property bool shown: kind !== ""
    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/wallpaper.py"

    property var items: []
    property string query: ""
    property int selected: 0
    property bool loading: false
    property string loadedKind: ""
    property int retries: 0
    // the user moved since opening; until then a refreshed list re-selects
    // the current wallpaper
    property bool moved: false

    // Lists kept between openings and loaded at startup (like Omarchy's
    // picker rows), so the previews are there the moment it opens; every
    // opening refreshes them in the background.
    property var cache: ({ static: null, live: null })

    // A freshly mapped layer surface starts with a small size and scale 1;
    // the output's real size and (fractional) scale arrive a frame or two
    // later. Cards built before that never showed until Tab rebuilt them.
    // As in Omarchy's OverlayWindow, the content stays transparent and the
    // cards aren't created until the window matches its monitor.
    readonly property var targetMonitor: {
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++) {
            if (screen && mons[i].name === screen.name)
                return mons[i];
        }
        return null;
    }
    readonly property bool contentReady: shown && backingWindowVisible && !!screen && width === screen.width && height === screen.height && !!targetMonitor && Math.round(devicePixelRatio * 120) === Math.round(targetMonitor.scale * 120)
    property bool contentRevealed: false

    onContentReadyChanged: {
        contentRevealed = false;
        // size and scale notifications arrive while Qt is still updating the
        // window; reveal on the next turn, once the layout has caught up
        if (contentReady)
            Qt.callLater(() => {
                if (root.contentReady)
                    root.contentRevealed = true;
            });
    }

    // never stay invisible if the scale check can't match (odd scale rounding)
    Timer {
        interval: 600
        running: root.shown && !root.contentRevealed
        onTriggered: root.contentRevealed = true
    }

    function currentIndex(list: var): int {
        return Math.max(0, list.findIndex(i => i.current));
    }

    function jumpTo(index: int): void {
        jump = true;
        selected = index;
        jump = false;
    }

    function useList(kind: string, list: var): void {
        const c = Object.assign({}, cache);
        c[kind] = list;
        cache = c;
        if (kind !== root.kind)
            return;
        const first = loadedKind !== kind;
        loadedKind = kind;
        if (JSON.stringify(list) === JSON.stringify(items))
            return; // unchanged: keep the cards as they are
        const path = shownItems[selected]?.path;
        items = list;
        if (first || !moved)
            jumpTo(currentIndex(shownItems));
        else
            jumpTo(Math.max(0, shownItems.findIndex(i => i.path === path)));
    }

    readonly property var shownItems: {
        const q = query.toLowerCase();
        return q ? items.filter(i => i.name.toLowerCase().includes(q)) : items;
    }

    // Animated selection: every card's size and place derive from it, so the
    // middle card shrinks exactly as fast as its neighbour grows (no gaps).
    // Driven by hand: a Behavior kept running after a jump and left the
    // carousel parked at 0 with the cards off-screen on every open.
    property real position: 0
    // skip the animation when jumping to the current wallpaper on open
    property bool jump: false

    onSelectedChanged: {
        positionAnim.stop();
        if (jump || !shown || Theme.animDuration === 0) {
            position = selected;
        } else {
            positionAnim.from = position;
            positionAnim.to = selected;
            positionAnim.start();
        }
    }

    NumberAnimation {
        id: positionAnim

        target: root
        property: "position"
        duration: Theme.animDuration * 2
        easing.type: Easing.OutCubic
    }

    // Card geometry from the monitor size (the window may not be mapped yet)
    readonly property real screenWidth: screen?.width ?? 1920
    readonly property real cardHeight: Math.min(475, (screen?.height ?? 1080) * 0.45)
    readonly property real cardWidth: cardHeight * 768 / 475
    readonly property real sliceWidth: cardHeight * 0.23
    readonly property real sliceHeight: cardHeight * 0.91
    readonly property real skew: cardHeight * 0.06
    readonly property real overlap: -cardHeight * 0.06
    readonly property int radius: Math.max(3, Math.ceil((screenWidth - cardWidth) / (2 * (sliceWidth + overlap))) + 2)

    // Thumbnails generated during this opening, per kind
    property var thumbsTried: ({})

    function load(): void {
        // nothing to list while closed (a late retry or re-run used to run
        // `wallpaper.py list ""`, which fails, and kept retrying)
        if (!shown)
            return;
        loading = true;
        // one run at a time: a run still going (previous tab) finishes and
        // is ignored, then the list is read again for the current tab
        if (listProc.running) {
            listProc.again = true;
            return;
        }
        listProc.kind = kind;
        listProc.command = [script, "list", kind];
        listProc.running = true;
    }

    function makeThumbs(): void {
        if (thumbsTried[kind])
            return;
        const tried = Object.assign({}, thumbsTried);
        tried[kind] = true;
        thumbsTried = tried;
        thumbsProc.running = false;
        thumbsProc.kind = kind;
        thumbsProc.command = [script, "thumbs", kind];
        thumbsProc.running = true;
    }

    function move(delta: int): void {
        moved = true;
        if (shownItems.length > 0)
            selected = Math.max(0, Math.min(shownItems.length - 1, selected + delta));
    }

    function apply(thisMonitorOnly: bool): void {
        const item = shownItems[selected];
        if (!item)
            return;
        const cmd = [script, "set", kind, item.path];
        if (thisMonitorOnly && screen)
            cmd.push(screen.name);
        Panels.wallpapers = "";
        // wait for the picker to fade out; live wallpapers need a moment to start playing
        SwitchFx.run(cmd, Theme.animDuration + 250, kind === "live" ? 1200 : 400);
    }

    // Size of the visible slice at fractional distance `d` from the selection
    function lerp(a: real, b: real, t: real): real {
        return a + (b - a) * Math.min(1, Math.abs(t));
    }

    function centerOffset(d: real): real {
        const a = Math.abs(d);
        const first = cardWidth / 2 + overlap + sliceWidth / 2;
        return Math.sign(d) * (a <= 1 ? a * first : first + (a - 1) * (sliceWidth + overlap));
    }

    screen: Panels.overlayScreen ?? Panels.focusedScreen
    visible: reveal.value > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onKindChanged: {
        if (shown) {
            Hyprland.refreshMonitors();
            query = "";
            moved = false;
            retries = 0;
            retry.stop();
            positionAnim.stop();
            // show the kept list at once, then refresh it
            const kept = cache[kind]?.length > 0 ? cache[kind] : null;
            items = kept ?? [];
            loadedKind = kept ? kind : "";
            jumpTo(kept ? currentIndex(items) : 0);
            position = selected;
            load();
            focusTimer.restart();
        } else {
            thumbsTried = {};
            contentRevealed = false;
            retry.stop();
            retries = 0;
            listProc.again = false;
        }
    }

    onQueryChanged: {
        moved = true;
        jumpTo(0);
    }

    Component.onCompleted: preload.next()

    // Startup: fill the cache for both kinds, one after the other
    Process {
        id: preload

        property var pending: ["static", "live"]
        property string kind: ""

        function next(): void {
            if (pending.length === 0)
                return;
            kind = pending[0];
            pending = pending.slice(1);
            command = [root.script, "list", kind];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    if (root.cache[preload.kind] === null)
                        root.useList(preload.kind, list);
                } catch (e) {}
            }
        }
        onExited: Qt.callLater(next)
    }

    // The window may not be mapped yet when the kind changes; focus once it is
    Timer {
        id: focusTimer

        interval: 50
        onTriggered: background.forceActiveFocus()
    }

    Reveal {
        id: reveal

        shown: root.shown
    }

    // `wallpaper.py list KIND`. The result is read when the process exits,
    // so a run that was stopped (or crashed) is never taken for an empty
    // folder; failures are retried with growing delays and logged.
    Process {
        id: listProc

        property string kind: ""
        property bool again: false

        stdout: StdioCollector {
            id: listOut
        }
        stderr: StdioCollector {
            id: listErr
        }

        onExited: (code, status) => {
            // A load came in during this run, or the tab changed: read again
            // for what is shown now (load() does nothing once closed)
            if (again || kind !== root.kind) {
                again = false;
                Qt.callLater(root.load);
                return;
            }
            let list = null;
            if (code === 0 && status === 0) {
                try {
                    list = JSON.parse(listOut.text);
                } catch (e) {}
            }
            // A failed or empty answer is retried (0.2 s doubling to ~6 s in
            // all) before it's believed, and an empty answer never replaces a
            // list that had wallpapers: the kept list stays on screen.
            const known = root.cache[kind]?.length > 0;
            if (list === null || list.length === 0) {
                console.warn(`Wallpapers: list ${kind} ${list === null ? "failed" : "came back empty"} (exit ${code}/${status}, try ${root.retries + 1}): ${listErr.text.trim().slice(-300) || listOut.text.slice(0, 120) || "no output"}`);
                if (root.retries < 5) {
                    retry.interval = 200 * Math.pow(2, root.retries);
                    root.retries++;
                    retry.restart();
                    return;
                }
                if (known) {
                    root.loading = false;
                    return;
                }
                list = list ?? [];
            }
            root.useList(root.kind, list);
            root.loading = false;
            // Fill in missing thumbnails, then reload once
            if (list.some(i => !i.thumb))
                root.makeThumbs();
        }
    }

    Timer {
        id: retry

        onTriggered: if (root.shown) root.load()
    }

    Process {
        id: thumbsProc

        property string kind: ""

        onExited: if (root.shown && kind === root.kind) root.load()
    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: Theme.alpha(Theme.crust, Theme.gamemode ? 1 : 0.6)
        // transparent until the window has its monitor's size and scale
        // (keys still work meanwhile)
        opacity: root.contentRevealed ? reveal.value : 0
        focus: root.shown

        Keys.onPressed: event => {
            const shift = event.modifiers & Qt.ShiftModifier;
            if (event.key === Qt.Key_Escape) {
                if (root.query !== "")
                    root.query = "";
                else
                    Panels.wallpapers = "";
            } else if (event.key === Qt.Key_Left)
                root.move(-1);
            else if (event.key === Qt.Key_Right)
                root.move(1);
            else if (event.key === Qt.Key_Home)
                root.move(-root.shownItems.length);
            else if (event.key === Qt.Key_End)
                root.move(root.shownItems.length);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.apply(shift);
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                Panels.wallpapers = root.kind === "static" ? "live" : "static";
            else if (event.key === Qt.Key_Delete && root.kind === "live") {
                Quickshell.execDetached([root.script, "stop"]);
                Panels.wallpapers = "";
            } else if (event.key === Qt.Key_Backspace)
                root.query = root.query.slice(0, -1);
            else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier)))
                root.query += event.text;
            else
                return;
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.wallpapers = ""
            onWheel: wheel => root.move(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
        }

        // Tabs and search
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: carousel.top
            anchors.bottomMargin: 30
            spacing: 12
            opacity: reveal.value

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: [
                        { kind: "static", label: "Wallpapers" },
                        { kind: "live", label: "Live wallpapers" }
                    ]

                    MouseArea {
                        id: tab

                        required property var modelData
                        readonly property bool current: root.kind === modelData.kind

                        width: tabLabel.implicitWidth + 28
                        height: 32
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Panels.wallpapers = modelData.kind

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: tab.current ? Theme.alpha(Theme.highlight, 0.25) : Theme.alpha(Theme.base, 0.6)
                            border.color: tab.current ? Theme.highlight : "transparent"
                            border.width: Theme.borderWidth
                        }

                        StyledText {
                            id: tabLabel

                            anchors.centerIn: parent
                            text: tab.modelData.label
                            color: tab.current ? Theme.highlight : Theme.subtext0
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 320
                implicitHeight: 34
                radius: height / 2
                color: Theme.alpha(Theme.base, 0.75)
                border.color: root.query !== "" ? Theme.highlight : "transparent"
                border.width: Theme.borderWidth

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        text: Icons.search
                        color: root.query !== "" ? Theme.highlight : Theme.overlay1
                    }

                    StyledText {
                        text: root.query !== "" ? root.query : "Type to search"
                        color: root.query !== "" ? Theme.text : Theme.overlay1
                    }
                }
            }
        }

        Item {
            id: carousel

            anchors.centerIn: parent
            width: parent.width
            height: root.cardHeight
            opacity: reveal.value
            scale: 0.95 + 0.05 * reveal.value

            Repeater {
                model: root.contentRevealed ? root.shownItems : []

                Loader {
                    id: slot

                    required property var modelData
                    required property int index
                    // fractional distance from the (animated) selection
                    readonly property real d: index - root.position
                    readonly property bool isSelected: index === root.selected
                    // visible slice inside the fixed-size card
                    readonly property real visibleWidth: root.lerp(root.cardWidth, root.sliceWidth, d)
                    readonly property real visibleHeight: root.lerp(root.cardHeight, root.sliceHeight, d)
                    readonly property real sliceLeft: (root.cardWidth - visibleWidth) / 2
                    readonly property real sliceTop: (root.cardHeight - visibleHeight) / 2

                    active: Math.abs(index - root.selected) <= root.radius
                    visible: active
                    z: 1000 - Math.round(Math.abs(d) * 10)
                    width: root.cardWidth
                    height: root.cardHeight
                    x: carousel.width / 2 + root.centerOffset(d) - width / 2

                    sourceComponent: Item {
                        id: card

                        // The visible parallelogram is a sheared, clipping
                        // Item (stencil clip, no layers or shader masks, so it
                        // survives the layer window being recreated on show).
                        // The picture inside gets the inverse shear and stays
                        // fixed to the card while the slice grows and shrinks.
                        Item {
                            id: slice

                            readonly property real k: root.skew / Math.max(1, slot.visibleHeight)

                            x: slot.sliceLeft
                            y: slot.sliceTop
                            width: Math.max(0, slot.visibleWidth - root.skew)
                            height: slot.visibleHeight
                            clip: true
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, -slice.k, 0, root.skew, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                            }

                            Item {
                                width: root.cardWidth
                                height: root.cardHeight
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, slice.k, 0, -(slot.sliceLeft + slice.k * slot.sliceTop + root.skew), 0, 1, 0, -slot.sliceTop, 0, 0, 1, 0, 0, 0, 0, 1)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.surface0
                                }

                                Image {
                                    anchors.fill: parent
                                    source: slot.modelData.thumb ? "file://" + slot.modelData.thumb : (root.kind === "static" ? "file://" + slot.modelData.path : "")
                                    sourceSize.width: 1024
                                    sourceSize.height: 640
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    visible: !slot.modelData.thumb && root.kind === "live"
                                    text: Icons.play
                                    color: Theme.overlay1
                                    font.pixelSize: 28
                                }
                            }

                            // dim the slices
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.crust
                                opacity: Math.min(1, Math.abs(slot.d)) * 0.45
                            }
                        }

                        // Outline
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: slot.isSelected ? Theme.accent : Theme.alpha(Theme.crust, 0.9)
                                // also smooths the clip's hard slanted edge
                                strokeWidth: slot.isSelected ? Math.max(2, Theme.borderWidth) : 1.5
                                startX: slot.sliceLeft + root.skew
                                startY: slot.sliceTop
                                PathLine { x: slot.sliceLeft + slot.visibleWidth; y: slot.sliceTop }
                                PathLine { x: slot.sliceLeft + slot.visibleWidth - root.skew; y: slot.sliceTop + slot.visibleHeight }
                                PathLine { x: slot.sliceLeft; y: slot.sliceTop + slot.visibleHeight }
                                PathLine { x: slot.sliceLeft + root.skew; y: slot.sliceTop }
                            }
                        }

                        // Current wallpaper marker
                        Rectangle {
                            visible: slot.modelData.current && slot.isSelected
                            x: slot.sliceLeft + slot.visibleWidth - 22
                            y: slot.sliceTop + 12
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.accent
                        }

                        // Clicks only on the visible slice
                        MouseArea {
                            x: slot.sliceLeft
                            y: slot.sliceTop
                            width: slot.visibleWidth
                            height: slot.visibleHeight
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (slot.isSelected) {
                                    root.apply(false);
                                } else {
                                    root.moved = true;
                                    root.selected = slot.index;
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: carousel.bottom
            anchors.topMargin: 28
            spacing: 6
            opacity: reveal.value

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (root.loading && root.items.length === 0)
                        return "Loading…";
                    if (root.items.length === 0)
                        return `Nothing in ~/Pictures/${root.kind === "live" ? "WallpapersLive" : "Wallpapers"}`;
                    if (root.shownItems.length === 0)
                        return `No match for "${root.query}"`;
                    return root.shownItems[root.selected]?.name ?? "";
                }
                font.pixelSize: Theme.fontSize + 3
                font.weight: Font.DemiBold
                style: Text.Outline
                styleColor: Theme.alpha(Theme.crust, 0.6)
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: `${root.shownItems.length ? root.selected + 1 : 0} / ${root.shownItems.length}   ·   Enter: all monitors   ·   Shift+Enter: this monitor   ·   Tab: ${root.kind === "static" ? "live" : "static"}${root.kind === "live" ? "   ·   Del: stop live" : ""}`
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
