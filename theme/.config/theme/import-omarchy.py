#!/usr/bin/env python3
"""Convert Omarchy themes (https://github.com/basecamp/omarchy, MIT) into
this theme format.

  import-omarchy.py <omarchy>/themes [theme ...]

Omarchy's colors.toml is semantic (background, foreground, accent, ANSI
colors, ...). Here every theme fills the same named slots, so the shades in
between are interpolated. Terminal colors follow Omarchy's kitty template
exactly. Themes without their own Neovim colorscheme use aether, as Omarchy does.
"""

import re
import sys
import tomllib
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent / "themes"

# Themes kept as hand-made exact palettes here
SKIP = {"catppuccin", "catppuccin-latte"}

# hackerman.nvim depends on an older aether; the generated aether palette looks the same
NVIM_OVERRIDES = {"hackerman": "aether"}


def mix(a: str, b: str, t: float) -> str:
    """Blend hex a toward b by t (0 = a, 1 = b)."""
    ca = [int(a[i : i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i : i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def nvim_colorscheme(theme_dir: Path) -> str:
    lua = theme_dir / "neovim.lua"
    if lua.exists():
        m = re.search(r'colorscheme\s*=\s*"([^"]+)"', lua.read_text())
        if m:
            return NVIM_OVERRIDES.get(m.group(1), m.group(1))
    return "aether"


def convert(theme_dir: Path) -> str:
    with (theme_dir / "colors.toml").open("rb") as f:
        c = {k: v.lower() if isinstance(v, str) and v.startswith("#") else v for k, v in tomllib.load(f).items()}

    fg, bg = c["foreground"], c["background"]
    get = lambda key, default: c.get(key) or default  # noqa: E731

    orange = get("orange", c["yellow"])
    bright_red = get("bright_red", c["red"])
    bright_blue = get("bright_blue", c["blue"])
    bright_magenta = get("bright_magenta", c["magenta"])
    dark_fg = get("dark_foreground", mix(fg, bg, 0.5))
    light_fg = get("light_foreground", mix(fg, bg, 0.2))
    muted = get("muted", mix(fg, bg, 0.6))
    selection = get("selection", get("selection_background", muted))

    slots = {
        "rosewater": mix(fg, c["red"], 0.15),
        "flamingo": mix(bright_magenta, fg, 0.3),
        "pink": bright_magenta,
        "mauve": c["magenta"],
        "red": c["red"],
        "maroon": bright_red if bright_red != c["red"] else mix(c["red"], fg, 0.25),
        "peach": orange,
        "yellow": c["yellow"],
        "green": c["green"],
        "teal": c["cyan"],
        "sky": get("bright_cyan", c["cyan"]),
        "sapphire": mix(c["cyan"], c["blue"], 0.5),
        "blue": c["blue"],
        "lavender": bright_blue if bright_blue != c["blue"] else mix(c["blue"], fg, 0.3),
        "text": fg,
        "subtext1": mix(light_fg, fg, 0.5),
        "subtext0": light_fg,
        "overlay2": mix(dark_fg, light_fg, 0.5),
        "overlay1": dark_fg,
        "overlay0": mix(muted, dark_fg, 0.5),
        "surface2": muted,
        "surface1": selection,
        "surface0": get("lighter_background", mix(bg, fg, 0.08)),
        "base": bg,
        "mantle": get("dark_background", mix(bg, "#000000", 0.15)),
        "crust": get("darker_background", mix(bg, "#000000", 0.3)),
    }
    accent = c.get("accent", c["blue"])
    accent2 = c["magenta"] if accent == c["blue"] else c["blue"]

    terminal = {
        "color0": bg, "color1": c["red"], "color2": c["green"], "color3": c["yellow"],
        "color4": c["blue"], "color5": c["magenta"], "color6": c["cyan"], "color7": fg,
        "color8": muted, "color9": bright_red, "color10": get("bright_green", c["green"]),
        "color11": get("bright_yellow", c["yellow"]), "color12": bright_blue,
        "color13": bright_magenta, "color14": get("bright_cyan", c["cyan"]),
        "color15": get("bright_foreground", fg),
        "cursor": get("bright_foreground", fg),
        "selection_fg": get("selection_foreground", get("bright_foreground", fg)),
        "selection_bg": selection,
    }

    name = theme_dir.name.replace("-", " ").title()
    w = max(map(len, slots))
    out = [
        f"# Imported from Omarchy ({theme_dir.name}) by import-omarchy.py",
        f'name = "{name}"',
        f'mode = "{c.get("mode", "dark")}"',
        "",
        "[colors]",
        *(f'{k.ljust(w)} = "{v}"' for k, v in slots.items()),
        "",
        f'{"accent".ljust(w)} = "{accent}"',
        f'{"accent2".ljust(w)} = "{accent2}"',
        "",
        "[terminal]",
        *(f'{k} = "{v}"' for k, v in terminal.items()),
        "",
        "[apps]",
        f'nvim_colorscheme = "{nvim_colorscheme(theme_dir)}"',
        "",
    ]
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__.strip())
        return 1
    src = Path(argv[0])
    names = argv[1:] or sorted(p.parent.name for p in src.glob("*/colors.toml"))
    for name in names:
        if name in SKIP:
            continue
        theme_dir = src / name
        dest = OUT_DIR / name / "colors.toml"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(convert(theme_dir))
        print(f"imported {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
