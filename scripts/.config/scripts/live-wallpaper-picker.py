#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
from pathlib import Path
from typing import Optional

HOME = Path(os.path.expanduser("~"))

WALLPAPER_DIR = Path(
    os.environ.get("LIVE_WALLPAPER_DIR", str(HOME / "wallpapers" / "live_1440p"))
).expanduser()

THUMB_DIR = Path(
    os.environ.get("LIVE_THUMB_DIR", str(HOME / ".cache" / "live-wallpaper-thumbs"))
).expanduser()

ROFI_THEME_GRID = Path(
    os.environ.get(
        "ROFI_THEME_GRID", str(HOME / ".config" / "rofi" / "wallpapers.rasi")
    )
).expanduser()

ROFI_THEME_LIST = Path(
    os.environ.get("ROFI_THEME_LIST", str(HOME / ".config" / "rofi" / "monitors.rasi"))
).expanduser()

MPVPAPER_BIN = os.environ.get("MPVPAPER_BIN", "mpvpaper")

# Thumbnail size (16:9)
THUMB_W, THUMB_H = 512, 288

# Generate thumbnail from this timestamp (seconds)
THUMB_AT_SECONDS = float(os.environ.get("THUMB_AT_SECONDS", "2.0"))

US = "\x1f"
NUL = "\x00"


def run(cmd: list[str], check: bool = False) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        cmd, check=check, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )


