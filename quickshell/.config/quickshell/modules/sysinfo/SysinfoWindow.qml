import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// System information: fastfetch's output in a window sized to it. fastfetch
// draws the info beside the logo with cursor moves and colors it with
// escape codes, so its output is replayed on a character grid and painted
// cell by cell the way kitty does it: braille dots, block and box-drawing
// characters drawn to fill their cell, Nerd Font icons free to spill over
// theirs. Shown once the output is ready. Ctrl+C copies it as plain text.
// A regular window like Settings (floating and centered by a Hyprland rule).
FloatingWindow {
    id: root

    readonly property bool shown: Panels.sysinfo
    readonly property int pad: 22
    property var rows: []
    property bool done: false

    // The cell size comes from the "Mono" variant (letters are the same width in both);
    // text is drawn in the regular Nerd Font like kitty does, so icons come out larger
    // and bold has a face (the Mono family doesn't get bold here)
    readonly property string monoFamily: {
        const mono = Theme.nerdFamily + " Mono";
        return Qt.fontFamilies().includes(mono) ? mono : Theme.monoFont;
    }
    readonly property int fontPx: Theme.fontSize + 1
    readonly property real cellW: metrics.averageCharacterWidth
    readonly property real cellH: Math.ceil(metrics.height)
    readonly property int cols: rows.reduce((n, r) => Math.max(n, r.length), 0)

    FontMetrics {
        id: metrics

        font.family: root.monoFamily
        font.pixelSize: root.fontPx
    }

    // Drawn as shapes on the canvas: braille, quadrant and half blocks, box drawing
    function isShape(ch: string): bool {
        const code = ch.codePointAt(0);
        return (code >= 0x2800 && code <= 0x28FF) || (code >= 0x2580 && code <= 0x259F) || (code >= 0x2500 && code <= 0x257F);
    }

    function isIcon(ch: string): bool {
        const code = ch.codePointAt(0);
        return (code >= 0xE000 && code <= 0xF8FF) || code >= 0xF0000;
    }

    // Text as runs of same-styled cells; an icon is a run of its own, drawn larger
    readonly property var runs: {
        const out = [];
        rows.forEach((cells, r) => {
            let run = null;
            const end = () => {
                if (run && run.text.trim() !== "")
                    out.push(run);
                run = null;
            };
            for (let c = 0; c < cells.length; c++) {
                const cell = cells[c] ?? { ch: " ", fg: "", bold: false };
                if (isShape(cell.ch)) {
                    end();
                    continue;
                }
                const icon = isIcon(cell.ch);
                if (icon || !run || run.icon || run.fg !== cell.fg || run.bold !== cell.bold) {
                    end();
                    run = { row: r, col: c, text: "", fg: cell.fg, bold: cell.bold, icon };
                }
                run.text += cell.ch;
                if (icon)
                    end();
            }
            end();
        });
        return out;
    }

    function plainText(): string {
        return rows.map(r => Array.from(r, cell => cell ? cell.ch : " ").join("").replace(/\s+$/, "")).join("\n");
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
            // whole characters: icons above U+FFFF are two UTF-16 units but one cell
            const ch = String.fromCodePoint(text.codePointAt(i));
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
                i += ch.length;
            }
        }
        // rows of cells, without blank rows around the output
        const blank = r => !(r ?? []).some(cell => cell && cell.ch.trim() !== "");
        let first = 0, last = grid.length - 1;
        while (first <= last && blank(grid[first]))
            first++;
        while (last >= first && blank(grid[last]))
            last--;
        const out = [];
        for (let r = first; r <= last; r++)
            out.push(grid[r] ?? []);
        return out;
    }

    // hidden until fastfetch has answered, so it opens at its size
    visible: shown && done
    title: "System Information"
    color: Theme.panelBg
    implicitWidth: rows.length ? Math.ceil(cols * cellW + pad * 2) : 320
    implicitHeight: rows.length ? Math.ceil(rows.length * cellH + pad * 2) : 100
    minimumSize: Qt.size(implicitWidth, implicitHeight)

    onClosed: Panels.sysinfo = false
    // created on each opening (LazyLoader in shell.qml)
    Component.onCompleted: proc.running = true

    Process {
        id: proc

        // fastfetch takes the shell from the process that started it (the user's shell, kept
        // around by the ": " after), and the terminal from the shell's parent. Started by
        // the user's systemd instead of the shell, it finds none and names kitty from KITTY_*.
        command: ["systemd-run", "--user", "--pipe", "--quiet", "-E", "KITTY_INSTALLATION_DIR=/usr/lib/kitty", Quickshell.env("SHELL") || "bash", "-c", "fastfetch --pipe false; :"]
        stdout: StdioCollector {
            onStreamFinished: root.rows = root.parse(text)
        }
        onExited: root.done = true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        focus: root.shown
        Keys.onEscapePressed: Panels.sysinfo = false

        Keys.onPressed: event => {
            if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                Quickshell.execDetached(["wl-copy", root.plainText()]);
                event.accepted = true;
            }
        }

        Canvas {
            id: grid

            x: root.pad
            y: root.pad
            width: Math.ceil(root.cols * root.cellW)
            height: Math.ceil(root.rows.length * root.cellH)
            visible: root.rows.length > 0

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root

                function onRowsChanged(): void {
                    grid.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = root.cellW, h = root.cellH;
                const line = Math.max(2, Math.round(root.fontPx / 7)); // box lines: kitty's are 2px at this size

                // Braille: a 2x4 grid of dots (U+2800 + bits 0-7)
                const braille = (code, x, y) => {
                    const bits = code - 0x2800;
                    const order = [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [0, 3], [1, 3]];
                    const dot = Math.max(1, Math.round(Math.min(w / 2, h / 4) * 0.55));
                    for (let b = 0; b < 8; b++) {
                        if (!(bits & (1 << b)))
                            continue;
                        const [cx, cy] = order[b];
                        ctx.fillRect(Math.round(x + (cx + 0.5) * w / 2 - dot / 2), Math.round(y + (cy + 0.5) * h / 4 - dot / 2), dot, dot);
                    }
                };
                // Quadrant and half blocks (U+2580-259F): [upper-left, upper-right, lower-left, lower-right]
                const quads = {
                    0x2580: [1, 1, 0, 0], 0x2584: [0, 0, 1, 1], 0x2588: [1, 1, 1, 1], 0x258C: [1, 0, 1, 0], 0x2590: [0, 1, 0, 1],
                    0x2596: [0, 0, 1, 0], 0x2597: [0, 0, 0, 1], 0x2598: [1, 0, 0, 0], 0x2599: [1, 0, 1, 1], 0x259A: [1, 0, 0, 1],
                    0x259B: [1, 1, 1, 0], 0x259C: [1, 1, 0, 1], 0x259D: [0, 1, 0, 0], 0x259E: [0, 1, 1, 0], 0x259F: [0, 1, 1, 1]
                };
                const block = (q, x, y) => {
                    const hw = w / 2, hh = h / 2;
                    [[0, 0], [1, 0], [0, 1], [1, 1]].forEach(([i, j], k) => {
                        if (q[k])
                            ctx.fillRect(Math.floor(x + i * hw), Math.floor(y + j * hh), Math.ceil(hw), Math.ceil(hh));
                    });
                };
                // Box drawing: which sides of the cell's center a line reaches [up, right, down, left]
                const boxes = {
                    "─": [0, 1, 0, 1], "│": [1, 0, 1, 0], "┌": [0, 1, 1, 0], "┐": [0, 0, 1, 1], "└": [1, 1, 0, 0], "┘": [1, 0, 0, 1],
                    "├": [1, 1, 1, 0], "┤": [1, 0, 1, 1], "┬": [0, 1, 1, 1], "┴": [1, 1, 0, 1], "┼": [1, 1, 1, 1]
                };
                const rounded = { "╭": [1, 1], "╮": [-1, 1], "╰": [1, -1], "╯": [-1, -1] }; // direction to the arms
                const box = (ch, x, y) => {
                    const cx = Math.floor(x + w / 2 - line / 2), cy = Math.floor(y + h / 2 - line / 2);
                    const s = boxes[ch];
                    if (s) {
                        if (s[0]) ctx.fillRect(cx, Math.floor(y), line, cy - Math.floor(y) + line);
                        if (s[2]) ctx.fillRect(cx, cy, line, Math.ceil(y + h) - cy);
                        if (s[3]) ctx.fillRect(Math.floor(x), cy, cx - Math.floor(x) + line, line);
                        if (s[1]) ctx.fillRect(cx, cy, Math.ceil(x + w) - cx, line);
                        return true;
                    }
                    const r = rounded[ch];
                    if (!r)
                        return false;
                    // kitty's rounded corner: straight arms meeting in a small quarter circle
                    const [dx, dy] = r;
                    const rad = line * 1.5;
                    const lx = cx + line / 2, ly = cy + line / 2; // the line's middle
                    if (dx > 0)
                        ctx.fillRect(lx + rad, cy, Math.ceil(x + w) - (lx + rad), line);
                    else
                        ctx.fillRect(Math.floor(x), cy, lx - rad - Math.floor(x), line);
                    if (dy > 0)
                        ctx.fillRect(cx, ly + rad, line, Math.ceil(y + h) - (ly + rad));
                    else
                        ctx.fillRect(cx, Math.floor(y), line, ly - rad - Math.floor(y));
                    ctx.lineWidth = line;
                    ctx.beginPath();
                    ctx.moveTo(lx, ly + dy * rad);
                    ctx.arcTo(lx, ly, lx + dx * rad, ly, rad);
                    ctx.stroke();
                    return true;
                };

                for (let r = 0; r < root.rows.length; r++) {
                    const cells = root.rows[r];
                    const y = r * h;
                    for (let c = 0; c < cells.length; c++) {
                        const cell = cells[c];
                        if (!cell || cell.ch === " " || cell.ch === "\u2800")
                            continue;
                        const x = c * w;
                        const color = cell.fg || String(Theme.text);
                        ctx.fillStyle = color;
                        ctx.strokeStyle = color;
                        const code = cell.ch.codePointAt(0);
                        if (code > 0x2800 && code <= 0x28FF) {
                            braille(code, x, y);
                        } else if (quads[code]) {
                            block(quads[code], x, y);
                        } else {
                            box(cell.ch, x, y); // text is drawn by the items below
                        }
                    }
                }
            }
        }

        // The text, run by run on the same grid
        Item {
            x: root.pad
            y: root.pad

            Repeater {
                model: root.runs

                Text {
                    required property var modelData

                    // the baseline where kitty puts it: measured 1px below Qt's top-aligned text
                    x: modelData.col * root.cellW
                    y: modelData.row * root.cellH + 1
                    text: modelData.text
                    color: modelData.fg || Theme.text
                    font.family: Theme.nerdFamily
                    font.pixelSize: root.fontPx
                    font.bold: modelData.bold
                    textFormat: Text.PlainText
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.rows.length === 0
            text: "fastfetch is not installed"
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
