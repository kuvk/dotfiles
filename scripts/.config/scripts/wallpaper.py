#!/usr/bin/env python3
"""Wallpapers and live (video) wallpapers, used by the Quickshell carousel.

Static wallpapers live in ~/Pictures/Wallpapers and are shown with hyprpaper.
Live wallpapers live in ~/Pictures/WallpapersLive and play with mpvpaper, one
process per monitor. The static choice is restored at login; live wallpapers
last until logout.

  wallpaper.py list static|live          JSON list for the picker
  wallpaper.py thumbs static|live        create missing thumbnails
  wallpaper.py set static|live PATH [MONITOR]   apply (all monitors if none)
  wallpaper.py stop [MONITOR]            stop live wallpapers
  wallpaper.py pause                     pause/resume live wallpapers
  wallpaper.py export-greeter            copy the wallpaper for the login screen
  wallpaper.py restore                   re-apply the saved static wallpapers (autostart)
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import time
import traceback
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HOME = Path.home()
DIRS = {
    "static": HOME / "Pictures/Wallpapers",
    "live": HOME / "Pictures/WallpapersLive",
}
EXTS = {
    "static": {".jpg", ".jpeg", ".png", ".webp"},
    "live": {".mp4", ".webm", ".mkv", ".mov"},
}
# convert-live-wallpapers.py keeps its originals here; don't list them
SKIP_DIRS = {"source"}

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "wallpaper"
STATE_FILE = STATE_DIR / "state.json"
GREETER_DIR = Path("/var/lib/kuvk-shell")  # only exists after sddm/install.sh
CURRENT_LINK = STATE_DIR / "current"  # hyprpaper.conf points here
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "wallpaper-thumbs"
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "wallpaper"

THUMB_W, THUMB_H = 1024, 640

# Light on resources: hardware decoding, no audio, no filters (a filter like
# fps=30 forces frames back to the CPU), crop to fill instead of stretching.
MPV_OPTIONS = [
    "no-audio",
    "loop",
    "hwdec=auto-safe",
    "vo=gpu-next",
    "panscan=1.0",
    "keepaspect=yes",
    "no-input-default-bindings",
    "msg-level=all=error",
]


def run(cmd: list[str]) -> str:
    out = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return out.stdout


def monitors() -> list[str]:
    try:
        return [m["name"] for m in json.loads(run(["hyprctl", "-j", "monitors"]) or "[]")]
    except (json.JSONDecodeError, KeyError, TypeError):
        return []


def load_state() -> dict:
    try:
        state = json.loads(STATE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        state = {}
    state.setdefault("static", {})
    state.setdefault("live", {})
    return state


def save_state(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2) + "\n")
    tmp.replace(STATE_FILE)


# ---------------------------------------------------------------- listing


def collect(kind: str) -> list[Path]:
    root = DIRS[kind]
    if not root.is_dir():
        return []
    files = []
    for p in root.rglob("*"):
        if p.is_file() and p.suffix.lower() in EXTS[kind] and not SKIP_DIRS & set(p.relative_to(root).parts[:-1]):
            files.append(p)
    return sorted(files, key=lambda p: p.name.lower())


def thumb_path(kind: str, src: Path) -> Path:
    key = hashlib.sha1(f"{src}|{int(src.stat().st_mtime)}".encode()).hexdigest()
    return CACHE_DIR / kind / f"{key}.jpg"


def make_thumb(kind: str, src: Path) -> None:
    dst = thumb_path(kind, src)
    if dst.exists():
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_suffix(".tmp.jpg")
    if kind == "static":
        magick = shutil.which("magick") or shutil.which("convert")
        if not magick:
            return
        cmd = [magick, f"{src}[0]", "-auto-orient", "-thumbnail", f"{THUMB_W}x{THUMB_H}^",
               "-gravity", "center", "-extent", f"{THUMB_W}x{THUMB_H}", "-quality", "85", str(tmp)]
    else:
        if not shutil.which("ffmpeg"):
            return
        cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "2", "-i", str(src),
               "-frames:v", "1", "-vf",
               f"scale={THUMB_W}:{THUMB_H}:force_original_aspect_ratio=increase,crop={THUMB_W}:{THUMB_H}",
               str(tmp)]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if kind == "live" and not tmp.exists():
        # shorter than 2 s: take the first frame
        cmd[cmd.index("-ss") + 1] = "0"
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if tmp.exists():
        tmp.replace(dst)


def list_json(kind: str) -> str:
    state = load_state()
    active = set(state[kind].values())
    items = []
    for p in collect(kind):
        try:
            t = thumb_path(kind, p)
        except OSError:
            continue  # vanished or unreadable meanwhile: skip it, list the rest
        items.append({
            "path": str(p),
            "name": p.stem.replace("_", " ").replace("-", " "),
            "thumb": str(t) if t.exists() else "",
            "current": str(p) in active,
        })
    return json.dumps(items)


def thumbs(kind: str) -> None:
    files = []
    for p in collect(kind):
        try:
            if not thumb_path(kind, p).exists():
                files.append(p)
        except OSError:
            pass
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        list(pool.map(lambda p: make_thumb(kind, p), files))


# ---------------------------------------------------------------- static


def set_static(path: Path, monitor: str | None) -> None:
    targets = [monitor] if monitor else monitors()
    for mon in targets:
        stop_live(mon, forget=True)
        run(["hyprctl", "hyprpaper", "wallpaper", f"{mon},{path},cover"])
    state = load_state()
    if monitor:
        state["static"][monitor] = str(path)
    else:
        state["static"] = {"*": str(path)}
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        CURRENT_LINK.unlink(missing_ok=True)
        CURRENT_LINK.symlink_to(path)
        export_greeter()
    save_state(state)


def export_greeter() -> None:
    """The login screen can't read your home folder, so it gets its own copy."""
    if not GREETER_DIR.is_dir() or not CURRENT_LINK.exists():
        return
    tmp = GREETER_DIR / "wallpaper.tmp"
    try:
        shutil.copyfile(CURRENT_LINK, tmp)
        tmp.replace(GREETER_DIR / "wallpaper")
    except OSError as e:
        print(f"wallpaper: could not copy for the login screen: {e}", file=sys.stderr)


