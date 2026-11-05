#!/usr/bin/env python3
"""Monitor layouts per setup, with workspaces, brightness and text size.

Each combination of connected monitors (home dock, office, laptop alone, ...)
gets its own profile in ~/.config/hypr/monitors.json. Monitors are matched by
their EDID description, not the port, so a profile survives a different cable
or dock. The first time a setup is seen its profile is created from the
current live layout, and workspaces are split across the monitors.

  hypr-monitors.py [apply]              apply the profile for the connected monitors
  hypr-monitors.py state                print the current profile as JSON (Quickshell)
  hypr-monitors.py set '<json>'         save and apply changes from Quickshell
  hypr-monitors.py brightness           print brightness per monitor as JSON
  hypr-monitors.py brightness NAME PCT  set brightness (backlight or DDC/CI)
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
PROFILES_FILE = HOME / ".config/hypr/monitors.json"
GENERATED_FILE = HOME / ".config/hypr/configs/generated/monitors.lua"
GAMEMODE = Path("/tmp/hypr-gamemode")
GAMEMODE_SCRIPT = HOME / ".config/scripts/hypr-gamemode.sh"

INTERNAL_PREFIXES = ("eDP", "LVDS", "DSI")
WORKSPACES = 10

# Descriptions shared by several connected monitors (same model, no serial);
# those are told apart by port instead
DUPLICATES: set[str] = set()


def run(cmd: list[str], *, check: bool = False) -> str:
    out = subprocess.run(cmd, check=check, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    return out.stdout


def hypr_json(what: str) -> list:
    try:
        return json.loads(run(["hyprctl", what, "all", "-j"]) or "[]")
    except json.JSONDecodeError:
        return []


def is_internal(name: str) -> bool:
    return name.startswith(INTERNAL_PREFIXES)


def ident(m: dict) -> str:
    """Stable identity: the EDID description, falling back to the port name."""
    desc = (m.get("description") or "").strip()
    return desc if desc and desc not in DUPLICATES else m["name"]


def selector(mon_id: str, live: dict[str, dict]) -> str:
    m = live.get(mon_id)
    if m and ident(m) != m["name"]:
        return "desc:" + m["description"].strip()
    return mon_id


def mode_str(width: int, height: int, refresh: float) -> str:
    return f"{width}x{height}@{refresh:.2f}"


def parse_mode(mode: str) -> tuple[int, int]:
    m = re.match(r"(\d+)x(\d+)", mode)
    return (int(m.group(1)), int(m.group(2))) if m else (1920, 1080)


def logical_size(mon: dict) -> tuple[float, float]:
    w, h = parse_mode(mon["mode"])
    if mon.get("transform", 0) % 2 == 1:
        w, h = h, w
    scale = float(mon.get("scale", 1)) or 1
    return w / scale, h / scale


def available_modes(m: dict) -> list[str]:
    modes = []
    for raw in m.get("availableModes", []):
        mm = re.match(r"(\d+)x(\d+)@([\d.]+)", raw)
        if mm:
            s = mode_str(int(mm.group(1)), int(mm.group(2)), float(mm.group(3)))
            if s not in modes:
                modes.append(s)
    return modes


def best_mode(m: dict) -> str:
    modes = available_modes(m)
    if not modes:
        return mode_str(m.get("width", 1920), m.get("height", 1080), m.get("refreshRate", 60))

    def key(s: str) -> tuple:
        w, h = parse_mode(s)
        return (w * h, float(s.split("@")[1]))

    return max(modes, key=key)


# ---------------------------------------------------------------- profiles


def load_profiles() -> dict:
    try:
        data = json.loads(PROFILES_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        data = {}
    data.setdefault("text_scale", 1.0)
    data.setdefault("profiles", {})
    return data


def save_profiles(data: dict) -> None:
    PROFILES_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = PROFILES_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    tmp.replace(PROFILES_FILE)


def profile_key(live: list[dict]) -> str:
    return " + ".join(sorted(ident(m) for m in live))


def default_profile(live: list[dict]) -> dict:
    """Start from what Hyprland shows now, then split workspaces."""
    monitors = {}
    for m in live:
        enabled = not m.get("disabled", False)
        monitors[ident(m)] = {
            "enabled": enabled,
            "mode": mode_str(m["width"], m["height"], m["refreshRate"]) if enabled else best_mode(m),
            "x": m.get("x", 0),
            "y": m.get("y", 0),
            "scale": round(float(m.get("scale", 1)), 6),
            "transform": m.get("transform", 0),
        }

    # Externals first (left to right), internal last, like the old fixed layouts
    order = sorted(
        (m for m in live if monitors[ident(m)]["enabled"]),
        key=lambda m: (is_internal(m["name"]), m.get("x", 0)),
    )
    workspaces = {}
    if order:
        per = WORKSPACES // len(order)
        extra = WORKSPACES % len(order)
        ws = 1
        for i, m in enumerate(order):
            for _ in range(per + (1 if i < extra else 0)):
                workspaces[str(ws)] = ident(m)
                ws += 1
    return {"monitors": monitors, "workspaces": workspaces}


def current_profile(data: dict, live: list[dict]) -> tuple[str, dict]:
    key = profile_key(live)
    profile = data["profiles"].get(key)
    if profile is None:
        profile = default_profile(live)
        data["profiles"][key] = profile
        save_profiles(data)
    # Monitors seen for the first time inside a known setup cannot happen
    # (the key would differ), but keep the profile complete anyway
    for m in live:
        profile["monitors"].setdefault(ident(m), default_profile([m])["monitors"][ident(m)])
    return key, profile


def effective_workspaces(profile: dict, live: list[dict]) -> dict[str, str]:
    """Workspaces of a disabled monitor go to the first enabled one, without
    changing the saved assignment, so they come back when it's re-enabled."""
    connected = {ident(m) for m in live}
    enabled = [mid for mid, mon in profile["monitors"].items() if mon["enabled"] and mid in connected]
    if not enabled:
        return {}
    return {ws: (mid if mid in enabled else enabled[0]) for ws, mid in profile["workspaces"].items()}


