import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
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
// ←/→ h/l or scroll: move   Enter: all monitors   Shift+Enter: this monitor
// Tab: static/live   Delete: stop live wallpapers   Esc: close
PanelWindow {
    id: root

    readonly property string kind: Panels.wallpapers
    readonly property bool shown: kind !== ""
    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/wallpaper.py"

    property var items: []
    property int selected: 0
    property bool loading: false

    // Card geometry, scaled to the screen
    readonly property real cardHeight: Math.min(475, height * 0.45)
    readonly property real cardWidth: cardHeight * 768 / 475
    readonly property real sliceWidth: cardHeight * 0.23
    readonly property real sliceHeight: cardHeight * 0.91
    readonly property real skew: cardHeight * 0.06
    readonly property real overlap: -cardHeight * 0.06
    readonly property int radius: Math.ceil((width - cardWidth) / (2 * (sliceWidth + overlap))) + 1

    // Thumbnails generated during this opening, per kind
    property var thumbsTried: ({})

    function load(): void {
        loading = true;
        // A list for the previous tab may still be running; restart it
        listProc.running = false;
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
        if (items.length > 0)
            selected = Math.max(0, Math.min(items.length - 1, selected + delta));
    }

    function apply(thisMonitorOnly: bool): void {
        const item = items[selected];
        if (!item)
            return;
        const cmd = [script, "set", kind, item.path];
        if (thisMonitorOnly && screen)
            cmd.push(screen.name);
        Quickshell.execDetached(cmd);
        Panels.wallpapers = "";
    }

    // Horizontal center of the card at `offset` from the selected one
    function centerFor(offset: int): real {
        if (offset === 0)
            return width / 2;
        const side = Math.sign(offset);
        return width / 2 + side * (cardWidth / 2 + overlap + sliceWidth / 2 + (Math.abs(offset) - 1) * (sliceWidth + overlap));
    }

    screen: Panels.focusedScreen
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
            items = [];
            selected = 0;
            load();
            focusTimer.restart();
        } else {
            thumbsTried = {};
        }
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

    Process {
        id: listProc

        property string kind: ""

        stdout: StdioCollector {
            onStreamFinished: {
                // Ignore a list for a tab that is no longer shown
                if (listProc.kind !== root.kind)
                    return;
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    console.warn("Wallpapers: bad list", e);
                }
                const first = root.items.length === 0;
                root.items = list;
                if (first)
                    root.selected = Math.max(0, list.findIndex(i => i.current));
                root.loading = false;
                // Fill in missing thumbnails, then reload once
                if (list.some(i => !i.thumb))
                    root.makeThumbs();
            }
        }
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
        opacity: reveal.value
        focus: root.shown

        Keys.onPressed: event => {
            const shift = event.modifiers & Qt.ShiftModifier;
            if (event.key === Qt.Key_Escape)
                Panels.wallpapers = "";
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
                root.move(-1);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
                root.move(1);
            else if (event.key === Qt.Key_Home)
                root.selected = 0;
            else if (event.key === Qt.Key_End)
                root.selected = Math.max(0, root.items.length - 1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.apply(shift);
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                Panels.wallpapers = root.kind === "static" ? "live" : "static";
            else if (event.key === Qt.Key_Delete && root.kind === "live") {
                Quickshell.execDetached([root.script, "stop"]);
                Panels.wallpapers = "";
            } else
                return;
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.wallpapers = ""
            onWheel: wheel => root.move(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1)
        }

        // Tabs
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: carousel.top
            anchors.bottomMargin: 36
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

        Item {
            id: carousel

            anchors.centerIn: parent
            width: parent.width
            height: root.cardHeight
            opacity: reveal.value
            scale: 0.95 + 0.05 * reveal.value

            Repeater {
                model: root.items

                Loader {
                    id: slot

                    required property var modelData
                    required property int index
                    readonly property int offset: index - root.selected
                    readonly property bool isSelected: offset === 0

                    active: Math.abs(offset) <= root.radius
                    visible: active
                    z: 100 - Math.abs(offset)
                    width: isSelected ? root.cardWidth : root.sliceWidth
                    height: isSelected ? root.cardHeight : root.sliceHeight
                    x: root.centerFor(offset) - width / 2
                    y: (carousel.height - height) / 2

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.animDuration * 1.5
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animDuration * 1.5
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.animDuration * 1.5
                            easing.type: Easing.OutCubic
                        }
                    }

                    sourceComponent: Item {
                        id: card

                        // Image, dimmed when not selected, cut to a parallelogram
                        Item {
                            id: picture

                            anchors.fill: parent
                            visible: false
                            layer.enabled: true

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

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.crust
                                opacity: slot.isSelected ? 0 : 0.45

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.animDuration
                                    }
                                }
                            }
                        }

                        Shape {
                            id: mask

                            anchors.fill: parent
                            visible: false
                            layer.enabled: true

                            ShapePath {
                                fillColor: "white"
                                strokeColor: "transparent"
                                startX: root.skew
                                startY: 0
                                PathLine { x: card.width; y: 0 }
                                PathLine { x: card.width - root.skew; y: card.height }
                                PathLine { x: 0; y: card.height }
                                PathLine { x: root.skew; y: 0 }
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: picture
                            maskEnabled: true
                            maskSource: mask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }

                        // Outline
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: slot.isSelected ? Theme.accent : Theme.alpha(Theme.text, 0.15)
                                strokeWidth: slot.isSelected ? Math.max(2, Theme.borderWidth) : 1
                                startX: root.skew
                                startY: 0
                                PathLine { x: card.width; y: 0 }
                                PathLine { x: card.width - root.skew; y: card.height }
                                PathLine { x: 0; y: card.height }
                                PathLine { x: root.skew; y: 0 }
                            }
                        }

                        // Current wallpaper marker
                        Rectangle {
                            visible: slot.modelData.current && slot.isSelected
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 12
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.accent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: slot.isSelected ? root.apply(false) : (root.selected = slot.index)
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
                text: root.items.length === 0 ? (root.loading ? "Loading…" : `Nothing in ~/Pictures/${root.kind === "live" ? "WallpapersLive" : "Wallpapers"}`) : (root.items[root.selected]?.name ?? "")
                font.pixelSize: Theme.fontSize + 3
                font.weight: Font.DemiBold
                style: Text.Outline
                styleColor: Theme.alpha(Theme.crust, 0.6)
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: `${root.items.length ? root.selected + 1 : 0} / ${root.items.length}   ·   Enter: all monitors   ·   Shift+Enter: this monitor   ·   Tab: ${root.kind === "static" ? "live" : "static"}${root.kind === "live" ? "   ·   Del: stop live" : ""}`
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }
}
