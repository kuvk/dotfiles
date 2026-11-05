#!/usr/bin/env python3
"""Power menu icons in each theme's colors.

Recolors the SVGs in ~/.config/theme/icons/source/ (wlogout's icons) with the
theme's palette and writes them to ~/.config/theme/icons/<theme>/. Quickshell
uses the current theme's folder, or catppuccin-mocha's when a theme has none.
Run it after adding or changing a theme.

  theme-icons.py              all themes
  theme-icons.py NAME...      only these themes
  theme-icons.py --missing    only themes without an icons folder yet
"""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

THEME_DIR = Path.home() / ".config/theme"
THEMES_DIR = THEME_DIR / "themes"
ICONS_DIR = THEME_DIR / "icons"
SOURCE_DIR = ICONS_DIR / "source"

# Same colors as the power menu borders (services/System.qml sessionActions)
ICON_COLORS = {
    "lock": "green",
    "suspend": "peach",
    "logout": "teal",
    "reboot": "mauve",
    "shutdown": "red",
    "hibernate": "blue",
}
HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")


def themes() -> list[str]:
    return sorted(p.parent.name for p in THEMES_DIR.glob("*/colors.toml"))


def generate(name: str) -> None:
    with (THEMES_DIR / name / "colors.toml").open("rb") as f:
        colors = tomllib.load(f).get("colors", {})
    out = ICONS_DIR / name
    out.mkdir(parents=True, exist_ok=True)
    for icon, slot in ICON_COLORS.items():
        color = colors.get(slot, "")
        if not HEX_RE.match(color):
            raise ValueError(f"{name}: colors.{slot} must be a #rrggbb value")
        svg = (SOURCE_DIR / f"{icon}.svg").read_text()
        # the paths have no fill of their own, so the root fill colors them
        svg = svg.replace("<svg ", f'<svg fill="{color.lower()}" ', 1)
        target = out / f"{icon}.svg"
        if not target.exists() or target.read_text() != svg:
            target.write_text(svg)


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    if not SOURCE_DIR.is_dir():
        print(f"theme-icons: {SOURCE_DIR} not found (stow the theme package)", file=sys.stderr)
        return 1
    available = themes()
    if argv and argv[0] == "--missing":
        names = [t for t in available if not (ICONS_DIR / t).is_dir()]
    elif argv:
        unknown = [a for a in argv if a not in available]
        if unknown:
            print(f"theme-icons: unknown theme(s): {', '.join(unknown)}", file=sys.stderr)
            return 1
        names = argv
    else:
        names = available
    for name in names:
        try:
            generate(name)
        except (OSError, ValueError, tomllib.TOMLDecodeError) as e:
            print(f"theme-icons: {e}", file=sys.stderr)
            return 1
        print(f"{name}: {ICONS_DIR / name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
