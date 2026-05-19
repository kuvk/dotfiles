#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

GENERATED_FILE = Path.home() / ".config/hypr/configs/generated/monitors.lua"
INTERNAL = "eDP-1"
MODE = "highres"
GAMEMODE = Path("/tmp/hypr-gamemode")
GAMEMODE_SCRIPT = Path.home() / ".config/scripts/hypr-gamemode.sh"


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
hl.monitor({{output = "{INTERNAL}", mode = "{MODE}", position = "auto", scale = "1.3333"}})

hl.workspace_rule({{ workspace = "1", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "2", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "3", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "4", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "5", monitor = "{INTERNAL}", persistent = false}})
"""
    # Laptop with one external
    elif edp_present and external:
        content = f"""
hl.monitor({{output = "{external}", mode = "{MODE}", position = "0x0", scale = "1"}})
hl.monitor({{output = "{INTERNAL}", mode = "{MODE}", position = "auto", scale = "1.6"}})

hl.workspace_rule({{ workspace = "1", monitor = "{external}", persistent = true}})
hl.workspace_rule({{ workspace = "2", monitor = "{external}", persistent = true}})
hl.workspace_rule({{ workspace = "3", monitor = "{external}", persistent = true}})
hl.workspace_rule({{ workspace = "4", monitor = "{external}", persistent = true}})
hl.workspace_rule({{ workspace = "5", monitor = "{external}", persistent = false}})

hl.workspace_rule({{ workspace = "6", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "7", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "8", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "9", monitor = "{INTERNAL}", persistent = true}})
hl.workspace_rule({{ workspace = "10", monitor = "{INTERNAL}", persistent = false}})
"""

    hypr_mon_conf.write_text(content, encoding="utf-8")
    # run(["cat", f"{GENERATED_FILE}"])
    
    # Turn off gamemode if on
    if GAMEMODE.exists():
        run(["/usr/bin/bash", f"{GAMEMODE_SCRIPT}"])

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
