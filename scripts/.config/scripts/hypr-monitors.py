#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

GENERATED_FILE = Path.home() / ".config/hypr/configs/generated/monitors.conf"
INTERNAL = "eDP-1"
MODE = "highres"


def run(
    cmd: list[str], *, check: bool = True, capture: bool = False, text: bool = True
) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        check=check,
        stdout=subprocess.PIPE if capture else None,
        stderr=None,
        text=text,
    )


def main() -> None:
    hypr_mon_conf = GENERATED_FILE
    hypr_mon_conf.parent.mkdir(parents=True, exist_ok=True)

    monitors_json = run(["hyprctl", "monitors", "-j"], capture=True).stdout
    monitors = json.loads(monitors_json)

    names = [m.get("name", "") for m in monitors if isinstance(m, dict)]
    edp_present = INTERNAL in names

    external = next((n for n in names if n != INTERNAL), "")

    # Laptop internal only
    if edp_present and not external:
        content = f"""
monitor = {INTERNAL}, {MODE}, auto, 1.3333
workspace = 1, monitor:{INTERNAL}, persistent:true
workspace = 2, monitor:{INTERNAL}, persistent:true
workspace = 3, monitor:{INTERNAL}, persistent:true
workspace = 4, monitor:{INTERNAL}, persistent:true
workspace = 5, monitor:{INTERNAL}
"""
    # Laptop with one external
    elif edp_present and external:
        content = f"""
monitor = {external}, {MODE}, 0x0, 1
monitor = {INTERNAL}, {MODE}, auto, 1.6

workspace = 1, monitor:{external}, persistent:true
workspace = 2, monitor:{external}, persistent:true
workspace = 3, monitor:{external}, persistent:true
workspace = 4, monitor:{external}, persistent:true
workspace = 5, monitor:{external}

workspace = 6, monitor:{INTERNAL}, persistent:true
workspace = 7, monitor:{INTERNAL}, persistent:true
workspace = 8, monitor:{INTERNAL}, persistent:true
workspace = 9, monitor:{INTERNAL}, persistent:true
workspace = 10, monitor:{INTERNAL}
"""

    hypr_mon_conf.write_text(content, encoding="utf-8")
    # run(["cat", f"{GENERATED_FILE}"])

    # hyprctl reload
    run(["hyprctl", "reload"])

    # pkill waybar || true
    subprocess.run(["pkill", "waybar"], check=False)

    # waybar &> "$HOME/.local/share/waybar/waybar.log" &
    log_path = Path.home() / ".local/share/waybar/waybar.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_file = open(log_path, "w", encoding="utf-8")
    try:
        subprocess.Popen(
            ["waybar"],
            stdout=log_file,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env=os.environ.copy(),
        )
    finally:
        log_file.close()


if __name__ == "__main__":
    main()
