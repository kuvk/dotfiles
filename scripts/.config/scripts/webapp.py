#!/usr/bin/env python3
"""Web apps like Omarchy's: a site in its own browser window (no tabs, no
address bar, no extension icons) with a launcher entry and an icon, so it
shows up in the search launcher and the app menu (Internet).

  webapp.py                                  ask for name, URL and icon
  webapp.py install NAME URL [ICON]          create (or update) a web app
  webapp.py list                             installed web apps
  webapp.py remove NAME                      remove one
  webapp.py launch URL                       open URL as a web app (used by the entries)

ICON is optional: a PNG URL, a local image file, or a name from
https://dashboardicons.com (e.g. "whatsapp"). Without one, the app's name is
tried on dashboardicons.com, then the site's favicon.

For no title bar at all, turn on Brave > Settings > Appearance > "Use system
title bar and borders" (Hyprland draws none).
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

HOME = Path.home()
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
APPS_DIR = DATA / "applications"
ICON_DIR = DATA / "icons/hicolor/256x256/apps"
PREFIX = "webapp-"
SELF = Path(__file__).resolve()

DASHBOARD_ICONS = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/{}.png"
FAVICON = "https://www.google.com/s2/favicons?domain={}&sz=256"
BROWSERS = ["brave", "brave-browser", "chromium", "google-chrome-stable", "vivaldi-stable"]


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def normalize_url(url: str) -> str:
    url = url.strip()
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url):
        url = "https://" + url
    if not re.match(r"^https?://", url, re.I) or re.search(r"\s", url):
        raise SystemExit(f"Not a web address: {url}")
    return url


def browser() -> str:
    for b in BROWSERS:
        if shutil.which(b):
            return b
    raise SystemExit("Web apps need a Chromium-based browser (Brave, Chromium, Chrome)")


def download(url: str, dest: Path) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = resp.read()
    except OSError:
        return False
    # PNG, JPEG, WebP, ICO or SVG
    if not data or not (data[:8] == b"\x89PNG\r\n\x1a\n" or data[:3] == b"\xff\xd8\xff"
                        or data[8:12] == b"WEBP" or data[:4] == b"\x00\x00\x01\x00" or b"<svg" in data[:512]):
        return False
    dest.write_bytes(data)
    return True


def fetch_icon(name: str, url: str, icon: str | None) -> Path | None:
    """The icon as a 256 px PNG in the user's hicolor theme."""
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    target = ICON_DIR / f"{PREFIX}{slug(name)}.png"
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "icon"
        candidates: list[str] = []
        if icon:
            if Path(icon).expanduser().is_file():
                shutil.copy(Path(icon).expanduser(), raw)
            elif re.match(r"^https?://", icon):
                candidates.append(icon)
            else:
                candidates.append(DASHBOARD_ICONS.format(slug(icon)))
        candidates.append(DASHBOARD_ICONS.format(slug(name)))
        candidates.append(FAVICON.format(urllib.parse.urlparse(url).netloc))
        if not raw.exists():
            for c in candidates:
                if download(c, raw):
                    print(f"Icon: {c}")
                    break
            else:
                return None
        magick = shutil.which("magick") or shutil.which("convert")
        if magick:
            done = subprocess.run([magick, f"{raw}[0]", "-background", "none", "-resize", "256x256",
                                   "-gravity", "center", "-extent", "256x256", f"png:{target}"],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
            if not done:
                return None
        else:
            shutil.copy(raw, target)
    subprocess.run(["gtk-update-icon-cache", "-q", str(DATA / "icons/hicolor")],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return target


def window_class(b: str, url: str) -> str:
    """Chromium names --app windows <browser>-<host><path, / as _>-Default."""
    parts = urllib.parse.urlparse(url)
    path = (parts.path or "/").replace("/", "_")
    base = {"brave-browser": "brave", "google-chrome-stable": "chrome"}.get(b, b)
    return f"{base}-{parts.netloc}_{path}-Default"


def install(name: str, url: str, icon: str | None) -> None:
    if "/" in name or not slug(name):
        raise SystemExit(f"Not a usable app name: {name!r}")
    url = normalize_url(url)
    b = browser()
    icon_path = fetch_icon(name, url, icon)
    if icon_path is None:
        print("No icon found; the entry uses a generic web icon")
    APPS_DIR.mkdir(parents=True, exist_ok=True)
    entry = APPS_DIR / f"{PREFIX}{slug(name)}.desktop"
    entry.write_text(
        "[Desktop Entry]\n"
        "Version=1.0\n"
        "Type=Application\n"
        f"Name={name}\n"
        f"Comment=Web app: {url}\n"
        f'Exec="{SELF}" launch {url}\n'
        # full path: Quickshell (Qt) doesn't see icons added to the theme
        # after it started; GTK apps find it in the hicolor theme too
        f"Icon={icon_path if icon_path else 'web-browser'}\n"
        "Terminal=false\n"
        "Categories=Network;WebBrowser;\n"
        f"StartupWMClass={window_class(b, url)}\n"
        f"X-WebApp-URL={url}\n"
    )
    entry.chmod(0o755)
    print(f"Installed {name}: {entry}")


def installed() -> list[tuple[str, str, Path]]:
    apps = []
    for entry in sorted(APPS_DIR.glob(f"{PREFIX}*.desktop")):
        text = entry.read_text()
        name = re.search(r"^Name=(.*)$", text, re.M)
        url = re.search(r"^X-WebApp-URL=(.*)$", text, re.M)
        apps.append((name.group(1) if name else entry.stem, url.group(1) if url else "", entry))
    return apps


def remove(name: str) -> None:
    for app_name, _, entry in installed():
        if app_name.lower() == name.lower() or entry.stem == f"{PREFIX}{slug(name)}":
            entry.unlink()
            (ICON_DIR / f"{entry.stem}.png").unlink(missing_ok=True)
            print(f"Removed {app_name}")
            return
    raise SystemExit(f"No web app named {name!r} (see: webapp.py list)")


def launch(url: str) -> None:
    b = browser()
    # own session: the window outlives whatever started it
    subprocess.Popen([b, f"--app={normalize_url(url)}"], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def ask() -> None:
    try:
        name = input("Name: ").strip()
        url = input("URL: ").strip()
        icon = input("Icon (PNG URL, file, or dashboardicons.com name; empty: find one): ").strip() or None
    except (EOFError, KeyboardInterrupt):
        print()
        return
    if name and url:
        install(name, url, icon)


def main(argv: list[str]) -> int:
    if not argv:
        ask()
    elif argv[0] in ("-h", "--help"):
        print(__doc__.strip())
    elif argv[0] == "install" and len(argv) in (3, 4):
        install(argv[1], argv[2], argv[3] if len(argv) == 4 else None)
    elif argv[0] == "list":
        for name, url, _ in installed():
            print(f"{name}\t{url}")
    elif argv[0] == "remove" and len(argv) == 2:
        remove(argv[1])
    elif argv[0] == "launch" and len(argv) == 2:
        launch(argv[1])
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