# ---------------------------------------------------------------- live


def pid_file(mon: str) -> Path:
    return RUNTIME_DIR / f"mpvpaper-{mon}.pid"


def socket_file(mon: str) -> Path:
    return RUNTIME_DIR / f"mpv-{mon}.sock"


def stop_live(mon: str, *, forget: bool) -> None:
    pf = pid_file(mon)
    try:
        os.kill(int(pf.read_text()), signal.SIGTERM)
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        pass
    pf.unlink(missing_ok=True)
    socket_file(mon).unlink(missing_ok=True)
    if forget:
        state = load_state()
        if state["live"].pop(mon, None) is not None:
            save_state(state)


def start_live(mon: str, path: Path) -> None:
    if not shutil.which("mpvpaper"):
        notify("mpvpaper is not installed")
        return
    stop_live(mon, forget=False)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    options = " ".join([*MPV_OPTIONS, f"input-ipc-server={socket_file(mon)}"])
    # -p: pause while covered by windows
    proc = subprocess.Popen(
        ["mpvpaper", "-p", "-o", options, mon, str(path)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
    )
    pid_file(mon).write_text(str(proc.pid))


def set_live(path: Path, monitor: str | None) -> None:
    targets = [monitor] if monitor else monitors()
    state = load_state()
    if not monitor:
        state["live"] = {}
    for mon in targets:
        start_live(mon, path)
        state["live"][mon] = str(path)
    save_state(state)


def stop(monitor: str | None) -> None:
    targets = [monitor] if monitor else [p.name[len("mpvpaper-"):-len(".pid")] for p in RUNTIME_DIR.glob("mpvpaper-*.pid")]
    for mon in targets:
        stop_live(mon, forget=True)
    if not monitor:
        state = load_state()
        state["live"] = {}
        save_state(state)
    # anything started outside this script
    if not monitor and shutil.which("pkill"):
        run(["pkill", "-x", "mpvpaper"])


def mpv_command(mon: str, command: list) -> dict | None:
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(1)
            s.connect(str(socket_file(mon)))
            s.sendall((json.dumps({"command": command}) + "\n").encode())
            return json.loads(s.recv(4096).decode().splitlines()[0])
    except (OSError, ValueError, IndexError):
        return None


def pause() -> None:
    mons = [p.name[len("mpv-"):-len(".sock")] for p in RUNTIME_DIR.glob("mpv-*.sock")]
    if not mons:
        notify("No live wallpaper is running")
        return
    for mon in mons:
        mpv_command(mon, ["cycle", "pause"])
    reply = mpv_command(mons[0], ["get_property", "pause"])
    notify("Live wallpapers paused" if reply and reply.get("data") else "Live wallpapers resumed")


def restore() -> None:
    """Static wallpapers survive a reboot; live ones don't, so forget them."""
    state = load_state()
    static = state["static"]
    for mon in monitors():
        path = static.get(mon) or static.get("*")
        if path and Path(path).exists():
            run(["hyprctl", "hyprpaper", "wallpaper", f"{mon},{path},cover"])
    if state["live"]:
        state["live"] = {}
        save_state(state)


def notify(body: str) -> None:
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Wallpapers", "-i", "preferences-desktop-wallpaper", body], check=False)


# ---------------------------------------------------------------- debugging

DEBUG_LOG = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "wallpaper-debug.log"


VERBOSE = bool(os.environ.get("WALLPAPER_DEBUG"))


def debug(message: str, *, always: bool = False) -> None:
    """Append a line to ~/.cache/wallpaper-debug.log (last 2000 lines kept).
    Errors are always logged; every call only with WALLPAPER_DEBUG=1."""
    if not (always or VERBOSE):
        return
    try:
        DEBUG_LOG.parent.mkdir(parents=True, exist_ok=True)
        line = f"{time.strftime('%H:%M:%S')}.{int(time.time() * 1000) % 1000:03d} [{os.getpid()}<{os.getppid()}] {message}\n"
        with DEBUG_LOG.open("a") as f:
            f.write(line)
        if DEBUG_LOG.stat().st_size > 400_000:
            lines = DEBUG_LOG.read_text().splitlines(keepends=True)[-2000:]
            DEBUG_LOG.write_text("".join(lines))
    except OSError:
        pass


def main(argv: list[str]) -> int:
    start = time.monotonic()
    debug(f"start argv={argv!r} cwd={os.getcwd()!r} python={sys.executable}")
    try:
        code = run_command(argv)
    except BaseException as e:  # noqa: BLE001 - log everything, then re-raise
        debug(f"EXCEPTION argv={argv!r} after {time.monotonic() - start:.3f}s: {e!r}\n{traceback.format_exc()}", always=True)
        raise
    debug(f"exit {code} after {time.monotonic() - start:.3f}s")
    return code


def run_command(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    cmd, args = argv[0], argv[1:]
    if cmd == "list" and args and args[0] in DIRS:
        out = list_json(args[0])
        debug(f"list {args[0]}: {len(json.loads(out))} items from {DIRS[args[0]]} (exists={DIRS[args[0]].is_dir()}), {len(out)} bytes")
        print(out, flush=True)
    elif cmd == "export-greeter":
        export_greeter()
    elif cmd == "thumbs" and args and args[0] in DIRS:
        thumbs(args[0])
    elif cmd == "set" and len(args) >= 2 and args[0] in DIRS:
        path = Path(args[1]).expanduser()
        if not path.exists():
            print(f"{path} does not exist", file=sys.stderr)
            return 1
        monitor = args[2] if len(args) > 2 else None
        (set_static if args[0] == "static" else set_live)(path, monitor)
    elif cmd == "stop":
        stop(args[0] if args else None)
    elif cmd == "pause":
        pause()
    elif cmd == "restore":
        restore()
    else:
        debug(f"unknown command {argv!r}: printing usage, exit 1", always=True)
        print(__doc__.strip(), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
