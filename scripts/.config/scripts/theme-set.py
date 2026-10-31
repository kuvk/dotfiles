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
  theme-set.py --shape rounded|square
                          corners of the status lines in tmux, nvim, yazi and Claude
                          Code (quickshell sets it: square in Work-Game or at radius 0)
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
    # catppuccin/tmux may be installed twice: cloned by hand to
    # plugins/catppuccin/tmux and by TPM to plugins/tmux. Every copy that is
    # there gets the flavor, or the one loaded last keeps the old colors.
    "tmux.conf": [
        HOME / ".tmux/plugins/catppuccin/tmux/themes/catppuccin_current_tmux.conf",
        HOME / ".tmux/plugins/tmux/themes/catppuccin_current_tmux.conf",
    ],
    "cliamp.toml": HOME / ".config/cliamp/themes/system.toml",
    "herdr-config.toml": HOME / ".config/herdr/config.toml",
    # GTK adds these to whatever theme is set (also replaces an old symlink here)
    "gtk.css": [HOME / ".config/gtk-3.0/gtk.css", HOME / ".config/gtk-4.0/gtk.css"],
    "gtk-settings.ini": [HOME / ".config/gtk-3.0/settings.ini", HOME / ".config/gtk-4.0/settings.ini"],
    "qt5ct.conf": HOME / ".config/qt5ct/qt5ct.conf",
    "qt6ct.conf": HOME / ".config/qt6ct/qt6ct.conf",
    "kvantum.kvconfig": HOME / ".config/Kvantum/kvantum.kvconfig",
    "kvantum-current.kvconfig": HOME / ".config/Kvantum/current/current.kvconfig",
    "kvantum-current.svg": HOME / ".config/Kvantum/current/current.svg",
    "hyprtoolkit.conf": HOME / ".config/hypr/hyprtoolkit.conf",
    "cursor-index.theme": HOME / ".icons/default/index.theme",
    # the login screen; that folder only exists after sddm/install.sh
    "sddm-theme.conf": Path("/var/lib/kuvk-shell/theme.conf"),
    "claude-theme.json": HOME / ".claude/themes/current.json",
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
ROLES = {"accent": "peach", "accent2": "blue", "selection_bg": "surface1"}
MIN_SELECTION_CONTRAST = 3.0
CURSOR_THEME = "Adwaita"

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


def shell_fonts() -> tuple[str, str]:
    """The fonts chosen in Quickshell's Settings."""
    display, nerd = "SF Pro Display", "JetBrainsMono Nerd Font"
    for path in (HOME / ".local/state/quickshell/by-shell").glob("*/settings.json"):
        try:
            settings = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        display = settings.get("displayFont", display)
        nerd = settings.get("nerdFont", nerd)
    return display, nerd


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

    strings = {
        "theme": name,
        "theme_name": data.get("name", name),
        "mode": mode,
        "cursor_theme": CURSOR_THEME,
        "display_font": shell_fonts()[0],
        "nerd_font": shell_fonts()[1],
        "icon_theme": "Papirus" if mode == "light" else "Papirus-Dark",
        "prefer_dark": "0" if mode == "light" else "1",
        # adw-gtk3, when installed, follows gtk.css in plain GTK3 and GTK4 apps too;
        # Adwaita only does in libadwaita apps
        "gtk_theme": ("adw-gtk3" if Path("/usr/share/themes/adw-gtk3").is_dir() else "Adwaita")
        + ("" if mode == "light" else "-dark"),
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
    out = subprocess.run(["dircolors", "-b", str(CURRENT_DIR / "dir_colors")], capture_output=True, text=True)
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
            if out_name == "sddm-theme.conf" and not dest.parent.is_dir():
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


def set_gtk_theme(strings: dict) -> None:
    """Wayland GTK apps read these; settings.ini (rendered above) is for XWayland ones."""
    interface = "org.gnome.desktop.interface"
    run_quiet(["gsettings", "set", interface, "gtk-theme", strings["gtk_theme"]])
    run_quiet(["gsettings", "set", interface, "icon-theme", strings["icon_theme"]])
    run_quiet(["gsettings", "set", interface, "cursor-theme", strings["cursor_theme"]])
    run_quiet(["gsettings", "set", interface, "color-scheme", f"prefer-{strings['mode']}"])


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
                "accent", "accent2", "red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink",
            )},
        })
    return json.dumps(result)


def set_shape(shape: str) -> None:
    if not write_if_changed(CURRENT_DIR / "shape", shape + "\n"):
        return
    # nvim watches the file and Claude Code's status line reads it each time
    if subprocess.run(["tmux", "info"], capture_output=True).returncode == 0:
        run_quiet(["tmux", "source-file", str(HOME / ".tmux.conf")])
    restart_yazi()


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
