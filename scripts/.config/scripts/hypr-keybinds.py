#!/usr/bin/env python3
"""Keybindings from ~/.config/hypr/configs/bindings.lua as JSON, for the
Quickshell Keybindings window (mainMod + SHIFT + /).

In bindings.lua:
  -- Section name                      starts a section (a comment line on its own)
  hl.bind(mainMod .. " + Q", ...) -- Close window
                                       a bind with its description
  --> mainMod + 1 … 0 | Go to workspace 1 … 10
                                       a bind made in a loop, described by hand
Binds without a description are left out.

  hypr-keybinds.py            JSON: [{"section": ..., "binds": [{"keys": [...], "desc": ...}]}]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BINDINGS = Path.home() / ".config/hypr/configs/bindings.lua"

LOCAL_RE = re.compile(r'^\s*local\s+(\w+)\s*=\s*"([^"]*)"\s*$')
BIND_RE = re.compile(r'^\s*hl\.bind\((.*)\)\s*--\s*(.+?)\s*$')
MANUAL_RE = re.compile(r'^\s*-->\s*(.+?)\s*\|\s*(.+?)\s*$')
SECTION_RE = re.compile(r'^--\s+([A-Z][^-].*?)\s*$')
STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')

# Key names as shown on the key caps
PRETTY = {
    "return": "Enter",
    "space": "Space",
    "grave": "`",
    "equal": "=",
    "minus": "-",
    "slash": "/",
    "escape": "Esc",
    "tab": "Tab",
    "print": "Print",
    "control": "Ctrl",
    "ctrl": "Ctrl",
    "shift": "Shift",
    "alt": "Alt",
    "super": "Super",
    "mouse:272": "Left click",
    "mouse:273": "Right click",
    "xf86audioraisevolume": "Volume Up",
    "xf86audiolowervolume": "Volume Down",
    "xf86audiomute": "Mute",
    "xf86audiomicmute": "Mic Mute",
    "xf86monbrightnessup": "Brightness Up",
    "xf86monbrightnessdown": "Brightness Down",
    "xf86audionext": "Next",
    "xf86audioprev": "Previous",
    "xf86audioplay": "Play",
    "xf86audiopause": "Pause",
}


def first_argument(args: str) -> str:
    """The first argument of hl.bind(...): everything up to the first comma
    outside a string."""
    in_string = False
    for i, ch in enumerate(args):
        if ch == '"' and (i == 0 or args[i - 1] != "\\"):
            in_string = not in_string
        elif ch == "," and not in_string:
            return args[:i]
    return args


def evaluate(expr: str, local: dict[str, str]) -> str | None:
    """A Lua string expression of literals and string locals joined by `..`;
    None when it uses anything else (a loop variable)."""
    out = []
    for part in expr.split(".."):
        part = part.strip()
        m = STRING_RE.fullmatch(part)
        if m:
            out.append(m.group(1))
        elif part in local:
            out.append(local[part])
        else:
            return None
    return "".join(out)


def keys(combo: str) -> list[str]:
    parts = [p.strip() for p in combo.split("+") if p.strip()]
    pretty = []
    for p in parts:
        name = PRETTY.get(p.lower())
        if name is None:
            name = p.upper() if len(p) == 1 else p
        pretty.append(name)
    return pretty


def parse(text: str) -> list[dict]:
    local: dict[str, str] = {}
    sections: list[dict] = []
    pending = "General"

    def add(combo: str, desc: str) -> None:
        nonlocal pending
        if pending is not None:
            sections.append({"section": pending, "binds": []})
            pending = None
        if not sections:
            sections.append({"section": "General", "binds": []})
        sections[-1]["binds"].append({"keys": keys(combo), "desc": desc})

    for line in text.splitlines():
        if m := LOCAL_RE.match(line):
            local[m.group(1)] = m.group(2)
        elif m := MANUAL_RE.match(line):
            combo = m.group(1)
            for name, value in local.items():
                combo = re.sub(rf"\b{name}\b", value, combo)
            add(combo, m.group(2))
        elif m := BIND_RE.match(line):
            combo = evaluate(first_argument(m.group(1)), local)
            if combo is not None:
                add(combo, m.group(2))
        elif m := SECTION_RE.match(line):
            pending = m.group(1)
    return [s for s in sections if s["binds"]]


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    path = Path(argv[0]).expanduser() if argv else BINDINGS
    try:
        text = path.read_text()
    except OSError as e:
        print(f"hypr-keybinds: {e}", file=sys.stderr)
        print("[]")
        return 1
    print(json.dumps(parse(text)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
