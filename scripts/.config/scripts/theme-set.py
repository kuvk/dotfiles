#!/usr/bin/env python3
"""Switch the system-wide color theme.

Every theme is a single colors.toml in ~/.config/theme/themes/<name>/.
Templates in ~/.config/theme/templates/*.tpl are rendered into
~/.config/theme/current/, which every app config points at, and running
apps are told to reload.

  theme-set.py <name>     apply a theme
  theme-set.py            re-apply the current theme (after editing templates)
  theme-set.py --list     list theme names
  theme-set.py --json     list themes with a few colors (used by quickshell)
  theme-set.py --current  print the current theme name
  theme-set.py --cursors  list the installed cursor themes as JSON
  theme-set.py --icon-themes  list the installed icon themes as JSON
  theme-set.py --icons NAME  apply an icon theme (Settings > Appearance saves the choice)
  theme-set.py --cursor NAME SIZE
                          apply a cursor everywhere (Settings > Appearance saves the choice)
  theme-set.py --fonts NERD DISPLAY on|off HINTING ANTIALIASING
                          apply fonts everywhere (Settings > Fonts saves the choice); on means
                          Nerd Fonts only. HINTING: none|slight|medium|full,
                          ANTIALIASING: none|grayscale|rgba
  theme-set.py --login    rewrite the login screen's colors from Settings > Lock Screen
  theme-set.py --text-size  GTK's font size from Displays > Text size (hypr-monitors.py)
  theme-set.py --follow-wallpaper
                          the logo wallpaper in this theme's colors, when Settings >
                          Appearance > Wallpaper follows theme is on
  theme-set.py --window-buttons on|off
                          close button in GTK apps (Settings > Windows saves the choice)
  theme-set.py --shape rounded|square
                          corners of the status lines in tmux, nvim and yazi, Neovim's
                          windows, LazyGit and the starship prompt
                          (quickshell sets it: square in Work-Game or at radius 0)
"""

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tomllib
from pathlib import Path

HOME = Path.home()
THEME_DIR = HOME / ".config/theme"
THEMES_DIR = THEME_DIR / "themes"
TEMPLATES_DIR = THEME_DIR / "templates"
CURRENT_DIR = THEME_DIR / "current"
ICONS_DIR = THEME_DIR / "icons"
STATE_FILE = CURRENT_DIR / "theme"
DEFAULT_THEME = "catppuccin-mocha"

# Rendered files that also need a copy somewhere an app can find them
EXTRA_DESTINATIONS = {
    "hyprland.lua": HOME / ".config/hypr/configs/generated/theme.lua",
    # btop and bat find themes by name in their own themes folders
    "btop.theme": HOME / ".config/btop/themes/current.theme",
    "bat.tmTheme": HOME / ".config/bat/themes/Current.tmTheme",
    "cava": HOME / ".config/cava/themes/current",
    "yazi-theme.toml": HOME / ".config/yazi/theme.toml",
    # catppuccin/tmux may be at plugins/catppuccin/tmux and, through TPM, at
    # plugins/tmux. Every copy gets the flavor, since the last one loaded wins.
    "tmux.conf": [
        HOME / ".tmux/plugins/catppuccin/tmux/themes/catppuccin_current_tmux.conf",
        HOME / ".tmux/plugins/tmux/themes/catppuccin_current_tmux.conf",
    ],
    "cliamp.toml": HOME / ".config/cliamp/themes/system.toml",
    "herdr-config.toml": HOME / ".config/herdr/config.toml",
    # eza's icons, the same as yazi's (theme/eza-icons.py writes the template)
    "eza-theme.yml": HOME / ".config/eza/theme.yml",
    # GTK adds these to whatever theme is set
    "gtk.css": HOME / ".config/gtk-3.0/gtk.css",
    "gtk4.css": HOME / ".config/gtk-4.0/gtk.css",
    "gtk-settings.ini": [HOME / ".config/gtk-3.0/settings.ini", HOME / ".config/gtk-4.0/settings.ini"],
    "kdeglobals": HOME / ".config/kdeglobals",
    "qt5ct.conf": HOME / ".config/qt5ct/qt5ct.conf",
    "qt6ct.conf": HOME / ".config/qt6ct/qt6ct.conf",
    "kvantum.kvconfig": HOME / ".config/Kvantum/kvantum.kvconfig",
    "kvantum-current.kvconfig": HOME / ".config/Kvantum/current/current.kvconfig",
    "kvantum-current.svg": HOME / ".config/Kvantum/current/current.svg",
    "hyprtoolkit.conf": HOME / ".config/hypr/hyprtoolkit.conf",
    "cursor-index.theme": HOME / ".icons/default/index.theme",
    "sddm-cursor.conf": Path("/var/lib/kuvk-shell/cursor.conf"),
    # the login screen; that folder only exists after sddm/install.sh
    "sddm-theme.conf": Path("/var/lib/kuvk-shell/theme.conf"),
}
# Written only when the app's folder exists (don't create a half plugin dir)
ONLY_IF_PRESENT = {"tmux.conf", "cliamp.toml"}

