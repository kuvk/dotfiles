#!/usr/bin/env python3
"""Monitor layouts per setup, with workspaces, brightness and text size.

Each combination of connected monitors (home dock, office, laptop alone, ...)
gets its own profile in ~/.config/hypr/monitors.json. Monitors are matched by
their EDID description, not the port, so a profile survives a different cable
or dock. The first time a setup is seen its profile is created from the
current live layout, and workspaces are split across the monitors.

  hypr-monitors.py [apply]              apply the profile for the connected monitors
  hypr-monitors.py hotplug              same, from Hyprland's monitor.added/removed events
  hypr-monitors.py startup              same, at login (waits for late outputs)
  hypr-monitors.py state                print the current profile as JSON (Quickshell)
  hypr-monitors.py set '<json>'         save and apply changes from Quickshell
  hypr-monitors.py export-greeter       save each monitor's scale for the login screen
  hypr-monitors.py brightness           print brightness per monitor as JSON
  hypr-monitors.py brightness NAME PCT  set brightness (backlight or DDC/CI)

Workspaces by default: the primary monitor gets 1-5, a second monitor 6-10,
with three monitors 3 each (1-3 on the primary). Any workspace can be
assigned or left unassigned in the Displays panel.

Text size is in px (9-20, default 13), like Omarchy's display text size: it
sets the shell font, GTK's text-scaling-factor (rounded so the interface font
lands on a whole point size) and kitty's font size.
"""

from __future__ import annotations

import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
PROFILES_FILE = HOME / ".config/hypr/monitors.json"
GENERATED_FILE = HOME / ".config/hypr/configs/generated/monitors.lua"
GAMEMODE = Path("/tmp/hypr-gamemode")
GREETER_SCALES = Path("/var/lib/kuvk-shell/monitors.conf")  # only after sddm/install.sh
LOG_FILE = HOME / ".cache/hypr-monitors.log"
LOCK_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr-monitors.lock"
LAST_RUN_FILE = LOCK_FILE.with_name("hypr-monitors.last")
LAST_RUN_WINDOW = 10.0  # s; the same monitors again this soon need nothing done
GAMEMODE_SCRIPT = HOME / ".config/scripts/hypr-gamemode.sh"

INTERNAL_PREFIXES = ("eDP", "LVDS", "DSI")
WORKSPACES = 10
MAX_PER_MONITOR = 5
PROFILE_VERSION = 2

TEXT_SIZE_DEFAULT = 13  # px, the shell's base font size
KITTY_FONT_DEFAULT = 11  # pt in kitty.conf, matching 13 px
KITTY_TEXT_SIZE_FILE = HOME / ".config/kitty/text-size.conf"

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


def clean_scale(scale: float, width: int, height: int) -> float:
    """Hyprland only accepts scales that divide the mode into whole logical
    pixels, in 1/120 steps. Round up to the nearest such scale (as Omarchy does)."""
    from math import gcd

    g = gcd(width * 120, height * 120)
    k = max(1, min(g, int(scale * 120 + 0.5)))
    while g % k:
        k += 1
    return round(k / 120, 6)


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
    if "text_size" not in data:
        data["text_size"] = round(TEXT_SIZE_DEFAULT * float(data.pop("text_scale", 1.0)))
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

    profile = {"version": PROFILE_VERSION, "monitors": monitors, "primary": default_primary(live, monitors)}
    profile["workspaces"] = default_workspaces(profile, live)
    return profile


def default_primary(live: list[dict], monitors: dict) -> str:
    """The leftmost external monitor, or the internal one when alone."""
    enabled = [m for m in live if monitors[ident(m)]["enabled"]] or live
    order = sorted(enabled, key=lambda m: (is_internal(m["name"]), monitors[ident(m)]["x"]))
    return ident(order[0]) if order else ""


