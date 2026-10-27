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
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

HOME = Path.home()
THEME_DIR = HOME / ".config/theme"
THEMES_DIR = THEME_DIR / "themes"
TEMPLATES_DIR = THEME_DIR / "templates"
CURRENT_DIR = THEME_DIR / "current"
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
    "tmux.conf": HOME / ".tmux/plugins/catppuccin/tmux/themes/catppuccin_current_tmux.conf",
    "cliamp.toml": HOME / ".config/cliamp/themes/system.toml",
}
# Written only when the app's folder exists (don't create a half plugin dir)
ONLY_IF_PRESENT = {"tmux.conf", "cliamp.toml"}

STARSHIP_SOURCE = HOME / ".config/starship/base.toml"
STARSHIP_OUTPUT = HOME / ".config/starship.toml"

SLOTS = (
    "rosewater flamingo pink mauve red maroon peach yellow green teal sky "
    "sapphire blue lavender text subtext1 subtext0 overlay2 overlay1 overlay0 "
    "surface2 surface1 surface0 base mantle crust"
).split()
ROLES = {"accent": "peach", "accent2": "blue"}

HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
PLACEHOLDER_RE = re.compile(r"\{\{\s*([\w.]+)\s*\}\}")


def notify(body: str) -> None:
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Theme", "Theme", body], check=False)


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


def load_theme(name: str) -> dict:
    path = THEMES_DIR / name / "colors.toml"
    with path.open("rb") as f:
        data = tomllib.load(f)

    raw = data.get("colors", {})
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

    strings = {
        "theme": name,
        "theme_name": data.get("name", name),
        "mode": mode,
    }
    for key, value in data.get("apps", {}).items():
        strings[key] = str(value)

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


def render_starship(theme: dict) -> None:
    """starship has no includes: ~/.config/starship.toml is generated from
    ~/.config/starship/base.toml plus the palette (starship rereads it every prompt)."""
    if not STARSHIP_SOURCE.exists():
        return
    base = re.sub(r"^palette\s*=.*$", "palette = 'theme'", STARSHIP_SOURCE.read_text(), count=1, flags=re.M)
    palette = "\n# Generated by theme-set\n[palettes.theme]\n" + "".join(
        f'{slot} = "{theme["colors"][slot]}"\n' for slot in [*SLOTS, *ROLES]
    )
    header = "# Generated by theme-set.py from ~/.config/starship/base.toml; edit that file\n"
    write_if_changed(STARSHIP_OUTPUT, header + base.rstrip() + "\n" + palette)


def render_quickshell(theme: dict) -> None:
    data = {
        "theme": theme["strings"]["theme"],
        "name": theme["strings"]["theme_name"],
        "mode": theme["strings"]["mode"],
        "colors": {k: v for k, v in theme["colors"].items() if not k.startswith("term_")},
    }
    write_if_changed(CURRENT_DIR / "quickshell.json", json.dumps(data, indent=2) + "\n")


def generate(name: str) -> dict:
    theme = load_theme(name)
    theme["changed"] = set()
    for tpl in sorted(TEMPLATES_DIR.glob("*.tpl")):
        out_name = tpl.name.removesuffix(".tpl")
        content = render(tpl.read_text(), theme, tpl.name)
        write_if_changed(CURRENT_DIR / out_name, content)
        if out_name in EXTRA_DESTINATIONS:
            if out_name in ONLY_IF_PRESENT and not EXTRA_DESTINATIONS[out_name].parent.parent.is_dir():
                continue
            try:
                if write_if_changed(EXTRA_DESTINATIONS[out_name], content):
                    theme["changed"].add(out_name)
            except OSError as e:
                print(f"theme-set: could not write {EXTRA_DESTINATIONS[out_name]}: {e}", file=sys.stderr)

    render_quickshell(theme)
    render_starship(theme)

    # A theme may ship its own file for any app (e.g. a hand-tuned btop.theme);
    # it replaces the rendered one.
    for override in theme["dir"].iterdir():
        if override.name != "colors.toml" and override.is_file():
            write_if_changed(CURRENT_DIR / override.name, override.read_text())

    write_if_changed(STATE_FILE, name + "\n")
    return theme


def hypr_running() -> bool:
    return bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")) and shutil.which("hyprctl") is not None


def reload_apps(theme: dict) -> None:
    colors, strings = theme["colors"], theme["strings"]

    # quickshell and neovim watch their generated files; poke quickshell anyway
    # in case the watch was lost when the file was replaced
    run_quiet(["qs", "ipc", "call", "theme", "reload"])

    if hypr_running():
        gamemode = Path("/tmp/hypr-gamemode").exists()
        alpha = ("", "") if gamemode else ("ee", "aa")
        fn = "rgb" if gamemode else "rgba"
        active = f"{fn}({colors['accent'][1:]}{alpha[0]})"
        inactive = f"{fn}({colors['accent2'][1:]}{alpha[1]})"
        run_quiet([
            "hyprctl", "eval",
            f"hl.config({{ general = {{ col = {{ active_border = '{active}', inactive_border = '{inactive}' }} }} }})",
        ])

    run_quiet(["pkill", "-USR1", "-x", "kitty"])
    run_quiet(["pkill", "-USR2", "-x", "btop"])
    run_quiet(["pkill", "-USR2", "-x", "cava"])  # reload colors
    # bat reads themes from a cache that must be rebuilt
    if "bat.tmTheme" in theme.get("changed", ()) and shutil.which("bat"):
        run_quiet(["bat", "cache", "--build"])
    if shutil.which("tmux") and subprocess.run(["tmux", "info"], capture_output=True).returncode == 0:
        run_quiet(["tmux", "source-file", str(HOME / ".tmux.conf")])
    # a running cliamp re-reads the theme file when told to switch to it
    if "cliamp.toml" in theme.get("changed", ()) and shutil.which("cliamp") and (HOME / ".config/cliamp/cliamp.sock").exists():
        run_quiet(["cliamp", "theme", "system"])

    browsers(colors["base"])

    scheme = "prefer-light" if strings["mode"] == "light" else "prefer-dark"
    run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme])

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
        })
    return json.dumps(result)


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    if argv and argv[0] == "--list":
        print("\n".join(available_themes()))
        return 0
    if argv and argv[0] == "--json":
        print(themes_json())
        return 0
    if argv and argv[0] == "--current":
        print(current_theme())
        return 0

    name = argv[0] if argv else current_theme()
    if name not in available_themes():
        print(f"Unknown theme '{name}'. Available: {', '.join(available_themes())}", file=sys.stderr)
        return 1

    try:
        theme = generate(name)
    except (ValueError, KeyError, tomllib.TOMLDecodeError) as e:
        print(f"theme-set: {e}", file=sys.stderr)
        notify(f"Failed to apply {name}: {e}")
        return 1

    reload_apps(theme)
    if argv:
        notify(f"Switched to {theme['strings']['theme_name']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