FASTFETCH_SOURCE = HOME / ".config/fastfetch/base.jsonc"
FASTFETCH_OUTPUT = HOME / ".config/fastfetch/config.jsonc"
STARSHIP_SOURCE = HOME / ".config/starship/base.toml"
STARSHIP_OUTPUT = HOME / ".config/starship.toml"

SLOTS = (
    "rosewater flamingo pink mauve red maroon peach yellow green teal sky "
    "sapphire blue lavender text subtext1 subtext0 overlay2 overlay1 overlay0 "
    "surface2 surface1 surface0 base mantle crust"
).split()
# selection_*: selected text in every app. selection_fg defaults to the accent, or
# to the text color in themes where the accent can't be read on selection_bg.
ROLES = {"accent": "peach", "accent2": "blue", "accent3": "peach", "selection_bg": "surface1"}
MIN_SELECTION_CONTRAST = 3.0
CURSOR_DIRS = (HOME / ".icons", HOME / ".local/share/icons", Path("/usr/share/icons"))

HINTINGS = ("none", "slight", "medium", "full")
ANTIALIASINGS = ("none", "grayscale", "rgba")

# --cursor sets these: Quickshell may not have saved the choice to its file yet
SETTINGS_OVERRIDE: dict = {}

HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
PLACEHOLDER_RE = re.compile(r"\{\{\s*([\w.]+)\s*\}\}")


def notify(body: str) -> None:
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Theme", "-i", "preferences-desktop-theme", body], check=False)


def run_quiet(cmd: list[str]) -> None:
    if shutil.which(cmd[0]):
        subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def available_themes() -> list[str]:
    if not THEMES_DIR.is_dir():
        return []
    return sorted(p.parent.name for p in THEMES_DIR.glob("*/colors.toml"))


def current_theme() -> str:
    try:
        name = STATE_FILE.read_text().strip()
    except FileNotFoundError:
        return DEFAULT_THEME
    return name or DEFAULT_THEME


def luminance(color: str) -> float:
    channels = [int(color[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    r, g, b = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: str, b: str) -> float:
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def current_shape() -> str:
    try:
        return (CURRENT_DIR / "shape").read_text().strip()
    except FileNotFoundError:
        return "rounded"


ICONS_FILE = THEME_DIR / "icons.toml"


def icon_strings(colors: dict) -> dict:
    """icons.toml as yazi [icon] lines and a Lua table for Neovim, in this theme's colors:
    folders accent, links accent3, files and extensions in their own color (a theme color
    name or #hex)."""
    try:
        icons = tomllib.loads(ICONS_FILE.read_text())
    except (OSError, tomllib.TOMLDecodeError) as e:
        print(f"theme-set: {ICONS_FILE}: {e}", file=sys.stderr)
        icons = {}
    color = lambda c: colors.get(c, c if HEX_RE.match(c or "") else colors["text"])
    toml = lambda v: json.dumps(v, ensure_ascii=False)
    dirs = [(n, d["icon"]) for d in icons.get("dir", []) for n in d.get("names", [])]
    files = [(n, f["icon"], color(f.get("color", "text"))) for f in icons.get("file", []) for n in f.get("names", [])]
    exts = [(n, e["icon"], color(e.get("color", "text"))) for e in icons.get("ext", []) for n in e.get("names", [])]
    link = icons.get("link", {})
    lua = lambda v: json.dumps(v, ensure_ascii=False)  # a JSON string is a Lua string literal
    lua_entries = lambda rows: "{ " + ", ".join(f"[{lua(n)}] = {{ {lua(i)}, {lua(c)} }}" for n, i, c in rows) + " }"
    return {
        "yazi_icon_dirs": "\n".join(f'\t{{ name = {toml(n)}, text = {toml(i)}, fg = {toml(colors["accent"])} }},' for n, i in dirs),
        "yazi_icon_files": "\n".join(f'\t{{ name = {toml(n)}, text = {toml(i)}, fg = {toml(c)} }},' for n, i, c in files),
        "yazi_icon_exts": "\n".join(f'\t{{ name = {toml(n)}, text = {toml(i)}, fg = {toml(c)} }},' for n, i, c in exts),
        "icon_link_dir": toml(link.get("dir", "\ue5ff"))[1:-1],
        "icon_link_file": toml(link.get("file", "\uf15b"))[1:-1],
        "icon_link_broken": toml(link.get("broken", "\U000f086f"))[1:-1],
        "nvim_icons": "{ dirs = { " + ", ".join(f"[{lua(n)}] = {lua(i)}" for n, i in dirs) + " }, files = "
        + lua_entries(files) + ", exts = " + lua_entries(exts)
        + f", link_dir = {lua(link.get('dir', chr(0xe5ff)))}, link_file = {lua(link.get('file', chr(0xf15b)))}"
        + f", link_broken = {lua(link.get('broken', chr(0xf086f)))} }}",
    }


def blend(a: str, b: str, amount: float) -> str:
    """b mixed into a by amount (0..1), as #rrggbb."""
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * amount):02x}" for x, y in zip(ca, cb))