def default_workspaces(profile: dict, live: list[dict]) -> dict[str, str]:
    """Primary first, then left to right; at most 5 each (1 monitor: 1-5,
    2: 1-5 / 6-10, 3: 1-3 / 4-6 / 7-9)."""
    mons = profile["monitors"]
    enabled = [ident(m) for m in live if mons.get(ident(m), {}).get("enabled")]
    if not enabled:
        return {}
    primary = profile.get("primary")
    order = sorted(enabled, key=lambda mid: (mid != primary, mons[mid]["x"], mons[mid]["y"]))
    per = min(MAX_PER_MONITOR, WORKSPACES // len(order))
    workspaces, ws = {}, 1
    for mid in order:
        for _ in range(per):
            workspaces[str(ws)] = mid
            ws += 1
    return workspaces


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
    # Profiles from the first version gave a lone monitor all 10 workspaces;
    # redo their workspaces with the current defaults, keep the layout
    if profile.get("version") != PROFILE_VERSION:
        profile["version"] = PROFILE_VERSION
        profile["primary"] = default_primary(live, profile["monitors"])
        profile["workspaces"] = default_workspaces(profile, live)
        save_profiles(data)
    return key, profile


def effective_workspaces(profile: dict, live: list[dict]) -> dict[str, str]:
    """Rules only for enabled monitors. A disabled monitor's workspaces get no
    rule (Hyprland opens them where you are) and come back when it's re-enabled."""
    connected = {ident(m) for m in live}
    enabled = {mid for mid, mon in profile["monitors"].items() if mon["enabled"] and mid in connected}
    return {ws: mid for ws, mid in profile["workspaces"].items() if mid in enabled}


# ---------------------------------------------------------------- applying


def scale_str(scale: float) -> str:
    return f"{float(scale):.6f}".rstrip("0").rstrip(".")


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
            f"position = \"{round(mon['x'])}x{round(mon['y'])}\", scale = \"{scale_str(mon['scale'])}\", "
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


def apply_text_size(size: int) -> None:
    """GTK factor and kitty font size for a text size in px (13 = default)."""
    if shutil.which("gsettings"):
        # Quantize so the GTK interface font lands on a whole point size
        name = run(["gsettings", "get", "org.gnome.desktop.interface", "font-name"]).strip().strip("'")
        try:
            pt = float(name.rsplit(" ", 1)[-1])
        except ValueError:
            pt = 11.0
        factor = round(pt * size / TEXT_SIZE_DEFAULT) / pt
        run(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", f"{factor:.4f}"])

    kitty_pt = round(size * KITTY_FONT_DEFAULT / TEXT_SIZE_DEFAULT)
    content = f"# Written by hypr-monitors.py (Displays > Text size)\nfont_size {kitty_pt}.0\n"
    try:
        current = KITTY_TEXT_SIZE_FILE.read_text()
    except FileNotFoundError:
        current = ""
    if current != content and KITTY_TEXT_SIZE_FILE.parent.exists():
        KITTY_TEXT_SIZE_FILE.write_text(content)
        run(["pkill", "-USR1", "-x", "kitty"])


def export_greeter_scales(profile: dict, live: list[dict]) -> None:
    """Each monitor's latest scale for the login screen. Monitors not connected now keep
    the one they had, so any monitor you plug in comes up at its last scale."""
    if not GREETER_SCALES.parent.is_dir():
        return
    scales: dict[str, str] = {}
    try:
        for line in GREETER_SCALES.read_text().splitlines():
            output, _, scale = line.partition("\t")
            scales[output] = scale
    except OSError:
        pass
    by_id = {ident(m): m for m in live}
    for mid, mon in profile["monitors"].items():
        if mid in by_id and mon.get("enabled", True):
            scales[selector(mid, by_id)] = f"{mon.get('scale', 1)}"
    content = "".join(f"{output}\t{scale}\n" for output, scale in scales.items())
    try:
        if not GREETER_SCALES.exists() or GREETER_SCALES.read_text() != content:
            GREETER_SCALES.write_text(content)
    except OSError as e:
        log(f"could not write {GREETER_SCALES}: {e}")


def apply(data: dict, live: list[dict], *, force_reload: bool = False) -> None:
    key, profile = current_profile(data, live)
    export_greeter_scales(profile, live)
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
    try:
        listed = json.loads(run(["hyprctl", "-j", "workspaces"]) or "[]")
    except json.JSONDecodeError:
        listed = []
    current = {str(w["id"]): w.get("monitor") for w in listed if w.get("id", 0) > 0}
    for ws, mid in effective_workspaces(profile, live).items():
        target = by_id.get(mid)
        if target and ws in current and current[ws] != target["name"]:
            run(["hyprctl", "dispatch", f"hl.dsp.workspace.move({{ workspace = \"{ws}\", monitor = {lua_str(target['name'])} }})"])

    apply_text_size(int(data.get("text_size", TEXT_SIZE_DEFAULT)))


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
        "text_size": data.get("text_size", TEXT_SIZE_DEFAULT),
        "primary": profile.get("primary", ""),
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
        w, h = parse_mode(mon["mode"])
        mon["scale"] = clean_scale(float(mon["scale"]), w, h)
    if not any(mon["enabled"] for mon in profile["monitors"].values()):
        print("refusing to disable every monitor", file=sys.stderr)
        return
    if "primary" in new:
        profile["primary"] = new["primary"]
    if "workspaces" in new:
        profile["workspaces"] = {str(k): v for k, v in new["workspaces"].items() if v}
    if "text_size" in new:
        data["text_size"] = max(9, min(20, int(new["text_size"])))
    save_profiles(data)
    apply(data, live)


def log(message: str) -> None:
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        lines = LOG_FILE.read_text().splitlines()[-200:] if LOG_FILE.exists() else []
        lines.append(time.strftime("%Y-%m-%d %H:%M:%S ") + message)
        LOG_FILE.write_text("\n".join(lines) + "\n")
    except OSError:
        pass


def settle(timeout: float = 8.0) -> list[dict]:
    """Wait until the set of monitors stops changing (a dock, or a dGPU
    output that shows up a few seconds into the session)."""
    live, key, stable = [], None, 0
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        now = hypr_json("monitors")
        now_key = " + ".join(sorted(m["name"] for m in now))
        stable = stable + 1 if now and now_key == key else 0
        live, key = now, now_key
        if stable >= 3:  # unchanged for 1.5 s
            break
        time.sleep(0.5)
    return live


def wake_dark_monitors(data: dict, live: list[dict]) -> None:
    """A monitor that should be on but is disabled or has DPMS off after the
    reload (seen right after login) gets one more reload and DPMS on."""
    _, profile = current_profile(data, live)
    wanted = {mid for mid, mon in profile["monitors"].items() if mon["enabled"]}
    now = hypr_json("monitors")
    dark = [m["name"] for m in now if ident(m) in wanted and (m.get("disabled") or not m.get("dpmsStatus", True))]
    if dark:
        log(f"monitors still dark after applying: {', '.join(dark)}; reloading again")
        run(["hyprctl", "reload"])
        time.sleep(1)
    run(["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "on" })'])


def last_run_id(key: str) -> str:
    return f"{os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')}\n{key}"


def handled_just_now(key: str) -> bool:
    try:
        return (
            LAST_RUN_FILE.read_text() == last_run_id(key)
            and time.time() - LAST_RUN_FILE.stat().st_mtime < LAST_RUN_WINDOW
        )
    except OSError:
        return False


def hotplug(startup: bool = False) -> int:
    """Monitors were plugged in or out (or the session just started): switch
    to the saved profile for the connected set. Waits for the set to settle;
    one run at a time, and runs again if the set changed meanwhile."""
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOCK_FILE, "w") as lock:
        try:
            # at login, wait for a hotplug run instead of skipping
            fcntl.flock(lock, fcntl.LOCK_EX if startup else fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0  # another run is handling it
        live = settle()
        for _ in range(5):
            if not live:
                return 1
            DUPLICATES.clear()
            descs = [(m.get("description") or "").strip() for m in live]
            DUPLICATES.update(d for d in descs if d and descs.count(d) > 1)
            key = profile_key(live)
            # Login fires both the monitor.added event and `startup`: one run does the work
            if handled_just_now(key):
                return 0
            state = ", ".join(
                f"{m['name']}{' disabled' if m.get('disabled') else ''}{' dpms-off' if not m.get('dpmsStatus', True) else ''}"
                for m in live
            )
            log(f"{'startup' if startup else 'hotplug'}: applying profile '{key}' ({state})")
            data = load_profiles()
            apply(data, live)
            # start from the first workspace on the new layout
            run(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 1 })"])
            time.sleep(1)
            again = settle(4) or live
            if profile_key(again) == key:
                wake_dark_monitors(data, again)
                LAST_RUN_FILE.write_text(last_run_id(key))
                break
            live = again
    return 0


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("hotplug", "startup"):
        return hotplug(startup=argv[0] == "startup")
    live = hypr_json("monitors")
    if not live:
        print("hyprctl monitors returned nothing; is Hyprland running?", file=sys.stderr)
        return 1
    descs = [(m.get("description") or "").strip() for m in live]
    DUPLICATES.update(d for d in descs if d and descs.count(d) > 1)
    data = load_profiles()
    cmd = argv[0] if argv else "apply"

    if cmd == "apply":
        log(f"apply: profile '{profile_key(live)}'")
        apply(data, live, force_reload="--reload" in argv)
    elif cmd == "export-greeter":
        export_greeter_scales(current_profile(data, live)[1], live)
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