def notify(title: str, body: str) -> None:
    subprocess.run(
        ["notify-send", title, body],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def truncate(name: str, maxlen: int = 30) -> str:
    return (name[: maxlen - 2] + "..") if len(name) > maxlen else name


def collect_videos(root: Path) -> list[Path]:
    exts = {".mp4", ".webm", ".mkv", ".mov"}
    if not root.exists():
        return []
    vids = [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in exts]
    vids.sort()
    return vids


def thumb_path(src: Path) -> Path:
    # include path + mtime in key so thumbs refresh when video changes
    st = src.stat()
    key_input = f"{src}|{int(st.st_mtime)}"
    key = hashlib.sha1(key_input.encode("utf-8")).hexdigest()
    return THUMB_DIR / f"{key}.png"


def ensure_thumb(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        return

    # 1 frame thumbnail, cropped to 16:9.
    # Uses ffmpeg. Much faster than decoding full video.
    # Notes:
    # -ss before -i is fast seek, good enough for thumb
    # force_original_aspect_ratio=increase + crop gives exact 16:9
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-ss",
        str(THUMB_AT_SECONDS),
        "-i",
        str(src),
        "-frames:v",
        "1",
        "-vf",
        (
            f"scale={THUMB_W}:{THUMB_H}:force_original_aspect_ratio=increase,"
            f"crop={THUMB_W}:{THUMB_H}"
        ),
        str(dst),
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def rofi_select_index(
    lines_bytes: bytes, theme: Path, prompt: str, placeholder: str
) -> Optional[int]:
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
            "-theme-str",
            f'entry {{ placeholder: "{placeholder}"; }}',
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


def rofi_select_text(
    options: list[str], theme: Path, prompt: str, placeholder: str
) -> Optional[str]:
    data = ("\n".join(options)).encode("utf-8", "surrogateescape")
    p = subprocess.run(
        [
            "rofi",
            "-dmenu",
            "-i",
            "-p",
            prompt,
            "-theme",
            str(theme),
            "-theme-str",
            f'entry {{ placeholder: "{placeholder}"; }}',
        ],
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
        if isinstance(item, dict):
            name = item.get("name")
            if isinstance(name, str) and name:
                mons.append(name)
    mons.sort()
    return mons


def socket_for(target: str) -> Path:
    return Path("/tmp") / f"mpv-socket-{target}"


def mpv_get_prop(sock: Path, prop: str) -> Optional[object]:
    if not sock.exists():
        return None
    req = json.dumps({"command": ["get_property", prop]})
    p = subprocess.run(
        ["socat", "-", f"UNIX-CONNECT:{str(sock)}"],
        input=(req + "\n").encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if p.returncode != 0:
        return None
    try:
        data = json.loads(p.stdout.decode("utf-8", errors="replace"))
        return data.get("data")
    except Exception:
        return None


def mpv_pid_for_target(target: str) -> Optional[int]:
    val = mpv_get_prop(socket_for(target), "pid")
    if isinstance(val, int):
        return val
    if isinstance(val, float):
        return int(val)
    return None


def running_video_for_target(target: str) -> Optional[Path]:
    val = mpv_get_prop(socket_for(target), "path")
    if isinstance(val, str) and val:
        return Path(val)
    return None


def kill_existing_mpvpaper() -> None:
    # Avoid killing other monitor wallpapers
    for sock in Path("/tmp").glob("mpv-socket-*"):
        try:
            if not sock.is_socket():
                continue
        except Exception:
            continue

        target = sock.name.replace("mpv-socket-", "", 1)
        pid = mpv_pid_for_target(target)
        if pid is not None:
            subprocess.run(
                ["kill", str(pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        try:
            if sock.exists():
                sock.unlink()
        except Exception:
            pass


def start_mpvpaper(target: str, video: Path) -> None:
    # mpv options tuned for lower overhead
    # Key: hwdec + low-cost scaling
    sock = socket_for(target)
    mpv_opts = " ".join(
        [
            "no-config",
            "no-audio",
            "loop",
            f"input-ipc-server={sock}",
            "--gpu-context=wayland",
            "--vo=gpu-next",
            "--hwdec=auto-safe",
            "--interpolation=no",
            "--scale=bilinear",
            "--cscale=bilinear",
            "--dscale=bilinear",
            "--deband=no",
            "--video-sync=audio",
            "--vf=fps=30",
            "--fullscreen",
            "--keepaspect=no",
        ]
    )

    cmd = [
        MPVPAPER_BIN,
        "-vsp",
        "-o",
        mpv_opts,
        "-p",
        target,
        str(video),
    ]
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> int:
    videos = collect_videos(WALLPAPER_DIR)
    if not videos:
        notify("Live Wallpapers", f"No videos found in {WALLPAPER_DIR}")
        return 0

    # Build rofi grid entries with thumbnails
    lines: list[str] = []
    for v in videos:
        tp = thumb_path(v)
        ensure_thumb(v, tp)
        label = truncate(v.name)
        lines.append(label + NUL + "icon" + US + str(tp))

    lines_bytes = ("\n".join(lines)).encode("utf-8", "surrogateescape")

    idx = rofi_select_index(
        lines_bytes, ROFI_THEME_GRID, "󱜅 ", "Search live wallpapers ..."
    )
    if idx is None:
        return 0
    if idx < 0 or idx >= len(videos):
        notify("Live Wallpapers", "Invalid selection.")
        return 1

    selected_video = videos[idx]

    monitors = get_active_monitors()
    if not monitors:
        notify(
            "Live Wallpapers", "No active monitors found (hyprctl monitors -j failed)."
        )
        return 1

    # If only one monitor, skip monitor picker
    if len(monitors) == 1:
        kill_existing_mpvpaper()
        start_mpvpaper(monitors[0], selected_video)
        notify("Live Wallpapers", f'Set "{selected_video.name}" on {monitors[0]}')
        return 0

    choice = rofi_select_text(
        ["ALL"] + monitors, ROFI_THEME_LIST, "󰍺 ", "Select monitor ..."
    )
    if not choice:
        return 0

    if choice == "ALL":
        kill_existing_mpvpaper()
        start_mpvpaper("ALL", selected_video)
        notify("Live Wallpapers", f'Set "{selected_video.name}" on ALL monitors')
    else:
        pid = mpv_pid_for_target(choice)
        if pid is not None:
            subprocess.run(
                ["kill", str(pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        sock = socket_for(choice)
        try:
            if sock.exists():
                sock.unlink()
        except Exception:
            pass

        start_mpvpaper(choice, selected_video)
        notify("Live Wallpapers", f'Set "{selected_video.name}" on {choice}')

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