def shell_settings() -> dict:
    """What's chosen in Quickshell's Settings: the saved settings, then the shell's
    defaults.json (a fresh install, before the shell has saved any), then these."""
    settings = {
        "displayFont": "SF Pro Display",
        "nerdFont": "JetBrainsMono Nerd Font",
        "nerdFontOnly": True,
        "fontHinting": "slight",
        "fontAntialiasing": "rgba",
        "windowButtons": False,
        "lockClockColor": "accent",
        "lockAvatarColor": "accent",
        "lockBoxOutlineColor": "accent",
        "lockBoxColor": "base",
        "lockInputOutlineColor": "accent",
        "lockInputColor": "subtext0",
        "lockDotsColor": "accent2",
        "lockUserColor": "accent",
        "lockTextColor": "text",
        "lockCheckColor": "green",
        "lockFailColor": "red",
        "lockCapsColor": "peach",
        "lockBoxOpacity": 90,
        "lockBox": False,
        "wallpaperFollowsTheme": True,
        "lockClock": False,
        "lockAvatar": True,
        "lockPowerColor": "base",
        "lockPowerOpacity": 85,
        "lockPowerIconColor": "accent2",
        "lockPowerOutlineColor": "accent",
        "accentOverrides": {"gruvbox": {"accent": "blue", "accent2": "peach", "accent3": "mauve"}, "tokyo-night": {"accent": "teal", "accent2": "peach", "accent3": "mauve"}},
        "lockInputOpacity": 30,
        "cursorTheme": "Adwaita",
        "cursorSize": 24,
        "iconTheme": "Papirus",
    }
    sources = [HOME / ".config/quickshell/config/defaults.json"]
    sources += sorted((HOME / ".local/state/quickshell/by-shell").glob("*/settings.json"))
    for path in sources:
        try:
            saved = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        settings.update({key: saved[key] for key in settings if key in saved})
    return settings | SETTINGS_OVERRIDE


def cursor_themes() -> list[str]:
    names = {
        path.parent.parent.name
        for folder in CURSOR_DIRS
        for path in folder.glob("*/cursors/left_ptr")
        if path.parent.parent.name != "default"
    }
    return sorted(names, key=str.lower)


def icon_themes() -> list[str]:
    names = set()
    for folder in CURSOR_DIRS:
        for index in folder.glob("*/index.theme"):
            if index.parent.name in ("default", "hicolor"):
                continue
            text = index.read_text(errors="ignore")
            # cursor themes have an index.theme too, without icon folders
            if re.search(r"^Directories\s*=\s*\S", text, re.M) and not re.search(r"^Hidden\s*=\s*true", text, re.M | re.I):
                names.add(index.parent.name)
    return sorted(names, key=str.lower)


def icon_theme_for(name: str, mode: str) -> str:
    """A theme with a variant for the mode uses it, so Papirus follows light and dark;
    choosing the variant itself (Papirus-Dark) keeps it in both."""
    variant = f"{name}-{mode.capitalize()}"
    return variant if variant in icon_themes() else name


