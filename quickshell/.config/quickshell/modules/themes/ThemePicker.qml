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

// Theme picker as a carousel, the same as the wallpaper picker: the selected
// theme is a large slanted card in the middle, the others narrow slices. Each
// card is a palette preview: a small mock desktop drawn in that theme's
// colors (bar, window with code, swatches).
//
// ←/→ or scroll: move   type: search   Enter: apply   Esc: clear, then close
PanelWindow {
    id: root

    readonly property bool shown: Panels.themes
    readonly property string themeSet: Quickshell.env("HOME") + "/.config/scripts/theme-set.py"

    property var items: []
    property string query: ""
    property int selected: 0
    property bool moved: false

    readonly property var shownItems: {
        const q = query.toLowerCase();
        return q ? items.filter(i => i.name.toLowerCase().includes(q) || i.theme.includes(q)) : items;
    }

    // Same reveal rules as the wallpaper picker: no cards until the fresh
    // layer surface has its monitor's size and scale
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
        if (contentReady)
            Qt.callLater(() => {
                if (root.contentReady)
                    root.contentRevealed = true;
            });
    }

    Timer {
        interval: 600
        running: root.shown && !root.contentRevealed
        onTriggered: root.contentRevealed = true
    }

    // Animated selection, driven by hand (see WallpaperPicker)
    property real position: 0
    property bool jump: false

    onSelectedChanged: {
        positionAnim.stop();
        if (jump || !Panels.themes || Theme.animDuration === 0) {
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

    function jumpTo(index: int): void {
        jump = true;
        selected = index;
        jump = false;
    }

    function useList(list: var): void {
        if (JSON.stringify(list) === JSON.stringify(items))
            return;
        const name = shownItems[selected]?.theme;
        items = list;
        if (!moved)
            jumpTo(Math.max(0, shownItems.findIndex(i => i.current)));
        else
            jumpTo(Math.max(0, shownItems.findIndex(i => i.theme === name)));
    }

    // Card geometry from the monitor size
    readonly property real screenWidth: screen?.width ?? 1920
    readonly property real cardHeight: Math.min(475, (screen?.height ?? 1080) * 0.45)
    readonly property real cardWidth: cardHeight * 768 / 475
    readonly property real sliceWidth: cardHeight * 0.23
    readonly property real sliceHeight: cardHeight * 0.91
    readonly property real skew: cardHeight * 0.06
    readonly property real overlap: -cardHeight * 0.06
    readonly property int radius: Math.max(3, Math.ceil((screenWidth - cardWidth) / (2 * (sliceWidth + overlap))) + 2)

    function move(delta: int): void {
        moved = true;
        if (shownItems.length > 0)
            selected = Math.max(0, Math.min(shownItems.length - 1, selected + delta));
    }

    function apply(): void {
        const item = shownItems[selected];
        if (!item)
            return;
        Panels.themes = false;
        // after the picker has faded out
        SwitchFx.run([themeSet, item.theme], Theme.animDuration + 250, 500);
    }

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
    WlrLayershell.namespace: "quickshell-themes"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // `shown` may still hold its old value inside this handler: test the flag
    Connections {
        target: Panels

        function onThemesChanged(): void {
            if (Panels.themes) {
                Hyprland.refreshMonitors();
                root.query = "";
                root.moved = false;
                positionAnim.stop();
                root.jumpTo(Math.max(0, root.shownItems.findIndex(i => i.current)));
                root.position = root.selected;
                listProc.running = true;
                focusTimer.restart();
            } else {
                root.contentRevealed = false;
            }
        }
    }

    onQueryChanged: {
        moved = true;
        jumpTo(0);
    }

    // List loaded at startup and refreshed on every opening
    Component.onCompleted: listProc.running = true

    Process {
        id: listProc

        command: [root.themeSet, "--json"]
        stdout: StdioCollector {
            id: listOut
        }
        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                return;
            try {
                root.useList(JSON.parse(listOut.text));
            } catch (e) {
                console.warn("Themes: bad list from theme-set.py", e);
            }
        }
    }

    Timer {
        id: focusTimer

        interval: 50
        onTriggered: background.forceActiveFocus()
    }

    Reveal {
        id: reveal

        shown: root.shown
    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: Theme.alpha(Theme.crust, Theme.gamemode ? 1 : 0.6)
        opacity: root.contentRevealed ? reveal.value : 0
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.query !== "")
                    root.query = "";
                else
                    Panels.themes = false;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                root.move(-1);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                root.move(1);
            else if (event.key === Qt.Key_Home)
                root.move(-root.shownItems.length);
            else if (event.key === Qt.Key_End)
                root.move(root.shownItems.length);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.apply();
            else if (event.key === Qt.Key_Backspace)
                root.query = root.query.slice(0, -1);
            else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier)))
                root.query += event.text;
            else
                return;
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.themes = false
            onWheel: wheel => root.move(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
        }

        // Search
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: carousel.top
            anchors.bottomMargin: 30
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
                    text: root.query !== "" ? root.query : "Type to search themes"
                    color: root.query !== "" ? Theme.text : Theme.overlay1
                }
            }
        }

        Item {
            id: carousel

            anchors.centerIn: parent
            width: parent.width
            height: root.cardHeight
            scale: 0.95 + 0.05 * reveal.value

            Repeater {
                model: root.contentRevealed ? root.shownItems : []

                Item {
                    id: slot

                    required property var modelData
                    required property int index
                    readonly property var c: modelData.colors ?? {}
                    readonly property real d: index - root.position
                    readonly property bool isSelected: index === root.selected
                    readonly property real visibleWidth: root.lerp(root.cardWidth, root.sliceWidth, d)
                    readonly property real visibleHeight: root.lerp(root.cardHeight, root.sliceHeight, d)
                    readonly property real sliceLeft: (root.cardWidth - visibleWidth) / 2
                    readonly property real sliceTop: (root.cardHeight - visibleHeight) / 2

                    visible: Math.abs(index - root.selected) <= root.radius
                    z: 1000 - Math.round(Math.abs(d) * 10)
                    width: root.cardWidth
                    height: root.cardHeight
                    x: carousel.width / 2 + root.centerOffset(d) - width / 2

                    // Sheared clip, preview upright inside (as in WallpaperPicker)
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

                        PalettePreview {
                            width: root.cardWidth
                            height: root.cardHeight
                            colors: slot.c
                            title: slot.modelData.name
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, slice.k, 0, -(slot.sliceLeft + slice.k * slot.sliceTop + root.skew), 0, 1, 0, -slot.sliceTop, 0, 0, 1, 0, 0, 0, 0, 1)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.crust
                            opacity: Math.min(1, Math.abs(slot.d)) * 0.45
                        }
                    }

                    // Outline, also smoothing the clip's slanted edge
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: slot.isSelected ? Theme.accent : Theme.alpha(Theme.crust, 0.9)
                            strokeWidth: slot.isSelected ? Math.max(2, Theme.borderWidth) : 1.5
                            startX: slot.sliceLeft + root.skew
                            startY: slot.sliceTop
                            PathLine { x: slot.sliceLeft + slot.visibleWidth; y: slot.sliceTop }
                            PathLine { x: slot.sliceLeft + slot.visibleWidth - root.skew; y: slot.sliceTop + slot.visibleHeight }
                            PathLine { x: slot.sliceLeft; y: slot.sliceTop + slot.visibleHeight }
                            PathLine { x: slot.sliceLeft + root.skew; y: slot.sliceTop }
                        }
                    }

                    // Current theme marker
                    Rectangle {
                        visible: slot.modelData.current && slot.isSelected
                        x: slot.sliceLeft + slot.visibleWidth - 22
                        y: slot.sliceTop + 12
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.accent
                    }

                    MouseArea {
                        x: slot.sliceLeft
                        y: slot.sliceTop
                        width: slot.visibleWidth
                        height: slot.visibleHeight
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (slot.isSelected) {
                                root.apply();
                            } else {
                                root.moved = true;
                                root.selected = slot.index;
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

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (root.items.length === 0)
                        return "Loading…";
                    if (root.shownItems.length === 0)
                        return `No match for "${root.query}"`;
                    const t = root.shownItems[root.selected];
                    return t ? `${t.name}${t.mode === "light" ? "  ·  light" : ""}` : "";
                }
                font.pixelSize: Theme.fontSize + 3
                font.weight: Font.DemiBold
                style: Text.Outline
                styleColor: Theme.alpha(Theme.crust, 0.6)
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: `${root.shownItems.length ? root.selected + 1 : 0} / ${root.shownItems.length}   ·   Enter: apply   ·   type to search   ·   Esc: close`
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
