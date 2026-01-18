#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path

HOME = Path(os.path.expanduser("~"))

SRC_DIR = Path(os.environ.get("LIVE_WALLPAPER_SRC", str(HOME / "wallpapers" / "live"))).expanduser()
OUT_DIR = Path(os.environ.get("LIVE_WALLPAPER_OUT", str(HOME / "wallpapers" / "live_1440p"))).expanduser()

# Target: "2K-ish". This uses width 2560 and keeps aspect ratio.
# If you want exact 2560x1440 crop-fill, say so.
TARGET_W = int(os.environ.get("TARGET_W", "2560"))
TARGET_FPS = int(os.environ.get("TARGET_FPS", "30"))

# Encoding settings (good quality / reasonable size)
# If you prefer HEVC to reduce file size, we can switch to libx265.
CRF = os.environ.get("CRF", "20")
PRESET = os.environ.get("PRESET", "veryfast")

EXTS = {".mp4", ".webm", ".mkv", ".mov"}

def convert_one(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)

    # Scale to TARGET_W, preserve aspect ratio. Enforce even height (required by many encoders).
    vf = f"scale={TARGET_W}:-2,fps={TARGET_FPS}"

    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(src),
        "-an",
        "-vf",
        vf,
        "-c:v",
        "libx264",
        "-preset",
        PRESET,
        "-crf",
        CRF,
        "-pix_fmt",
        "yuv420p",
        str(dst.with_suffix(".mp4")),
    ]
    subprocess.run(cmd, check=False)

def main() -> int:
    if not SRC_DIR.exists():
        print(f"Source dir does not exist: {SRC_DIR}")
        return 1

    videos = [p for p in SRC_DIR.rglob("*") if p.is_file() and p.suffix.lower() in EXTS]
    videos.sort()

    if not videos:
        print(f"No videos found in: {SRC_DIR}")
        return 0

    for src in videos:
        rel = src.relative_to(SRC_DIR)
        out = OUT_DIR / rel
        print(f"Converting: {rel}")
        convert_one(src, out)

    print(f"Done. Output in: {OUT_DIR}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