def load_theme(name: str) -> dict:
    path = THEMES_DIR / name / "colors.toml"
    with path.open("rb") as f:
        data = tomllib.load(f)

    raw = dict(data.get("colors", {}))
    # Settings > Appearance > Accent: another slot of this theme's palette
    chosen = shell_settings().get("accentOverrides", {})
    chosen = chosen.get(name, {}) if isinstance(chosen, dict) else {}
    for role in ("accent", "accent2", "accent3"):
        if chosen.get(role) in SLOTS:
            raw[role] = chosen[role]
    colors: dict[str, str] = {}
    for slot in SLOTS:
        value = raw.get(slot)
        if not isinstance(value, str) or not HEX_RE.match(value):
            raise ValueError(f"{path}: colors.{slot} must be a #rrggbb value")
        colors[slot] = value.lower()

    # Roles and terminal entries may name a slot instead of a hex value
    def resolve(value: str, key: str) -> str:
        if HEX_RE.match(value):
            return value.lower()
        if value in colors:
            return colors[value]
        raise ValueError(f"{path}: {key} = {value!r} is neither a hex color nor a slot")

    for role, default in ROLES.items():
        colors[role] = resolve(raw.get(role, default), f"colors.{role}")
    readable = contrast(colors["accent"], colors["selection_bg"]) >= MIN_SELECTION_CONTRAST
    colors["selection_fg"] = resolve(raw.get("selection_fg", "accent" if readable else "text"), "colors.selection_fg")

    terminal_defaults = {
        "color0": "surface1", "color8": "surface2",
        "color1": "red", "color9": "red",
        "color2": "green", "color10": "green",
        "color3": "yellow", "color11": "yellow",
        "color4": "blue", "color12": "blue",
        "color5": "mauve", "color13": "mauve",
        "color6": "teal", "color14": "teal",
        "color7": "subtext1", "color15": "subtext0",
        "cursor": "rosewater",
        "selection_fg": "base", "selection_bg": "rosewater",
    }
    terminal_raw = data.get("terminal", {})
    for key, default in terminal_defaults.items():
        colors[f"term_{key}"] = resolve(terminal_raw.get(key, default), f"terminal.{key}")

    mode = data.get("mode", "dark")
    if mode not in ("dark", "light"):
        raise ValueError(f"{path}: mode must be 'dark' or 'light'")

    shell = shell_settings()
    hinting, antialiasing = shell["fontHinting"], shell["fontAntialiasing"]
    strings = {
        "theme": name,
        "theme_name": data.get("name", name),
        "mode": mode,
        "cursor_theme": shell["cursorTheme"],
        "cursor_size": str(shell["cursorSize"]),
        "display_font": shell["displayFont"],
        "nerd_font": shell["nerdFont"],
        # what apps show text in: "Nerd Fonts only" replaces the display font
        "text_font": shell["nerdFont"] if shell["nerdFontOnly"] else shell["displayFont"],
        "font_hinting": hinting,
        "font_antialiasing": antialiasing,
        "gtk_font_pt": str(gtk_font_pt()),
        # the cursor line in Neovim's neo-tree (Catppuccin's: surface0 64% over base); yazi's
        # hover highlight uses it too
        "cursorline": blend(colors["base"], colors["surface0"], 0.64),
        # yazi's hover highlight ends: rounded caps, or full blocks. yazi draws these in the
        # highlight's color (a space would come out in the background's), so either way the
        # bar starts one character before the icon.
        "yazi_pad_open": "\u2588" if current_shape() == "square" else "\ue0b6",
        "yazi_pad_close": "\u2588" if current_shape() == "square" else "\ue0b4",
        "fc_antialias": "false" if antialiasing == "none" else "true",
        "fc_hinting": "false" if hinting == "none" else "true",
        "fc_hintstyle": f"hint{hinting}",
        "fc_rgba": "rgb" if antialiasing == "rgba" else "none",
        "fc_lcdfilter": "lcddefault" if antialiasing == "rgba" else "lcdnone",
        "xft_antialias": "0" if antialiasing == "none" else "1",
        "xft_hinting": "0" if hinting == "none" else "1",
        "decoration_layout": ":close" if shell["windowButtons"] else ":",
        "border_style": "single" if current_shape() == "square" else "rounded",
        # the login screen uses the lock screen's colors
        "login_clock": colors.get(shell["lockClockColor"], colors["text"]),
        "login_date": colors.get(shell["lockClockColor"], colors["text"]),  # one color for both
        "login_avatar": colors.get(shell["lockAvatarColor"], colors["text"]),
        "login_boxOutline": colors.get(shell["lockBoxOutlineColor"], colors["text"]),
        "login_box": colors.get(shell["lockBoxColor"], colors["text"]),
        "login_inputOutline": colors.get(shell["lockInputOutlineColor"], colors["text"]),
        "login_input": colors.get(shell["lockInputColor"], colors["text"]),
        "login_dots": colors.get(shell["lockDotsColor"], colors["text"]),
        "login_user": colors.get(shell["lockUserColor"], colors["text"]),
        "login_text": colors.get(shell["lockTextColor"], colors["text"]),
        "login_check": colors.get(shell["lockCheckColor"], colors["text"]),
        "login_fail": colors.get(shell["lockFailColor"], colors["text"]),
        "login_caps": colors.get(shell["lockCapsColor"], colors["text"]),
        "login_box_opacity": str(shell["lockBoxOpacity"] / 100),
        "login_show_box": "true" if shell["lockBox"] else "false",
        "login_show_clock": "true" if shell["lockClock"] else "false",
        "login_show_avatar": "true" if shell["lockAvatar"] else "false",
        "login_power_bg": colors.get(shell["lockPowerColor"], colors["base"]),
        "login_power_opacity": str(shell["lockPowerOpacity"] / 100),
        "login_power_icon": colors.get(shell["lockPowerIconColor"], colors["text"]),
        "login_power_outline": colors.get(shell["lockPowerOutlineColor"], colors["text"]),
        "login_input_opacity": str(shell["lockInputOpacity"] / 100),
        "icon_theme": icon_theme_for(shell["iconTheme"], mode),
        "prefer_dark": "0" if mode == "light" else "1",
        # adw-gtk3, when installed, follows gtk.css in plain GTK3 and GTK4 apps too;
        # Adwaita only does in libadwaita apps
        "gtk_theme": ("adw-gtk3" if Path("/usr/share/themes/adw-gtk3").is_dir() else "Adwaita")
        + ("" if mode == "light" else "-dark"),
    }
    for key, value in data.get("apps", {}).items():
        strings[key] = str(value)
    strings.update(icon_strings(colors))  # icons.toml: folder, file and link icons

    return {"colors": colors, "strings": strings, "dir": path.parent}


