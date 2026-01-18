#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

HOME = os.path.expanduser("~")

# --- CONFIG ---
WALLPAPER_DIR = os.path.join(HOME, "wallpapers")
THUMB_DIR = os.path.join(HOME, ".cache/wallpaper-thumbs")
ROFI_THEME_GRID = os.path.join(HOME, ".config/rofi/wallpapers.rasi")
ROFI_THEME_LIST = os.path.join(HOME, ".config/rofi/monitors.rasi")

THUMB_W, THUMB_H = 512, 288  # 16:9

US = "\x1f"
NUL = "\x00"


@dataclass(frozen=True)
class Config:
    wallpaper_dir: Path
    thumb_dir: Path
    rofi_theme_grid: Path
    rofi_theme_list: Path
    thumb_w: int = 512
    thumb_h: int = 288


CFG = Config(
    wallpaper_dir=Path(WALLPAPER_DIR),
    thumb_dir=Path(THUMB_DIR),
    rofi_theme_grid=Path(ROFI_THEME_GRID),
    rofi_theme_list=Path(ROFI_THEME_LIST),
    thumb_w=THUMB_W,
    thumb_h=THUMB_H,
)


def run(
    cmd: list[str],
    check: bool = True,
    capture: bool = False,
    input_bytes: bytes | None = None,
) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        check=check,
        input=input_bytes,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def notify(title: str, body: str) -> None:
    try:
        run(["notify-send", title, body], check=False)
    except Exception:
        pass


def truncate(name: str, maxlen: int = 30) -> str:
    return (name[: maxlen - 2] + "..") if len(name) > maxlen else name


def collect_wallpapers(cfg: Config) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png"}
    files: list[Path] = []
    if not cfg.wallpaper_dir.exists():
        return files
    for p in sorted(cfg.wallpaper_dir.rglob("*")):
        if p.is_file() and p.suffix.lower() in exts:
            files.append(p)
    return files


def thumb_path(cfg: Config, src: Path) -> Path:
    key = hashlib.sha1(str(src).encode("utf-8")).hexdigest()
    return cfg.thumb_dir / f"{key}.png"


def ensure_thumb(cfg: Config, src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)

    regen = True
    try:
        regen = src.stat().st_mtime > dst.stat().st_mtime
    except FileNotFoundError:
        regen = True

    if not regen:
        return

    run(
        [
            "magick",
            str(src),
            "-auto-orient",
            "-thumbnail",
            f"{cfg.thumb_w}x{cfg.thumb_h}^",
            "-gravity",
            "center",
            "-background",
            "none",
            "-extent",
            f"{cfg.thumb_w}x{cfg.thumb_h}",
            str(dst),
        ],
        check=False,
    )


def rofi_select_index(lines_bytes: bytes, theme: Path, prompt: str) -> int | None:
    p = subprocess.run(
        [
            "rofi",
            "-dmenu",
            "-i",
            "-show-icons",
            "-p",
            prompt,
            "-format",
            "i",
            "-theme",
            str(theme),
        ],
        input=lines_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if p.returncode != 0:
        return None
    out = p.stdout.decode("utf-8", errors="replace").strip()
    if not out:
        return None
    try:
        return int(out)
    except ValueError:
        return None


def rofi_select_text(options: list[str], theme: Path, prompt: str) -> str | None:
    data = ("\n".join(options)).encode("utf-8", "surrogateescape")
    p = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", prompt, "-theme", str(theme)],
        input=data,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if p.returncode != 0:
        return None
    out = p.stdout.decode("utf-8", errors="replace").strip()
    return out or None


def get_active_monitors() -> list[str]:
    p = subprocess.run(
        ["hyprctl", "monitors", "-j"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
    if p.returncode != 0:
        return []
    try:
        data = json.loads(p.stdout.decode("utf-8", errors="replace"))
    except Exception:
        return []

    if not isinstance(data, list):
        return []

    mons: list[str] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        name = item.get("name")
        if isinstance(name, str) and name:
            mons.append(name)

    return sorted(mons)


def set_wallpaper(monitor: str, file_path: Path) -> None:
    run(
        ["hyprctl", "hyprpaper", "wallpaper", f"{monitor},{str(file_path)},cover"],
        check=False,
    )


def main(cfg: Config) -> int:
    files = collect_wallpapers(cfg)
    if not files:
        notify("Wallpapers", f"No wallpapers found in {cfg.wallpaper_dir}")
        return 0

    lines: list[str] = []
    for f in files:
        tp = thumb_path(cfg, f)
        ensure_thumb(cfg, f, tp)
        label = truncate(f.name)
        lines.append(label + NUL + "icon" + US + str(tp))

    lines_bytes = ("\n".join(lines)).encode("utf-8", "surrogateescape")

    idx = rofi_select_index(lines_bytes, cfg.rofi_theme_grid, "󰸉")
    if idx is None:
        return 0
    if idx < 0 or idx >= len(files):
        notify("Wallpapers", "Invalid selection.")
        return 1

    selected_file = files[idx]
    selected_name = selected_file.name

    monitors = get_active_monitors()
    if not monitors:
        notify("Wallpapers", "No active monitors found (hyprctl monitors -j failed).")
        return 1

    if len(monitors) == 1:
        mon = monitors[0]
        set_wallpaper(mon, selected_file)
        notify("Wallpapers", f'Wallpaper "{selected_name}" set on {mon}')
        return 0

    choice = rofi_select_text(["ALL"] + monitors, cfg.rofi_theme_list, "󰍺")
    if not choice:
        return 0

    if choice == "ALL":
        for mon in monitors:
            set_wallpaper(mon, selected_file)
        notify("Wallpapers", f'Wallpaper "{selected_name}" set on ALL monitors')
    else:
        set_wallpaper(choice, selected_file)
        notify("Wallpapers", f'Wallpaper "{selected_name}" set on {choice}')

    return 0


if __name__ == "__main__":
    raise SystemExit(main(CFG))
