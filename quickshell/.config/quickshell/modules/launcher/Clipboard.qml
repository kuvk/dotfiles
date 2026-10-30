import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Clipboard history (ALT+SHIFT+V), from cliphist: type to filter, Enter puts
// the entry back on the clipboard, Ctrl+D deletes it, Ctrl+J/K move.
PanelWindow {
    id: root

    readonly property bool shown: Panels.clipboard
    readonly property int maxRows: 9
    readonly property int rowHeight: 40
    // cliphist list: "<id>\t<preview>", newest first
    property var entries: []
    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        return q === "" ? entries : entries.filter(e => e.preview.toLowerCase().includes(q));
    }

    function refresh(): void {
        listProc.running = true;
    }

    function activate(index: int): void {
        const entry = results[index];
        if (!entry)
            return;
        Panels.clipboard = false;
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | cliphist decode | wl-copy', "_", entry.line]);
    }

    function remove(index: int): void {
        const entry = results[index];
        if (!entry)
            return;
        // gone from the list right away; cliphist catches up behind it
        entries = entries.filter(e => e !== entry);
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | cliphist delete', "_", entry.line]);
    }

    screen: Panels.overlayScreen ?? Panels.focusedScreen
    visible: shown
    color: "transparent"
    anchors {
        top: true
    }
    margins {
        top: Math.round((screen?.height ?? 1080) * 0.22)
    }
    implicitWidth: 640
    implicitHeight: 74 + maxRows * (rowHeight + 4) + 12
    readonly property real panelHeight: 74 + (results.length > 0 ? Math.min(results.length, maxRows) * (rowHeight + 4) + 12 : 0)
    mask: Region {
        item: panel
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: {
        search.text = "";
        list.currentIndex = 0;
        if (shown) {
            refresh();
            search.forceActiveFocus();
        }
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l !== "").map(line => {
                    const tab = line.indexOf("\t");
                    return {
                        line: line,
                        preview: line.slice(tab + 1)
                    };
                });
            }
        }
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root]
        onCleared: Panels.clipboard = false
    }

    Rectangle {
        id: panel

        width: parent.width
        height: root.panelHeight
        clip: true
        color: Theme.panelBg
        radius: Theme.radius
        border.color: Theme.border
        border.width: Theme.borderWidth

        Behavior on height {
            NumberAnimation {
                duration: Theme.animDuration * 1.6
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            x: 13
            y: 13
            width: parent.width - 26
            height: root.implicitHeight - 26
            spacing: 12

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
                        text: Icons.search
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

                        Keys.onEscapePressed: {
                            if (search.text !== "")
                                search.text = "";
                            else
                                Panels.clipboard = false;
                        }
                        Keys.onReturnPressed: root.activate(list.currentIndex)
                        Keys.onEnterPressed: root.activate(list.currentIndex)
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onTabPressed: list.incrementCurrentIndex()
                        Keys.onBacktabPressed: list.decrementCurrentIndex()
                        Keys.onPressed: event => {
                            if (!(event.modifiers & Qt.ControlModifier))
                                return;
                            if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                                list.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                                list.decrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_D) {
                                root.remove(list.currentIndex);
                                event.accepted = true;
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: root.entries.length > 0 ? "Search clipboard…" : "Clipboard history is empty"
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

                ScrollBar {
                    parent: list
                    flick: list
                }

                delegate: MouseArea {
                    id: entry

                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    implicitHeight: root.rowHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = index
                    onClicked: root.activate(index)

                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        text: entry.modelData.preview
                        textFormat: Text.PlainText
                        maximumLineCount: 1
                        color: entry.ListView.isCurrentItem ? Theme.highlight : Theme.text
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