def render(text: str, theme: dict, source: str) -> str:
    colors, strings = theme["colors"], theme["strings"]

    def substitute(match: re.Match) -> str:
        key = match.group(1)
        name, _, fmt = key.partition(".")
        if name in colors:
            value = colors[name]
            if fmt == "":
                return value
            if fmt == "hex":
                return value[1:]
            if fmt == "rgb":
                return ", ".join(str(int(value[i : i + 2], 16)) for i in (1, 3, 5))
            if fmt == "ansi":  # 24-bit SGR foreground code, e.g. for fastfetch
                return "38;2;" + ";".join(str(int(value[i : i + 2], 16)) for i in (1, 3, 5))
            if fmt == "ansi_bg":  # the same as a background
                return "48;2;" + ";".join(str(int(value[i : i + 2], 16)) for i in (1, 3, 5))
        elif name in strings and fmt == "":
            return strings[name]
        raise KeyError(f"{source}: unknown placeholder {{{{ {key} }}}}")

    return PLACEHOLDER_RE.sub(substitute, text)


def write_if_changed(path: Path, content: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        if path.read_text() == content:
            return False
    except FileNotFoundError:
        pass
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(content)
    tmp.replace(path)  # atomic, so file watchers never see a half-written file
    return True


def render_fastfetch(theme: dict) -> None:
    """fastfetch has no includes either: config.jsonc is base.jsonc with the
    theme's colors filled in (read on every run)."""
    if not FASTFETCH_SOURCE.exists():
        return
    header = "// Generated by theme-set.py from ~/.config/fastfetch/base.jsonc; edit that file\n"
    try:
        content = render(FASTFETCH_SOURCE.read_text(), theme, "fastfetch/base.jsonc")
    except KeyError as e:  # a typo in base.jsonc must not stop the theme switch
        print(f"theme-set: {e}", file=sys.stderr)
        return
    write_if_changed(FASTFETCH_OUTPUT, header + content)


def render_starship(theme: dict) -> None:
    """starship has no includes: ~/.config/starship.toml is generated from
    ~/.config/starship/base.toml plus the palette (starship rereads it every prompt)."""
    if not STARSHIP_SOURCE.exists():
        return
    base = re.sub(r"^palette\s*=.*$", "palette = 'theme'", STARSHIP_SOURCE.read_text(), count=1, flags=re.M)
    # square corners in Work-Game or with the corner radius at 0 (--shape)
    if current_shape() == "square":
        base = base.replace("╭", "┌").replace("╰", "└")
    palette = "\n# Generated by theme-set\n[palettes.theme]\n" + "".join(
        f'{slot} = "{theme["colors"][slot]}"\n' for slot in [*SLOTS, *ROLES]
    )
    header = "# Generated by theme-set.py from ~/.config/starship/base.toml; edit that file\n"
    write_if_changed(STARSHIP_OUTPUT, header + base.rstrip() + "\n" + palette)


def icons_dir(name: str) -> str:
    """Power menu icons from theme-icons.py, or Catppuccin's for a theme
    that has none yet."""
    for candidate in (name, "catppuccin-mocha"):
        if (ICONS_DIR / candidate / "lock.svg").is_file():
            return str(ICONS_DIR / candidate)
    return ""


def render_quickshell(theme: dict) -> None:
    data = {
        "theme": theme["strings"]["theme"],
        "name": theme["strings"]["theme_name"],
        "mode": theme["strings"]["mode"],
        "icons": icons_dir(theme["strings"]["theme"]),
        "colors": {k: v for k, v in theme["colors"].items() if not k.startswith("term_")},
    }
    write_if_changed(CURRENT_DIR / "quickshell.json", json.dumps(data, indent=2) + "\n")


def render_ls_colors() -> None:
    """dircolors' output for .zshrc, so shells set LS_COLORS without running it."""
    # dircolors outputs nothing unless TERM matches, and the shell's picker and autostart have none
    env = os.environ | {"TERM": "xterm-256color"}
    out = subprocess.run(["dircolors", "-b", str(CURRENT_DIR / "dir_colors")], capture_output=True, text=True, env=env)
    if out.returncode == 0:
        write_if_changed(CURRENT_DIR / "ls_colors.zsh", out.stdout)
    else:
        print(f"theme-set: dircolors: {out.stderr.strip()}", file=sys.stderr)


def generate(name: str) -> dict:
    theme = load_theme(name)
    theme["changed"] = set()
    for tpl in sorted(TEMPLATES_DIR.glob("*.tpl")):
        out_name = tpl.name.removesuffix(".tpl")
        content = render(tpl.read_text(), theme, tpl.name)
        write_if_changed(CURRENT_DIR / out_name, content)
        targets = EXTRA_DESTINATIONS.get(out_name, [])
        for dest in targets if isinstance(targets, list) else [targets]:
            if out_name in ONLY_IF_PRESENT and not dest.parent.parent.is_dir():
                continue
            if out_name.startswith("sddm-") and not dest.parent.is_dir():
                continue
            if out_name == "tmux.conf" and not (dest.parent.parent / "catppuccin.tmux").is_file():
                continue  # some other plugin named "tmux"
            try:
                if write_if_changed(dest, content):
                    theme["changed"].add(out_name)
            except OSError as e:
                print(f"theme-set: could not write {dest}: {e}", file=sys.stderr)

    render_quickshell(theme)
    render_starship(theme)
    render_fastfetch(theme)

    # A theme may ship its own file for any app (e.g. a hand-tuned btop.theme);
    # it replaces the rendered one.
    for override in theme["dir"].iterdir():
        if override.name != "colors.toml" and override.is_file():
            write_if_changed(CURRENT_DIR / override.name, override.read_text())

    render_ls_colors()
    write_if_changed(STATE_FILE, name + "\n")
    return theme


def hypr_running() -> bool:
    return bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")) and shutil.which("hyprctl") is not None


def apply_cursor(strings: dict) -> None:
    interface = "org.gnome.desktop.interface"
    run_quiet(["gsettings", "set", interface, "cursor-theme", strings["cursor_theme"]])
    run_quiet(["gsettings", "set", interface, "cursor-size", strings["cursor_size"]])
    if hypr_running():
        run_quiet(["hyprctl", "setcursor", strings["cursor_theme"], strings["cursor_size"]])


def gtk_font_pt() -> int:
    """GTK's font size in points for Displays > Text size (px, kept by hypr-monitors.py):
    13 px is 10 pt. Set as the font size rather than GTK's text-scaling-factor, which
    Electron apps on Wayland (Obsidian, Mullvad) apply to their content without resizing
    the window, leaving an empty strip."""
    try:
        size = int(json.loads((HOME / ".config/hypr/monitors.json").read_text()).get("text_size", 13))
    except (OSError, ValueError, TypeError, AttributeError):
        size = 13
    return max(6, round(10 * size / 13))


def apply_fonts(strings: dict) -> None:
    interface = "org.gnome.desktop.interface"
    pt = strings["gtk_font_pt"]
    run_quiet(["gsettings", "set", interface, "font-name", f"{strings['text_font']} {pt}"])
    run_quiet(["gsettings", "set", interface, "document-font-name", f"{strings['text_font']} {pt}"])
    run_quiet(["gsettings", "set", interface, "monospace-font-name", f"{strings['nerd_font']} {pt}"])
    run_quiet(["gsettings", "set", interface, "text-scaling-factor", "1.0"])
    run_quiet(["gsettings", "set", interface, "font-hinting", strings["font_hinting"]])
    run_quiet(["gsettings", "set", interface, "font-antialiasing", strings["font_antialiasing"]])
    run_quiet(["gsettings", "set", interface, "font-rgba-order", "rgb"])


def apply_window_buttons(strings: dict) -> None:
    run_quiet(["gsettings", "set", "org.gnome.desktop.wm.preferences", "button-layout", strings["decoration_layout"]])


def set_gtk_theme(strings: dict) -> None:
    """Wayland GTK apps read these; settings.ini (rendered above) is for XWayland ones."""
    interface = "org.gnome.desktop.interface"
    run_quiet(["gsettings", "set", interface, "gtk-theme", strings["gtk_theme"]])
    run_quiet(["gsettings", "set", interface, "icon-theme", strings["icon_theme"]])
    apply_cursor(strings)
    apply_fonts(strings)
    apply_window_buttons(strings)
    run_quiet(["gsettings", "set", interface, "color-scheme", f"prefer-{strings['mode']}"])


def reload_apps(theme: dict) -> None:
    colors, strings = theme["colors"], theme["strings"]

    # quickshell and neovim watch their generated files; poke quickshell anyway
    # in case the watch was lost when the file was replaced
    run_quiet(["qs", "ipc", "call", "theme", "reload"])

    if hypr_running():
        # Same in every mode (hyprland.lua.tpl): active in full color, inactive see-through
        active = f"rgb({colors['accent'][1:]})"
        inactive = f"rgba({colors['accent2'][1:]}e6)"
        run_quiet([
            "hyprctl", "eval",
            f"hl.config({{ general = {{ col = {{ active_border = '{active}', inactive_border = '{inactive}' }} }} }})",
        ])

    run_quiet(["pkill", "-USR1", "-x", "kitty"])
    run_quiet(["pkill", "-USR2", "-x", "btop"])
    run_quiet(["pkill", "-USR2", "-x", "cava"])  # reload colors
    run_quiet(["pkill", "-USR1", "-x", "swayimg"])  # re-reads current/swayimg.lua
    # bat reads themes from a cache that must be rebuilt
    if "bat.tmTheme" in theme.get("changed", ()) and shutil.which("bat"):
        run_quiet(["bat", "cache", "--build"])
    if "yazi-theme.toml" in theme.get("changed", ()):
        restart_yazi()
    redraw_prompts()
    if shutil.which("tmux") and subprocess.run(["tmux", "info"], capture_output=True).returncode == 0:
        run_quiet(["tmux", "source-file", str(HOME / ".tmux.conf")])
    # a running cliamp re-reads the theme file when told to switch to it
    if "cliamp.toml" in theme.get("changed", ()) and shutil.which("cliamp") and (HOME / ".config/cliamp/cliamp.sock").exists():
        run_quiet(["cliamp", "theme", "system"])

    # ~/.local/bin isn't on PATH when the shell's theme picker runs this
    herdr = shutil.which("herdr") or str(HOME / ".local/bin/herdr")
    if "herdr-config.toml" in theme.get("changed", ()) and os.access(herdr, os.X_OK):
        run_quiet([herdr, "server", "reload-config"])

    # file dialogs: the portal reads gtk.css only when it starts
    if "gtk.css" in theme.get("changed", ()):
        run_quiet(["systemctl", "--user", "try-restart", "xdg-desktop-portal-gtk.service"])

    browsers(colors["base"])

    set_gtk_theme(strings)

    wallpaper = strings.get("wallpaper")
    if wallpaper and hypr_running():
        path = Path(os.path.expanduser(wallpaper))
        if not path.is_absolute():
            path = theme["dir"] / path
        if path.exists():
            out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True)
            try:
                monitors = [m["name"] for m in json.loads(out.stdout)]
            except (json.JSONDecodeError, KeyError, TypeError):
                monitors = []
            for monitor in monitors:
                run_quiet(["hyprctl", "hyprpaper", "wallpaper", f"{monitor},{path},cover"])


