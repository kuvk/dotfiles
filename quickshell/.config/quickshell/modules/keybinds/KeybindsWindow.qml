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
            section: "Search launcher",
            binds: [
                { keys: ["Type"], desc: "Apps appear as you type" },
                { keys: ["↑", "↓"], desc: "Move (also Tab, Ctrl+J/K, Ctrl+N/P)" },
                { keys: ["Enter"], desc: "Launch" },
                { keys: ["Esc"], desc: "Clear, then close" }
            ]
        },
        {
            section: "App menu",
            binds: [
                { keys: ["←", "→"], desc: "Categories (also Tab)" },
                { keys: ["↑", "↓"], desc: "Apps" },
                { keys: ["Type"], desc: "Filter the category" },
                { keys: ["Enter"], desc: "Launch" },
                { keys: ["Esc"], desc: "Clear, then close" }
            ]
        },
        {
            section: "Theme carousel",
            binds: [
                { keys: ["←", "→"], desc: "Previous / next (also scroll)" },
                { keys: ["Enter"], desc: "Apply" },
                { keys: ["Type"], desc: "Search; Esc clears, then closes" }
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
        },
        {
            section: "Clipboard history",
            binds: [
                { keys: ["Type"], desc: "Filter" },
                { keys: ["Ctrl", "J"], desc: "Next (also ↓, Tab)" },
                { keys: ["Ctrl", "K"], desc: "Previous (also ↑)" },
                { keys: ["Ctrl", "D"], desc: "Delete the entry" },
                { keys: ["Enter"], desc: "Copy it again" },
                { keys: ["Esc"], desc: "Clear, then close" }
            ]
        }
    ]

    // Keys of the terminal tools. Each chip is one press, in order, so
    // ["Ctrl+S", "V"] means Ctrl+S, then V.
    readonly property var terminalSections: [
        {
            section: "Panes (tmux, nvim, herdr)",
            binds: [
                { keys: ["Ctrl+H"], desc: "Left pane or split" },
                { keys: ["Ctrl+J"], desc: "Pane or split below" },
                { keys: ["Ctrl+K"], desc: "Pane or split above" },
                { keys: ["Ctrl+L"], desc: "Right pane or split" }
            ]
        },
        {
            section: "Copy and paste",
            binds: [
                { keys: ["y"], desc: "Copy (zsh normal, nvim, copy modes)" },
                { keys: ["p"], desc: "Paste after (zsh normal, nvim)" },
                { keys: ["P"], desc: "Paste before (zsh normal, nvim)" },
                { keys: ["Ctrl+S", "P"], desc: "Paste in tmux" },
                { keys: ["Ctrl+Shift+V"], desc: "Paste anywhere in kitty" },
                { keys: ["Ctrl+Shift+C"], desc: "Copy the kitty selection" }
            ]
        },
        {
            section: "tmux",
            binds: [
                { keys: ["Ctrl+S", "|"], desc: "Split right" },
                { keys: ["Ctrl+S", "-"], desc: "Split down" },
                { keys: ["Ctrl+S", "H"], desc: "Resize left (J, K, L too)" },
                { keys: ["Ctrl+S", "h"], desc: "Move to pane (j, k, l)" },
                { keys: ["Ctrl+S", "z"], desc: "Zoom pane" },
                { keys: ["Ctrl+S", "x"], desc: "Close pane" },
                { keys: ["Ctrl+S", "c"], desc: "New window" },
                { keys: ["Ctrl+S", "n"], desc: "Next window (p previous)" },
                { keys: ["Ctrl+S", "1…9"], desc: "Go to window" },
                { keys: ["Ctrl+S", "d"], desc: "Detach" },
                { keys: ["Ctrl+S", "r"], desc: "Reload config" },
                { keys: ["Ctrl+S", "Ctrl+S"], desc: "Send Ctrl+S to the app" }
            ]
        },
        {
            section: "tmux copy mode",
            binds: [
                { keys: ["Ctrl+S", "v"], desc: "Enter copy mode" },
                { keys: ["h j k l"], desc: "Move (also w, b, Ctrl+U/D, g, G)" },
                { keys: ["/"], desc: "Search down (? up, n, N)" },
                { keys: ["v"], desc: "Start selection" },
                { keys: ["Ctrl+V"], desc: "Rectangle selection" },
                { keys: ["y"], desc: "Copy and leave" },
                { keys: ["q"], desc: "Leave" }
            ]
        },
        {
            section: "herdr panes",
            binds: [
                { keys: ["Ctrl+S", "v"], desc: "Split right" },
                { keys: ["Ctrl+S", "-"], desc: "Split down" },
                { keys: ["Ctrl+S", "h"], desc: "Move to pane (j, k, l)" },
                { keys: ["Ctrl+S", "z"], desc: "Zoom pane" },
                { keys: ["Ctrl+S", "x"], desc: "Close pane" },
                { keys: ["Ctrl+S", "r"], desc: "Resize mode" },
                { keys: ["Ctrl+S", "["], desc: "Copy mode (v, y, q, /)" },
                { keys: ["Ctrl+S", "e"], desc: "Scrollback in the editor" }
            ]
        },
        {
            section: "herdr tabs and workspaces",
            binds: [
                { keys: ["Ctrl+S", "g"], desc: "Find an agent (b, w, i, d filter)" },
                { keys: ["Ctrl+S", "w"], desc: "Workspaces" },
                { keys: ["Ctrl+S", "Shift+N"], desc: "New workspace" },
                { keys: ["Ctrl+S", "c"], desc: "New tab" },
                { keys: ["Ctrl+S", "n"], desc: "Next tab (p previous)" },
                { keys: ["Ctrl+S", "1…9"], desc: "Go to tab" },
                { keys: ["Ctrl+S", "b"], desc: "Show / hide the sidebar" },
                { keys: ["Ctrl+S", "s"], desc: "Settings" },
                { keys: ["Ctrl+S", "?"], desc: "All keys" },
                { keys: ["Ctrl+S", "q"], desc: "Detach; agents keep running" }
            ]
        },
        {
            section: "Claude Code",
            binds: [
                { keys: ["PgUp"], desc: "Scroll up (PgDn down)" },
                { keys: ["Ctrl+Home"], desc: "Top (Ctrl+End latest)" },
                { keys: ["Ctrl+O"], desc: "Open the transcript" },
                { keys: ["Shift+Enter"], desc: "New line" },
                { keys: ["Ctrl+G"], desc: "Write the prompt in nvim" },
                { keys: ["Ctrl+V"], desc: "Paste an image" },
                { keys: ["Shift+Tab"], desc: "Change permission mode" },
                { keys: ["jk"], desc: "Leave insert mode" }
            ]
        },
        {
            section: "Claude Code transcript",
            binds: [
                { keys: ["j"], desc: "Line down (k up)" },
                { keys: ["Ctrl+D"], desc: "Half page down (Ctrl+U up)" },
                { keys: ["g"], desc: "Top (G bottom)" },
                { keys: ["{"], desc: "Previous prompt (} next)" },
                { keys: ["/"], desc: "Search (n, N)" },
                { keys: ["v"], desc: "Open in nvim" },
                { keys: ["["], desc: "Send to terminal scrollback" },
                { keys: ["q"], desc: "Back to the prompt" }
            ]
        },
        {
            section: "zsh",
            binds: [
                { keys: ["jk"], desc: "Normal mode (also Esc)" },
                { keys: ["k"], desc: "Normal mode: older match (j newer)" },
                { keys: ["↑"], desc: "Older match in history (↓ newer)" },
                { keys: ["Ctrl+R"], desc: "Search history (fzf)" },
                { keys: ["Ctrl+T"], desc: "Pick a file (fzf)" },
                { keys: ["v"], desc: "Normal mode: select text" }
            ]
        },
        {
            section: "nvim",
            binds: [
                { keys: ["Space", "s", "v"], desc: "Split right (s h down)" },
                { keys: ["Space", "s", "x"], desc: "Close split" },
                { keys: ["Ctrl+←"], desc: "Resize split (other arrows too)" },
                { keys: ["Space", "d"], desc: "Delete without copying" },
                { keys: ["jk"], desc: "Leave insert mode" }
            ]
        },
        {
            section: "kitty",
            binds: [
                { keys: ["Ctrl+Shift+H"], desc: "Scrollback in nvim (y, q)" },
                { keys: ["Ctrl+F5"], desc: "Reload config" }
            ]
        }
    ]

    readonly property var sections: {
        const q = query.toLowerCase();
        const all = hyprSections.concat(shellSections, terminalSections);
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
    // can grow, not shrink below the default size
    minimumSize: Qt.size(implicitWidth, implicitHeight)

    onClosed: Panels.keybinds = false
    // created on each opening (LazyLoader in shell.qml)
    Component.onCompleted: listProc.running = true

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
