import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// System information: fastfetch's output in a window sized to it. fastfetch
// draws the info beside the logo with cursor moves and colors it with
// escape codes, so its output is replayed on a character grid and each row
// drawn as styled text in the Nerd Font's monospaced variant. A regular
// window like Settings (floating and centered by a Hyprland rule).
FloatingWindow {
    id: root

    readonly property bool shown: Panels.sysinfo
    readonly property int pad: 22
    property var rows: []

    // the "Mono" variant keeps icons one cell wide, so columns line up
    readonly property string monoFamily: {
        const mono = Theme.nerdFamily + " Mono";
        return Qt.fontFamilies().includes(mono) ? mono : Theme.monoFont;
    }

    // ANSI colors 0-15 from the theme
    readonly property var ansi: [Theme.surface1, Theme.red, Theme.green, Theme.yellow, Theme.blue, Theme.pink, Theme.teal, Theme.subtext1, Theme.surface2, Theme.red, Theme.green, Theme.yellow, Theme.blue, Theme.pink, Theme.teal, Theme.text]

    function color256(n: int): string {
        if (n < 16)
            return String(ansi[n]);
        if (n >= 232) {
            const v = 8 + (n - 232) * 10;
            return Qt.rgba(v / 255, v / 255, v / 255, 1).toString();
        }
        const i = n - 16, steps = [0, 95, 135, 175, 215, 255];
        return Qt.rgba(steps[Math.floor(i / 36)] / 255, steps[Math.floor(i / 6) % 6] / 255, steps[i % 6] / 255, 1).toString();
    }

    // Replays the output: cursor moves (A B C D G H), colors (SGR), text
    function parse(text: string): var {
        const grid = [];
        let row = 0, col = 0, fg = "", bold = false;
        const put = ch => {
            (grid[row] = grid[row] ?? [])[col] = { ch, fg, bold };
            col++;
        };
        const sgr = codes => {
            for (let i = 0; i < codes.length; i++) {
                const c = codes[i];
                if (c === 0) {
                    fg = "";
                    bold = false;
                } else if (c === 1)
                    bold = true;
                else if (c === 22)
                    bold = false;
                else if (c === 39)
                    fg = "";
                else if (c >= 30 && c <= 37)
                    fg = String(ansi[c - 30]);
                else if (c >= 90 && c <= 97)
                    fg = String(ansi[c - 90 + 8]);
                else if (c === 38 && codes[i + 1] === 2) {
                    fg = Qt.rgba(codes[i + 2] / 255, codes[i + 3] / 255, codes[i + 4] / 255, 1).toString();
                    i += 4;
                } else if (c === 38 && codes[i + 1] === 5) {
                    fg = color256(codes[i + 2]);
                    i += 2;
                } else if (c === 48)
                    i += codes[i + 1] === 2 ? 4 : 2; // backgrounds: skipped
            }
        };
        const csi = /^\x1b\[([0-9;?]*)([A-Za-z])/;
        const osc = /^\x1b\][^\x07\x1b]*(\x07|\x1b\\)/;
        let i = 0;
        while (i < text.length) {
            const rest = text.slice(i, i + 64);
            let m = csi.exec(rest);
            if (m) {
                const args = m[1].replace("?", "").split(";").map(a => a === "" ? NaN : Number(a));
                const n = isNaN(args[0]) ? 1 : args[0];
                switch (m[2]) {
                case "A": row = Math.max(0, row - n); break;
                case "B": row += n; break;
                case "C": col += n; break;
                case "D": col = Math.max(0, col - n); break;
                case "G": col = Math.max(0, n - 1); break;
                case "H": case "f":
                    row = (isNaN(args[0]) ? 1 : args[0]) - 1;
                    col = (isNaN(args[1]) ? 1 : args[1]) - 1;
                    break;
                case "m": sgr(m[1] === "" ? [0] : args.map(a => isNaN(a) ? 0 : a)); break;
                }
                i += m[0].length;
                continue;
            }
            m = osc.exec(rest);
            if (m) {
                i += m[0].length;
                continue;
            }
            const ch = text[i];
            if (ch === "\x1b")
                i += 2; // other two-character escapes
            else {
                if (ch === "\n") {
                    row++;
                    col = 0;
                } else if (ch === "\r")
                    col = 0;
                else if (ch >= " ")
                    put(ch);
                i++;
            }
        }
        // rows as styled text, without blank rows around the output
        // plain spaces: the rows go into a <pre>, so copied text stays normal
        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const lines = [];
        for (let r = 0; r < grid.length; r++) {
            const cells = grid[r] ?? [];
            let html = "", run = "", style = null;
            const flush = () => {
                if (run === "")
                    return;
                let s = esc(run);
                if (style?.fg)
                    s = `<font color="${style.fg}">${s}</font>`;
                if (style?.bold)
                    s = `<b>${s}</b>`;
                html += s;
                run = "";
            };
            for (let c = 0; c < cells.length; c++) {
                const cell = cells[c] ?? { ch: " ", fg: "", bold: false };
                if (!style || cell.fg !== style.fg || cell.bold !== style.bold) {
                    flush();
                    style = cell;
                }
                run += cell.ch;
            }
            flush();
            lines.push(html);
        }
        const blank = l => l.replace(/<[^>]*>/g, "").trim() === "";
        while (lines.length && blank(lines[0]))
            lines.shift();
        while (lines.length && blank(lines[lines.length - 1]))
            lines.pop();
        return lines;
    }

    visible: shown
    title: "System Information"
    color: Theme.panelBg
    implicitWidth: Math.ceil(output.implicitWidth + pad * 2)
    implicitHeight: Math.ceil(Math.max(60, output.implicitHeight) + pad * 2)
    minimumSize: Qt.size(implicitWidth, implicitHeight)

    onClosed: Panels.sysinfo = false
    // created on each opening (LazyLoader in shell.qml)
    Component.onCompleted: proc.running = true

    Process {
        id: proc

        // fastfetch names its terminal from KITTY_* (it isn't run from one
        // here); the shell line comes from bash
        command: ["bash", "-c", "fastfetch --pipe false"]
        environment: ({ KITTY_INSTALLATION_DIR: "/usr/lib/kitty" })
        stdout: StdioCollector {
            onStreamFinished: root.rows = root.parse(text)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        focus: root.shown
        Keys.onEscapePressed: Panels.sysinfo = false

        // Text, not an image: select with the mouse, copy with Ctrl+C
        TextEdit {
            id: output

            x: root.pad
            y: root.pad
            readOnly: true
            selectByMouse: true
            persistentSelection: true
            Keys.onEscapePressed: Panels.sysinfo = false
            textFormat: TextEdit.RichText
            color: Theme.text
            selectionColor: Theme.alpha(Theme.accent, 0.35)
            selectedTextColor: Theme.text
            font.family: root.monoFamily
            font.pixelSize: Theme.fontSize + 1
            text: root.rows.length ? `<pre style="margin:0; font-family:'${root.monoFamily}'">${root.rows.join("\n")}</pre>` : ""
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.rows.length === 0
            text: proc.running ? "Loading…" : "fastfetch is not installed"
            color: Theme.overlay1
        }

        CloseButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            onClicked: Panels.sysinfo = false
        }
    }
}
