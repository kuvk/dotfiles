#!/usr/bin/env python3
"""Wallpapers and live (video) wallpapers, used by the Quickshell carousel, and the lock
screen's background.

Static wallpapers live in ~/.local/share/dotfiles/backgrounds/default (the themes' own
backgrounds too, drawn by theme-set.py) and are shown with hyprpaper. Live wallpapers live
in ~/.local/share/dotfiles/backgrounds/live and play with mpvpaper, one process per
monitor. More folders for either go in ~/.config/dotfiles/backgrounds.json:
  {"static": ["~/Pictures/Wallpapers"], "live": ["~/Videos/Wallpapers"]}
(created with empty lists if missing). The static choice is restored at login; live
wallpapers last until logout.

  wallpaper.py list static|live          JSON list for the picker
  wallpaper.py thumbs static|live        create missing thumbnails
  wallpaper.py set static|live PATH [MONITOR]   apply (all monitors if none)
  wallpaper.py stop [MONITOR]            stop live wallpapers
  wallpaper.py pause [on|off]            pause/resume live wallpapers (toggles without on|off)
  wallpaper.py lock PATH                 the lock screen's background: a copy small enough
                                         to load at once (PATH itself if it is), also for the
                                         login screen; prints it and a stamp, tab-separated
  wallpaper.py export-greeter            copy the lock screen's background for the login screen
  wallpaper.py default [PATH]            first run: PATH (or the theme's background), unless one is chosen
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
BACKGROUNDS = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "dotfiles/backgrounds"
DIRS = {
    "static": BACKGROUNDS / "default",
    "live": BACKGROUNDS / "live",
}
# More folders to list, per kind (edited by hand)
EXTRA_DIRS_FILE = HOME / ".config/dotfiles/backgrounds.json"
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
# The lock screen's background, ready to load (see prepare_lock), and what it was made from
LOCK_IMAGE = STATE_DIR / "lock.jpg"
LOCK_INFO = STATE_DIR / "lock.json"
# Shipped with the dotfiles (theme package); used until another is picked
# the theme's background, drawn by theme-set.py (theme_background)
THEME_JSON = HOME / ".config/theme/current/quickshell.json"
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


def ensure_dirs() -> None:
    """The backgrounds folders, and the extra folders file with empty lists, if missing."""
    for d in DIRS.values():
        d.mkdir(parents=True, exist_ok=True)
    if not EXTRA_DIRS_FILE.exists():
        EXTRA_DIRS_FILE.parent.mkdir(parents=True, exist_ok=True)
        EXTRA_DIRS_FILE.write_text(json.dumps({"static": [], "live": []}, indent=2) + "\n")


def roots(kind: str) -> list[Path]:
    """The folders to list: the backgrounds one, then those in backgrounds.json."""
    out = [DIRS[kind]]
    try:
        extra = json.loads(EXTRA_DIRS_FILE.read_text()).get(kind, [])
    except (OSError, json.JSONDecodeError, AttributeError):
        extra = []
    for entry in extra if isinstance(extra, list) else []:
        if isinstance(entry, str) and entry.strip():
            d = Path(os.path.expandvars(entry.strip())).expanduser()
            if d not in out:
                out.append(d)
    return out


def collect(kind: str) -> list[Path]:
    files, seen = [], set()
    for root in roots(kind):
        if not root.is_dir():
            continue
        for p in root.rglob("*"):
            if p.is_file() and p.suffix.lower() in EXTS[kind] and not SKIP_DIRS & set(p.relative_to(root).parts[:-1]):
                if p not in seen:
                    seen.add(p)
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
    save_state(state)


def largest_screen() -> tuple[int, int]:
    """The largest width and height among the monitors, in pixels (2560x1440 without any)."""
    try:
        mons = json.loads(run(["hyprctl", "-j", "monitors"]) or "[]")
        sizes = [(int(m["width"]), int(m["height"])) for m in mons if m.get("width")]
    except (json.JSONDecodeError, KeyError, TypeError, ValueError):
        sizes = []
    if not sizes:
        return 2560, 1440
    return max(w for w, _ in sizes), max(h for _, h in sizes)


def image_size(path: Path) -> tuple[int, int] | None:
    magick = shutil.which("magick")
    cmd = [magick, "identify"] if magick else [shutil.which("identify") or "identify"]
    out = run([*cmd, "-format", "%w %h", f"{path}[0]"]).split()
    return (int(out[0]), int(out[1])) if len(out) == 2 and all(o.isdigit() for o in out) else None


def prepare_lock(src: Path) -> Path | None:
    """The lock screen's background, ready to load at once: SRC itself when it's light (a
    flat picture like the themes' logo backgrounds, or one no bigger than the largest
    screen), else a JPEG copy scaled to cover the largest screen (a large wallpaper took a
    moment to decode at every lock).
    Made again only when SRC or the screens change. The login screen gets the same file."""
    try:
        st = src.stat()
    except OSError:
        return None
    width, height = largest_screen()
    made_from = {"source": str(src), "mtime": int(st.st_mtime), "size": st.st_size, "screen": [width, height]}
    try:
        info = json.loads(LOCK_INFO.read_text())
    except (OSError, json.JSONDecodeError):
        info = {}
    out = Path(info.get("image", ""))
    if info.get("from") == made_from and out.is_file():
        return out
    dims = image_size(src)
    fits = dims and dims[0] <= width * 1.25 and dims[1] <= height * 1.25
    if st.st_size <= 1_000_000 or (fits and st.st_size <= 4_000_000):
        out = src
    else:
        magick = shutil.which("magick") or shutil.which("convert")
        if not magick:
            return src
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        tmp = LOCK_IMAGE.with_suffix(".tmp.jpg")
        subprocess.run([magick, f"{src}[0]", "-auto-orient", "-resize", f"{width}x{height}^",
                        "-quality", "90", str(tmp)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not tmp.exists():
            return src
        tmp.replace(LOCK_IMAGE)
        out = LOCK_IMAGE
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    LOCK_INFO.write_text(json.dumps({"from": made_from, "image": str(out)}) + "\n")
    export_greeter()
    return out


def export_greeter() -> None:
    """The login screen can't read the home folder, so it gets its own copy of the lock
    screen's background."""
    try:
        image = Path(json.loads(LOCK_INFO.read_text()).get("image", ""))
    except (OSError, json.JSONDecodeError):
        return
    if not GREETER_DIR.is_dir() or not image.is_file():
        return
    tmp = GREETER_DIR / "wallpaper.tmp"
    try:
        shutil.copyfile(image, tmp)
        tmp.replace(GREETER_DIR / "wallpaper")
    except OSError as e:
        print(f"wallpaper: could not copy for the login screen: {e}", file=sys.stderr)