def redraw_prompts() -> None:
    """Open zsh shells redraw their starship prompt in the new colors. Only
    shells that registered themselves (.zshrc, they trap USR1) are signalled:
    USR1 would end any other process."""
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "zsh-prompt"
    if not runtime.is_dir():
        return
    for entry in runtime.iterdir():
        try:
            pid = int(entry.name)
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() != "zsh":
                    raise ProcessLookupError
            os.kill(pid, signal.SIGUSR1)
        except (ValueError, OSError):
            entry.unlink(missing_ok=True)  # gone, or the pid was reused


def restart_yazi() -> None:
    """yazi can't reload its theme: every yazi started by yazi-live.sh is told
    to quit (it writes its folder) and the script reopens it right there."""
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "yazi-live"
    if not shutil.which("ya") or not runtime.is_dir():
        return
    for client in runtime.glob("*.client"):
        pid = client.stem
        try:
            os.kill(int(pid), 0)
        except (ValueError, ProcessLookupError):
            client.unlink(missing_ok=True)  # left over from a crash
            continue
        except PermissionError:
            continue
        (runtime / f"{pid}.restart").touch()
        run_quiet(["ya", "emit-to", pid, "quit"])


BROWSER_HELPER = "/usr/local/bin/browser-theme-policy"


def browsers(color: str) -> None:
    """Chromium/Brave theme color via managed policy (browser-theme-setup.sh).
    Does nothing until that one-time setup has been run."""
    if not Path(BROWSER_HELPER).exists() or not shutil.which("sudo"):
        return
    result = subprocess.run(["sudo", "-n", BROWSER_HELPER, color[1:]],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode != 0:
        return
    # Running browsers pick the policy up without a restart
    for proc, binary in (("chromium", "chromium"), ("brave", "brave")):
        if shutil.which(binary) and subprocess.run(["pgrep", "-x", proc], capture_output=True).returncode == 0:
            subprocess.Popen([binary, "--refresh-platform-policy", "--no-startup-window"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def themes_json() -> str:
    current = current_theme()
    result = []
    for name in available_themes():
        try:
            theme = load_theme(name)
        except (ValueError, tomllib.TOMLDecodeError) as e:
            print(e, file=sys.stderr)
            continue
        c = theme["colors"]
        result.append({
            "theme": name,
            "name": theme["strings"]["theme_name"],
            "mode": theme["strings"]["mode"],
            "current": name == current,
            "swatches": [c["base"], c["text"], c["accent"], c["accent2"], c["red"], c["green"], c["yellow"], c["mauve"]],
            # for the theme carousel's palette preview cards
            "colors": {k: c[k] for k in (
                "base", "mantle", "crust", "surface0", "surface1", "overlay0", "overlay1", "text", "subtext0",
                "accent", "accent2", "accent3", "red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink",
            )},
        })
    return json.dumps(result)


def set_shape(shape: str) -> None:
    if not write_if_changed(CURRENT_DIR / "shape", shape + "\n"):
        return
    # templates that draw corners (lazygit)
    generate(current_theme())
    # nvim watches the file
    if subprocess.run(["tmux", "info"], capture_output=True).returncode == 0:
        run_quiet(["tmux", "source-file", str(HOME / ".tmux.conf")])
    restart_yazi()


def follow_wallpaper(theme: dict) -> None:
    """Settings > Appearance > Wallpaper follows theme: the logo in accent2 on base, drawn once
    per theme and colors (logo-wallpaper.py) and set on every monitor, so the lock and login
    screens follow too. Picking another wallpaper turns this off (WallpaperPicker.qml)."""
    if not shell_settings().get("wallpaperFollowsTheme"):
        return
    colors, name = theme["colors"], theme["strings"]["theme"]
    folder = HOME / "Pictures/Wallpapers"
    path = folder / f"dori-theme-{name}-{colors['accent2'][1:]}-on-{colors['base'][1:]}.png"
    scripts = HOME / ".config/scripts"
    if not path.exists():
        for old in folder.glob(f"dori-theme-{name}-*.png"):  # this theme in older colors
            old.unlink(missing_ok=True)
        run_quiet([str(scripts / "logo-wallpaper.py"), "--bg", colors["base"], "--fg", colors["accent2"],
                   "--size", "30", "--output", str(path)])
        if not path.exists():
            return
    current = HOME / ".local/state/wallpaper/current"
    if current.resolve() != path.resolve():
        run_quiet([str(scripts / "wallpaper.py"), "set", "static", str(path)])


def offer_boot_update() -> None:
    """A notification with an Update button when the boot splash and menu were built from
    other colors (theme-boot.sh --check); the button opens a kitty window with theme-boot.sh,
    its password prompt and output (theme-boot.sh --window)."""
    script = HOME / ".config/scripts/theme-boot.sh"
    if not script.exists() or not shutil.which("notify-send"):
        return
    if subprocess.run([str(script), "--check"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        return
    ask = (
        'a=$(notify-send -a "Boot screens" -i preferences-desktop-theme -A update=Update '
        '"Boot screens use the old theme" '
        '"The boot menu and splash keep their colors until updated. Update asks for your password '
        'and takes about a minute."); [ "$a" = update ] && exec "$0" --window'
    )
    subprocess.Popen(["bash", "-c", ask, str(script)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    if len(argv) == 2 and argv[0] == "--shape" and argv[1] in ("rounded", "square"):
        set_shape(argv[1])
        return 0
    if argv and argv[0] == "--list":
        print("\n".join(available_themes()))
        return 0
    if argv and argv[0] == "--json":
        print(themes_json())
        return 0
    if argv and argv[0] == "--cursors":
        print(json.dumps(cursor_themes()))
        return 0
    if len(argv) == 3 and argv[0] == "--cursor":
        if argv[1] not in cursor_themes() or not argv[2].isdigit():
            print(f"Unknown cursor '{argv[1]} {argv[2]}'", file=sys.stderr)
            return 1
        SETTINGS_OVERRIDE.update(cursorTheme=argv[1], cursorSize=int(argv[2]))
        apply_cursor(generate(current_theme())["strings"])
        return 0
    if argv and argv[0] == "--icon-themes":
        print(json.dumps(icon_themes()))
        return 0
    if len(argv) == 2 and argv[0] == "--icons":
        if argv[1] not in icon_themes():
            print(f"Unknown icon theme '{argv[1]}'", file=sys.stderr)
            return 1
        SETTINGS_OVERRIDE.update(iconTheme=argv[1])
        strings = generate(current_theme())["strings"]
        run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", strings["icon_theme"]])
        return 0
    if len(argv) == 6 and argv[0] == "--fonts":
        nerd, display, only, hinting, antialiasing = argv[1:]
        if only not in ("on", "off") or hinting not in HINTINGS or antialiasing not in ANTIALIASINGS:
            print(f"Unknown font options '{only} {hinting} {antialiasing}'", file=sys.stderr)
            return 1
        SETTINGS_OVERRIDE.update(nerdFont=nerd, displayFont=display, nerdFontOnly=only == "on",
                                 fontHinting=hinting, fontAntialiasing=antialiasing)
        apply_fonts(generate(current_theme())["strings"])
        return 0
    if argv == ["--text-size"]:
        # Displays > Text size changed (hypr-monitors.py): GTK's font size
        apply_fonts(generate(current_theme())["strings"])
        return 0
    if argv == ["--follow-wallpaper"]:
        follow_wallpaper(load_theme(current_theme()))
        return 0
    if argv == ["--login"]:
        generate(current_theme())
        return 0
    if len(argv) == 2 and argv[0] == "--window-buttons" and argv[1] in ("on", "off"):
        SETTINGS_OVERRIDE.update(windowButtons=argv[1] == "on")
        apply_window_buttons(generate(current_theme())["strings"])
        return 0
    if argv and argv[0] == "--current":
        print(current_theme())
        return 0

    name = argv[0] if argv else current_theme()
    if name not in available_themes():
        print(f"Unknown theme '{name}'. Available: {', '.join(available_themes())}", file=sys.stderr)
        return 1

    colors_file = CURRENT_DIR / "colors.sh"
    before = colors_file.read_text() if colors_file.exists() else ""
    try:
        theme = generate(name)
    except (ValueError, KeyError, tomllib.TOMLDecodeError) as e:
        print(f"theme-set: {e}", file=sys.stderr)
        notify(f"Failed to apply {name}: {e}")
        return 1

    reload_apps(theme)
    follow_wallpaper(theme)
    # The boot screens only change when their installers run: offer it after a real change
    if colors_file.read_text() != before:
        offer_boot_update()
    if argv:
        notify(f"Switched to {theme['strings']['theme_name']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
