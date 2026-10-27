import QtQuick
import qs.config

// Digital rain, drawn cell by cell so each frame only touches a few hundred
// glyphs (no full-screen redraw). Replaces `unimatrix` in a fullscreen kitty.
Canvas {
    id: root

    property bool running: true
    property int cellSize: 18
    property int fps: 24
    property color color: Theme.green
    property color headColor: Qt.lighter(Theme.green, 1.6)
    property color dimColor: Theme.alpha(Theme.green, 0.45)
    readonly property string glyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789ZXCVBNM<>*+-=:.\"|"

    property var drops: []
    property int cols: 0
    property int rows: 0
    property bool reset: true

    function glyph(): string {
        return glyphs[Math.floor(Math.random() * glyphs.length)];
    }

    function newDrop(initial: bool): var {
        return {
            head: initial ? -Math.floor(Math.random() * rows * 1.5) : -Math.floor(Math.random() * rows * 0.5),
            painted: -1,
            speed: 0.3 + Math.random() * 0.7,
            pos: 0,
            length: 8 + Math.floor(Math.random() * Math.max(8, rows * 0.6))
        };
    }

    function init(): void {
        cols = Math.ceil(width / cellSize);
        rows = Math.ceil(height / cellSize);
        const d = [];
        for (let i = 0; i < cols; i++)
            d.push(newDrop(true));
        drops = d;
        reset = true;
        requestPaint();
    }

    onWidthChanged: init()
    onHeightChanged: init()
    Component.onCompleted: init()

    onPaint: {
        const ctx = getContext("2d");
        const s = cellSize;
        if (reset) {
            ctx.clearRect(0, 0, width, height);
            reset = false;
        }
        ctx.font = `${s - 3}px "JetBrainsMono Nerd Font", monospace`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";

        const cell = (col, row, c) => {
            if (row < 0 || row >= rows)
                return;
            ctx.clearRect(col * s, row * s, s, s);
            if (c) {
                ctx.fillStyle = c;
                ctx.fillText(glyph(), col * s + s / 2, row * s + s / 2);
            }
        };

        for (let i = 0; i < drops.length; i++) {
            const d = drops[i];
            d.pos += d.speed;
            while (d.pos >= 1) {
                d.pos -= 1;
                d.head += 1;
                // previous head turns green, new head is bright, tail end fades then clears
                cell(i, d.head - 1, root.color);
                cell(i, d.head, root.headColor);
                cell(i, d.head - Math.floor(d.length * 0.7), root.dimColor);
                cell(i, d.head - d.length, null);
            }
            // flicker a random glyph inside the trail
            if (Math.random() < 0.08)
                cell(i, d.head - 1 - Math.floor(Math.random() * d.length * 0.6), root.color);
            if (d.head - d.length > rows)
                drops[i] = newDrop(false);
        }
    }

    Timer {
        interval: 1000 / root.fps
        running: root.running && root.visible
        repeat: true
        onTriggered: root.requestPaint()
    }
}