def theme_background() -> Path | None:
    try:
        path = Path(json.loads(THEME_JSON.read_text()).get("background") or "")
    except (OSError, json.JSONDecodeError):
        return None
    return path if path.is_file() else None


def use_default(path: Path | None = None) -> None:
    """The backgrounds folders (and backgrounds.json) if missing, and with no wallpaper
    chosen yet (a fresh install) PATH, or else the theme's background, for every monitor;
    also the lock and login screens' background. Works before Hyprland runs."""
    ensure_dirs()
    source = path if path and path.is_file() else theme_background()
    if source is None:
        return
    if not CURRENT_LINK.exists():
        dest = source if source.parent == DIRS["static"] else DIRS["static"] / source.name
        if not dest.exists():
            shutil.copyfile(source, dest)
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        CURRENT_LINK.unlink(missing_ok=True)
        CURRENT_LINK.symlink_to(dest)
        state = load_state()
        state["static"] = {"*": str(dest)}
        save_state(state)
    # the lock and login screens' background until the shell sets its own (services/Lock.qml)
    if not LOCK_INFO.exists():
        prepare_lock(source)


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


def pause(state: str | None = None) -> None:
    mons = [p.name[len("mpv-"):-len(".sock")] for p in RUNTIME_DIR.glob("mpv-*.sock")]
    if not mons:
        if state is None:
            notify("No live wallpaper is running")
        return
    for mon in mons:
        if state is None:
            mpv_command(mon, ["cycle", "pause"])
        else:
            mpv_command(mon, ["set_property", "pause", state == "on"])
    if state is not None:
        return  # Work-Game says so itself
    reply = mpv_command(mons[0], ["get_property", "pause"])
    notify("Live wallpapers paused" if reply and reply.get("data") else "Live wallpapers resumed")


def restore() -> None:
    """Static wallpapers survive a reboot; live ones don't, so forget them."""
    use_default()
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
        ensure_dirs()
        out = list_json(args[0])
        debug(f"list {args[0]}: {len(json.loads(out))} items from {DIRS[args[0]]} (exists={DIRS[args[0]].is_dir()}), {len(out)} bytes")
        print(out, flush=True)
    elif cmd == "lock" and args:
        out = prepare_lock(Path(args[0]).expanduser())
        if out is None:
            return 1
        st = out.stat()
        print(f"{out}\t{st.st_ino}-{int(st.st_mtime)}-{st.st_size}", flush=True)
    elif cmd == "export-greeter":
        export_greeter()
    elif cmd == "default":
        use_default(Path(args[0]).expanduser() if args else None)
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
        pause(args[0] if args and args[0] in ("on", "off") else None)
    elif cmd == "restore":
        restore()
    else:
        debug(f"unknown command {argv!r}: printing usage, exit 1", always=True)
        print(__doc__.strip(), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