# ---------------------------------------------------------------- applying


def lua_str(s: str) -> str:
    return json.dumps(s)  # a JSON string is a valid Lua string literal


def render_lua(profile: dict, live: list[dict]) -> str:
    by_id = {ident(m): m for m in live}
    lines = ["-- Generated by ~/.config/scripts/hypr-monitors.py from ~/.config/hypr/monitors.json", ""]
    for mid, mon in profile["monitors"].items():
        if mid not in by_id:
            continue
        sel = lua_str(selector(mid, by_id))
        if not mon["enabled"]:
            lines.append(f"hl.monitor({{ output = {sel}, disabled = true }})")
            continue
        lines.append(
            f"hl.monitor({{ output = {sel}, mode = {lua_str(mon['mode'])}, "
            f"position = \"{round(mon['x'])}x{round(mon['y'])}\", scale = \"{mon['scale']:g}\", "
            f"transform = {int(mon.get('transform', 0))} }})"
        )
    # Anything not in the profile (e.g. a projector plugged in later) still works
    lines.append('hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })')
    lines.append("")
    for ws, mid in sorted(effective_workspaces(profile, live).items(), key=lambda kv: int(kv[0])):
        if mid in by_id:
            lines.append(
                f"hl.workspace_rule({{ workspace = \"{ws}\", monitor = {lua_str(selector(mid, by_id))}, persistent = true }})"
            )
    return "\n".join(lines) + "\n"


