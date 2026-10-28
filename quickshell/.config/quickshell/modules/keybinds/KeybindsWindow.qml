import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Every keybinding, like Omarchy's keybindings menu (ALT+SHIFT+/). Hyprland's
// come from ~/.config/hypr/configs/bindings.lua through hypr-keybinds.py, so
// the list follows that file; the shell's own keys inside its windows are
// listed below them. Type to filter. A regular window like Settings and
// Displays (floating and centered by a Hyprland rule, can be tiled).
FloatingWindow {
    id: root

    readonly property bool shown: Panels.keybinds
    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/hypr-keybinds.py"
    property var hyprSections: []
    property string query: ""

    // Keys handled inside the shell's own windows
    readonly property var shellSections: [
        {
            section: "Launcher",
            binds: [
                { keys: ["↑", "↓"], desc: "Move (also Tab, Ctrl+J/K, Ctrl+N/P)" },
                { keys: ["Enter"], desc: "Launch, or switch theme" },
                { keys: ["Esc"], desc: "Close" }
            ]
        },
        {
            section: "Control Center",
            binds: [
                { keys: ["Shift", "C"], desc: "Clear notifications" },
                { keys: ["Shift", "D"], desc: "Do not disturb on / off" },
                { keys: ["Esc"], desc: "Close" }
            ]
        },
        {
            section: "Wallpaper picker",
            binds: [
                { keys: ["←", "→"], desc: "Previous / next (also scroll)" },
                { keys: ["Enter"], desc: "Set on all monitors" },
                { keys: ["Shift", "Enter"], desc: "Set on this monitor" },
                { keys: ["Tab"], desc: "Wallpapers / live wallpapers" },
                { keys: ["Del"], desc: "Stop live wallpapers" },
                { keys: ["Type"], desc: "Search; Esc clears, then closes" }
            ]
        },
        {
            section: "Power menu",
            binds: [
                { keys: ["L"], desc: "Lock" },
                { keys: ["U"], desc: "Sleep" },
                { keys: ["E"], desc: "Log out" },
                { keys: ["R"], desc: "Reboot" },
                { keys: ["S"], desc: "Shut down" },
                { keys: ["←", "→"], desc: "Choose, Enter runs it" }
            ]
        }
    ]

    readonly property var sections: {
        const q = query.toLowerCase();
        const all = hyprSections.concat(shellSections);
        if (!q)
            return all;
        return all.map(s => ({
                    section: s.section,
                    binds: s.section.toLowerCase().includes(q) ? s.binds : s.binds.filter(b => b.desc.toLowerCase().includes(q) || b.keys.join(" ").toLowerCase().includes(q))
                })).filter(s => s.binds.length > 0);
    }

    visible: shown
    title: "Keybindings"
    color: Theme.panelBg
    implicitWidth: 900
    implicitHeight: 640

    onClosed: Panels.keybinds = false
    onShownChanged: {
        query = "";
        if (shown)
            listProc.running = true;
    }

    Process {
        id: listProc

        command: [root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hyprSections = JSON.parse(text);
                } catch (e) {
                    console.warn("Keybindings: bad list from hypr-keybinds.py", e);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.query !== "")
                    root.query = "";
                else
                    Panels.keybinds = false;
            } else if (event.key === Qt.Key_Backspace) {
                root.query = root.query.slice(0, -1);
            } else if (event.key === Qt.Key_Down) {
                bindsFlick.contentY = Math.min(Math.max(0, bindsFlick.contentHeight - bindsFlick.height), bindsFlick.contentY + 60);
            } else if (event.key === Qt.Key_Up) {
                bindsFlick.contentY = Math.max(0, bindsFlick.contentY - 60);
            } else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                root.query += event.text;
            } else {
                return;
            }
            event.accepted = true;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            SectionHeader {
                title: "Keybindings"

                CloseButton {
                    onClicked: Panels.keybinds = false
                }
            }

            // Search
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.smallRadius
                color: Theme.cardBg
                border.color: root.query !== "" ? Theme.highlight : "transparent"
                border.width: Theme.borderWidth

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.search
                        color: root.query !== "" ? Theme.highlight : Theme.overlay1
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query !== "" ? root.query : "Type to filter"
                        color: root.query !== "" ? Theme.text : Theme.overlay1
                    }
                }
            }

            Flickable {
                id: bindsFlick

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: columns.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar {
                    parent: bindsFlick
                    flick: bindsFlick
                }

                // Sections flow into two columns, each section kept whole
                Row {
                    id: columns

                    readonly property real columnWidth: (width - spacing) / 2

                    // room for the scroll bar
                    width: bindsFlick.width - 14
                    spacing: 16

                    Repeater {
                        model: 2

                        Column {
                            id: column

                            required property int index

                            width: columns.columnWidth
                            spacing: 14

                            Repeater {
                                // alternate sections between the columns
                                model: root.sections.filter((s, i) => i % 2 === column.index)

                                Column {
                                    id: section

                                    required property var modelData

                                    width: column.width
                                    spacing: 6

                                    StyledText {
                                        text: section.modelData.section
                                        color: Theme.highlight
                                        font.weight: Font.Bold
                                    }

                                    Repeater {
                                        model: section.modelData.binds

                                        Item {
                                            id: bind

                                            required property var modelData

                                            width: section.width
                                            height: Math.max(caps.height, label.implicitHeight)

                                            Row {
                                                id: caps

                                                spacing: 4

                                                Repeater {
                                                    model: bind.modelData.keys

                                                    Rectangle {
                                                        required property string modelData

                                                        width: Math.max(24, keyText.implicitWidth + 12)
                                                        height: 22
                                                        radius: Theme.smallRadius
                                                        color: Theme.cardBg
                                                        border.color: Theme.alpha(Theme.overlay0, 0.6)
                                                        border.width: 1

                                                        StyledText {
                                                            id: keyText

                                                            anchors.centerIn: parent
                                                            text: parent.modelData
                                                            color: Theme.text
                                                            font.pixelSize: Theme.fontSize - 1
                                                            font.weight: Font.DemiBold
                                                        }
                                                    }
                                                }
                                            }

                                            StyledText {
                                                id: label

                                                x: Math.max(caps.width + 10, 170)
                                                width: parent.width - x
                                                anchors.verticalCenter: caps.verticalCenter
                                                text: bind.modelData.desc
                                                color: Theme.subtext1
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
