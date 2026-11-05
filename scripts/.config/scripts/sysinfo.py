#!/usr/bin/env python3
"""System information: fastfetch in a floating kitty window sized to its
output, padded, with no cursor; any key closes it. (Quickshell's ⓘ buttons.)

fastfetch draws the info next to the logo with cursor movements, so the size
is measured by replaying those on a virtual screen, not by counting lines.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import unicodedata

PADDING = 18  # px around the output
CSI = re.compile(r"\x1b\[([0-9;?]*)([A-Za-z])")
OSC = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")


def char_width(ch: str) -> int:
    if unicodedata.combining(ch):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def measure(text: str) -> tuple[int, int]:
    """Columns and rows the output covers on a terminal."""
    text = OSC.sub("", text)
    row = col = 0
    max_col = max_row = 0
    i = 0
    while i < len(text):
        m = CSI.match(text, i)
        if m:
            args, cmd = m.group(1), m.group(2)
            n = int(args.split(";")[0]) if args and args.split(";")[0].isdigit() else 1
            if cmd == "A":
                row = max(0, row - n)
            elif cmd == "B":
                row += n
            elif cmd == "C":
                col += n
            elif cmd == "D":
                col = max(0, col - n)
            elif cmd == "G":
                col = max(0, n - 1)
            elif cmd in ("H", "f"):
                parts = [int(p) if p.isdigit() else 1 for p in args.split(";")] + [1, 1]
                row, col = parts[0] - 1, parts[1] - 1
            i = m.end()
            continue
        ch = text[i]
        if ch == "\n":
            row += 1
            col = 0
        elif ch == "\r":
            col = 0
        elif ch == "\t":
            col = (col // 8 + 1) * 8
        elif ch >= " ":
            col += char_width(ch)
            max_col = max(max_col, col)
            max_row = max(max_row, row + 1)
        i += 1
    return max_col, max_row


def main() -> int:
    if not shutil.which("fastfetch") or not shutil.which("kitty"):
        print("sysinfo: needs fastfetch and kitty", file=sys.stderr)
        return 1
    # measured from a run here; the window runs its own, so the terminal and
    # shell lines name kitty and bash (a little slack covers the difference)
    out = subprocess.run(["bash", "-c", "fastfetch --pipe false"], capture_output=True, text=True).stdout
    cols, rows = measure(out)

    # $(...) drops the trailing newline, which would scroll the first line
    # away in a window exactly as tall as the output; the cursor is hidden
    # after fastfetch, which shows it again when it finishes
    show = "out=$(fastfetch --pipe false); printf '\\033[2J\\033[H%s\\033[?25l' \"$out\"; read -rsn1"
    subprocess.Popen(
        [
            "kitty", "--class", "sysinfo", "--title", "System Information",
            "-o", "remember_window_size=no",
            "-o", f"initial_window_width={cols + 3}c",
            "-o", f"initial_window_height={rows}c",
            "-o", f"window_padding_width={PADDING}",
            "-o", "cursor_blink_interval=0",
            "-e", "bash", "-c", show,
        ],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env={**os.environ},
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