def apply_text_scale(scale: float) -> None:
    if shutil.which("gsettings"):
        run(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", f"{scale:g}"])


def apply(data: dict, live: list[dict], *, force_reload: bool = False) -> None:
    key, profile = current_profile(data, live)
    content = render_lua(profile, live)

    GENERATED_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        changed = GENERATED_FILE.read_text() != content
    except FileNotFoundError:
        changed = True
    if changed:
        GENERATED_FILE.write_text(content)

    if changed or force_reload:
        # A reload resets the runtime gamemode tweaks, so leave gamemode first
        if GAMEMODE.exists() and GAMEMODE_SCRIPT.exists():
            run(["bash", str(GAMEMODE_SCRIPT)])
        run(["hyprctl", "reload"])

    # Workspace rules only apply to new workspaces; move the existing ones
    by_id = {ident(m): m for m in live}
    current = {str(w["id"]): w.get("monitor") for w in hypr_json("workspaces") if w.get("id", 0) > 0}
    for ws, mid in effective_workspaces(profile, live).items():
        target = by_id.get(mid)
        if target and ws in current and current[ws] != target["name"]:
            run(["hyprctl", "dispatch", f"hl.dsp.workspace.move({{ workspace = \"{ws}\", monitor = {lua_str(target['name'])} }})"])

    apply_text_scale(float(data.get("text_scale", 1.0)))


# ---------------------------------------------------------------- brightness


def backlight_device() -> str | None:
    out = run(["brightnessctl", "-m", "-c", "backlight"]) if shutil.which("brightnessctl") else ""
    return out.split(",")[0] if out.strip() else None


def ddc_buses() -> dict[str, str]:
    """Map connector name (DP-1) to I2C bus number via `ddcutil detect`."""
    if not shutil.which("ddcutil"):
        return {}
    buses, bus = {}, None
    for line in run(["ddcutil", "detect", "--terse"]).splitlines():
        line = line.strip()
        if line.startswith("I2C bus:"):
            bus = line.rsplit("-", 1)[-1]
        elif line.startswith("DRM connector:") and bus:
            connector = line.split(":", 1)[1].strip()
            buses[re.sub(r"^card\d+-", "", connector)] = bus
    return buses


def brightness_get(live: list[dict]) -> dict:
    result = {}
    backlight = backlight_device()
    buses = None
    for m in live:
        if m.get("disabled"):
            continue
        name = m["name"]
        if is_internal(name) and backlight:
            f = run(["brightnessctl", "-m", "-d", backlight]).strip().split(",")
            result[name] = round(int(f[2]) * 100 / int(f[4])) if len(f) >= 5 else None
        else:
            if buses is None:
                buses = ddc_buses()
            bus = buses.get(name)
            value = None
            if bus:
                # VCP 10 C 50 100
                parts = run(["ddcutil", "--bus", bus, "getvcp", "10", "--terse"]).split()
                if len(parts) >= 5 and parts[2] == "C":
                    value = round(int(parts[3]) * 100 / max(1, int(parts[4])))
            result[name] = value
    return result


def brightness_set(name: str, pct: int) -> None:
    pct = max(1, min(100, pct))
    backlight = backlight_device()
    if is_internal(name) and backlight:
        run(["brightnessctl", "-q", "-d", backlight, "s", f"{pct}%"])
        return
    bus = ddc_buses().get(name)
    if bus:
        run(["ddcutil", "--bus", bus, "setvcp", "10", str(pct), "--noverify"])


# ---------------------------------------------------------------- state for quickshell


def state(data: dict, live: list[dict]) -> dict:
    key, profile = current_profile(data, live)
    monitors = []
    for m in live:
        mid = ident(m)
        mon = profile["monitors"][mid]
        w, h = logical_size(mon)
        monitors.append({
            "id": mid,
            "name": m["name"],
            "description": (m.get("description") or "").strip(),
            "make": m.get("make", ""),
            "model": m.get("model", ""),
            "internal": is_internal(m["name"]),
            "enabled": mon["enabled"],
            "mode": mon["mode"],
            "modes": available_modes(m) or [mon["mode"]],
            "x": mon["x"],
            "y": mon["y"],
            "width": w,
            "height": h,
            "scale": mon["scale"],
            "transform": mon.get("transform", 0),
        })
    return {
        "key": key,
        "text_scale": data.get("text_scale", 1.0),
        "monitors": monitors,
        "workspaces": profile["workspaces"],
    }


def set_state(data: dict, live: list[dict], new: dict) -> None:
    key, profile = current_profile(data, live)
    for m in new.get("monitors", []):
        mon = profile["monitors"].get(m["id"])
        if mon is None:
            continue
        for field in ("enabled", "mode", "x", "y", "scale", "transform"):
            if field in m:
                mon[field] = m[field]
    if not any(mon["enabled"] for mon in profile["monitors"].values()):
        print("refusing to disable every monitor", file=sys.stderr)
        return
    if "workspaces" in new:
        profile["workspaces"] = {str(k): v for k, v in new["workspaces"].items()}
    if "text_scale" in new:
        data["text_scale"] = round(float(new["text_scale"]), 2)
    save_profiles(data)
    apply(data, live)


def main(argv: list[str]) -> int:
    live = hypr_json("monitors")
    if not live:
        print("hyprctl monitors returned nothing; is Hyprland running?", file=sys.stderr)
        return 1
    descs = [(m.get("description") or "").strip() for m in live]
    DUPLICATES.update(d for d in descs if d and descs.count(d) > 1)
    data = load_profiles()
    cmd = argv[0] if argv else "apply"

    if cmd == "apply":
        apply(data, live, force_reload="--reload" in argv)
    elif cmd == "state":
        print(json.dumps(state(data, live)))
    elif cmd == "set" and len(argv) > 1:
        set_state(data, live, json.loads(argv[1]))
    elif cmd == "brightness" and len(argv) == 1:
        print(json.dumps(brightness_get(live)))
    elif cmd == "brightness" and len(argv) == 3:
        brightness_set(argv[1], int(float(argv[2])))
    else:
        print(__doc__.strip())
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
