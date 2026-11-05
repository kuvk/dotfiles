import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Centered launcher. Two modes: applications, and themes (runs theme-set.py).
PanelWindow {
    id: root

    readonly property bool shown: Panels.launcher
    readonly property bool themes: Panels.launcherMode === "themes"
    readonly property string themeSet: Quickshell.env("HOME") + "/.config/scripts/theme-set.py"
    property var themeList: []

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        if (themes)
            return themeList.filter(t => t.name.toLowerCase().includes(q) || t.theme.includes(q));
        if (!q)
            return apps;
        const scored = [];
        for (const app of apps) {
            const name = app.name.toLowerCase();
            let score = 0;
            if (name.startsWith(q))
                score = 4;
            else if (name.split(/[\s-]/).some(w => w.startsWith(q)))
                score = 3;
            else if (name.includes(q))
                score = 2;
            else if ([app.genericName, app.comment, app.id, ...(app.keywords ?? [])].some(s => s && s.toLowerCase().includes(q)))
                score = 1;
            if (score > 0)
                scored.push({ app, score });
        }
        return scored.sort((a, b) => b.score - a.score).map(s => s.app);
    }

    function launch(app: DesktopEntry): void {
        Panels.launcher = false;
        if (app.runInTerminal) {
            // DesktopEntry.execute() ignores Terminal=true
            const cmd = (app.command ?? []).filter(arg => !/^%[fFuUdDnNickvm]$/.test(arg));
            Quickshell.execDetached(["kitty", "-e", ...cmd]);
        } else {
            app.execute();
        }
    }

    function activate(index: int): void {
        const item = results[index];
        if (!item)
            return;
        if (themes) {
            Panels.launcher = false;
            Transition.run([themeSet, item.theme], 250, 500); // after the launcher has faded out
        } else {
            launch(item);
        }
    }

    screen: Panels.overlayScreen ?? Panels.focusedScreen
    visible: shown
    color: "transparent"
    implicitWidth: 560
    implicitHeight: 480
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        search.text = "";
        list.currentIndex = 0;
        if (shown) {
            search.forceActiveFocus();
            if (themes)
                themeProc.running = true;
        }
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root]
        onCleared: Panels.launcher = false
    }

    Process {
        id: themeProc

        command: [root.themeSet, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themeList = JSON.parse(text);
                    list.currentIndex = Math.max(0, root.themeList.findIndex(t => t.current));
                } catch (e) {
                    console.warn("Launcher: bad theme list", e);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        radius: Theme.radius
        border.color: Theme.border
        border.width: Theme.borderWidth

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.smallRadius
                color: Theme.alpha(Theme.surface0, 0.8)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    spacing: 12

                    Icon {
                        text: root.themes ? Icons.palette : Icons.search
                        color: Theme.accent2
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: search

                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 16
                        clip: true
                        onTextChanged: list.currentIndex = 0

                        Keys.onEscapePressed: Panels.launcher = false
                        Keys.onReturnPressed: root.activate(list.currentIndex)
                        Keys.onEnterPressed: root.activate(list.currentIndex)
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onTabPressed: list.incrementCurrentIndex()
                        Keys.onPressed: event => {
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                                    list.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                                    list.decrementCurrentIndex();
                                    event.accepted = true;
                                }
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            visible: search.text === ""
                            text: root.themes ? "Switch theme…" : "Search apps…"
                            color: Theme.surface2
                            font.pixelSize: 16
                        }
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.results
                highlightMoveDuration: Theme.animDuration
                boundsBehavior: Flickable.StopAtBounds

                highlight: Rectangle {
                    radius: Theme.smallRadius
                    color: Theme.alpha(Theme.surface0, 0.8)
                }

                delegate: MouseArea {
                    id: entry

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    implicitHeight: 52
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = index
                    onClicked: root.activate(index)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        IconImage {
                            visible: !root.themes
                            implicitSize: 32
                            source: root.themes ? "" : Quickshell.iconPath(entry.modelData.icon ?? "", "application-x-executable")
                        }

                        // Theme swatches
                        Row {
                            visible: root.themes
                            spacing: 0

                            Repeater {
                                model: root.themes ? entry.modelData.swatches : []

                                Rectangle {
                                    required property string modelData
                                    required property int index

                                    width: index === 0 ? 32 : 10
                                    height: 32
                                    color: modelData
                                    radius: index === 0 ? 4 : 0
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: entry.modelData.name
                                color: entry.ListView.isCurrentItem ? Theme.highlight : Theme.text
                                font.pixelSize: 14
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: root.themes ? (entry.modelData.current ? "Current · " : "") + entry.modelData.mode : (entry.modelData.genericName || entry.modelData.comment || "")
                                color: Theme.overlay1
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
