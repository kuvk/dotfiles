#!/usr/bin/env python3
"""Network details and actions for the Quickshell Network dropdown.

Everything goes through NetworkManager (nmcli); the speed test uses
Cloudflare's speed endpoints, like speed.cloudflare.com, with the standard
library only.

  network.py status                     JSON: wired, VPNs, details, DNS
  network.py wired on|off IFACE         connect / disconnect a wired device
  network.py vpn up|down|delete NAME    WireGuard or other VPN connections
  network.py vpn import FILE.conf       import a WireGuard config
  network.py dns auto|cloudflare|google|quad9   DNS for the active connections
  network.py dns custom "1.1.1.1 9.9.9.9"
  network.py speedtest                  JSON lines: ping, download, upload
  network.py stats                      JSON: the default route's interface, addresses,
                                        byte counters and one ping to the router and 1.1.1.1
  network.py band [auto|2.4|5|6]        JSON: the Wi-Fi band in use and available; or pin one
  network.py qr [IFACE]                 JSON: the connected Wi-Fi as a QR code matrix (qrencode)
  network.py password IFACE             the connected Wi-Fi's password
  network.py eap SSID IDENTITY          join a WPA-Enterprise (PEAP/MSCHAPv2) network,
                                        the password on stdin

stats, band, qr, password and eap follow Omarchy's network panel scripts
(omarchy-network-status, -band, -qr, -password; github.com/basecamp/omarchy, MIT).
"""

from __future__ import annotations

import http.client
import json
import os
import ssl
import statistics
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
WIREGUARD_DIRS = [HOME / ".config/wireguard", HOME / "Downloads"]

DNS_PROVIDERS = {
    "cloudflare": ("1.1.1.1 1.0.0.1", "2606:4700:4700::1111 2606:4700:4700::1001"),
    "google": ("8.8.8.8 8.8.4.4", "2001:4860:4860::8888 2001:4860:4860::8844"),
    "quad9": ("9.9.9.9 149.112.112.112", "2620:fe::fe 2620:fe::9"),
}

VPN_TYPES = {"wireguard", "vpn"}


def nmcli(*args: str) -> tuple[int, str, str]:
    p = subprocess.run(["nmcli", *args], capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr.strip()


def fields(line: str) -> list[str]:
    """nmcli -t escapes ':' as '\\:'."""
    out, cur, i = [], "", 0
    while i < len(line):
        if line[i] == "\\" and i + 1 < len(line):
            cur += line[i + 1]
            i += 2
            continue
        if line[i] == ":":
            out.append(cur)
            cur = ""
        else:
            cur += line[i]
        i += 1
    out.append(cur)
    return out


def rows(*args: str) -> list[list[str]]:
    code, out, _ = nmcli("-t", *args)
    return [fields(l) for l in out.splitlines() if l] if code == 0 else []


def sysfs(iface: str, name: str) -> str:
    try:
        return Path(f"/sys/class/net/{iface}/{name}").read_text().strip()
    except OSError:
        return ""


def device_details(iface: str) -> dict:
    info: dict = {"iface": iface, "ip4": "", "gateway": "", "dns": [], "mac": ""}
    for key, value in (r[:2] for r in rows("-f", "GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show", iface) if len(r) >= 2):
        if key == "GENERAL.HWADDR":
            info["mac"] = value
        elif key.startswith("IP4.ADDRESS") and not info["ip4"]:
            info["ip4"] = value
        elif key == "IP4.GATEWAY":
            info["gateway"] = value
        elif key.startswith("IP4.DNS"):
            info["dns"].append(value)
        elif key.startswith("IP6.ADDRESS") and "ip6" not in info and not value.lower().startswith("fe80"):
            info["ip6"] = value
    speed = sysfs(iface, "speed")
    if speed.isdigit() and int(speed) > 0:
        info["link_speed"] = int(speed)
    return info


def dns_mode(connection: str) -> dict:
    values = {r[0]: r[1] for r in rows("-f", "ipv4.ignore-auto-dns,ipv4.dns", "connection", "show", connection) if len(r) >= 2}
    servers = values.get("ipv4.dns", "").replace(",", " ").split()
    if values.get("ipv4.ignore-auto-dns") != "yes" or not servers:
        return {"mode": "auto", "servers": servers}
    joined = " ".join(servers)
    for name, (v4, _) in DNS_PROVIDERS.items():
        if joined == v4:
            return {"mode": name, "servers": servers}
    return {"mode": "custom", "servers": servers}


def status() -> dict:
    devices = rows("-f", "DEVICE,TYPE,STATE,CONNECTION", "device")
    wired = []
    active = None
    for dev in devices:
        if len(dev) < 4:
            continue
        iface, kind, state, conn = dev[:4]
        if kind == "ethernet":
            wired.append({"iface": iface, "state": state.split(" ")[0], "connection": conn})
        if state.startswith("connected") and kind in ("ethernet", "wifi") and (active is None or kind == "ethernet" and active["type"] != "ethernet"):
            active = {"iface": iface, "type": kind, "connection": conn}

    vpns = []
    imported = set()
    for r in rows("-f", "NAME,TYPE,ACTIVE,DEVICE", "connection", "show"):
        if len(r) >= 4 and r[1] in VPN_TYPES:
            vpns.append({"name": r[0], "type": r[1], "active": r[2] == "yes", "device": r[3]})
            imported.add(r[0])

    files = []
    for d in WIREGUARD_DIRS:
        if d.is_dir():
            for f in sorted(d.glob("*.conf")):
                try:
                    if f.stem not in imported and "[Interface]" in f.read_text(errors="ignore")[:4096]:
                        files.append(str(f))
                except OSError:
                    pass

    result = {"wired": wired, "vpns": vpns, "wireguardFiles": files, "active": None, "dns": {"mode": "auto", "servers": []}}
    if active:
        details = device_details(active["iface"])
        result["active"] = {**active, **details}
        result["dns"] = dns_mode(active["connection"])
        result["dns"]["current"] = details["dns"]
    return result


def active_connections() -> list[tuple[str, str]]:
    return [(r[0], r[1]) for r in rows("-f", "NAME,DEVICE,TYPE", "connection", "show", "--active")
            if len(r) >= 3 and r[2] in ("802-3-ethernet", "802-11-wireless")]


def set_dns(mode: str, custom: str = "") -> int:
    conns = active_connections()
    if not conns:
        print("no active connection", file=sys.stderr)
        return 1
    for name, iface in conns:
        if mode == "auto":
            args = ["ipv4.ignore-auto-dns", "no", "ipv4.dns", "", "ipv6.ignore-auto-dns", "no", "ipv6.dns", ""]
        else:
            v4, v6 = DNS_PROVIDERS.get(mode, (custom, ""))
            v4s = " ".join(s for s in v4.replace(",", " ").split() if ":" not in s)
            v6s = " ".join(s for s in (v6 + " " + v4).replace(",", " ").split() if ":" in s)
            args = ["ipv4.ignore-auto-dns", "yes", "ipv4.dns", v4s, "ipv6.ignore-auto-dns", "yes" if v6s else "no", "ipv6.dns", v6s]
        code, _, err = nmcli("connection", "modify", name, *args)
        if code != 0:
            print(err, file=sys.stderr)
            return code
        # apply without dropping the connection
        if nmcli("device", "reapply", iface)[0] != 0:
            nmcli("connection", "up", name)
    return 0


# ---------------------------------------------------------------- speed test


HOST = "speed.cloudflare.com"


def emit(**data) -> None:
    print(json.dumps(data), flush=True)


def connection() -> http.client.HTTPSConnection:
    return http.client.HTTPSConnection(HOST, timeout=15, context=ssl.create_default_context())


def speedtest() -> int:
    try:
        conn = connection()
        # Latency: time to first byte of empty downloads on a warm connection
        samples = []
        for i in range(8):
            start = time.perf_counter()
            conn.request("GET", "/__down?bytes=0")
            conn.getresponse().read()
            if i > 0:
                samples.append((time.perf_counter() - start) * 1000)
        ping = statistics.median(samples)
        jitter = statistics.mean(abs(a - b) for a, b in zip(samples, samples[1:]))
        emit(phase="ping", ping=round(ping, 1), jitter=round(jitter, 1))

        # Download: 25 MB requests back to back for ~8 s
        total, start, last = 0, time.perf_counter(), 0.0
        while time.perf_counter() - start < 8:
            conn.request("GET", f"/__down?bytes={25_000_000}")
            resp = conn.getresponse()
            if resp.status != 200:
                raise OSError(f"download refused (HTTP {resp.status})")
            while True:
                chunk = resp.read(256 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                elapsed = time.perf_counter() - start
                if elapsed - last > 0.4:
                    last = elapsed
                    emit(phase="download", download=round(total * 8 / elapsed / 1e6, 1), progress=min(1, elapsed / 8))
                if elapsed > 8:
                    break
        conn.close()
        down = total * 8 / (time.perf_counter() - start) / 1e6
        emit(phase="download", download=round(down, 1), progress=1)

        # Upload: a few rounds, growing until a round takes ~2 s or 8 s pass
        conn = connection()
        size, sent, start = 1_000_000, 0, time.perf_counter()
        payload = os.urandom(1_000_000)
        while time.perf_counter() - start < 8:
            body = payload * (size // len(payload))
            t0 = time.perf_counter()
            conn.request("POST", "/__up", body=body, headers={"Content-Type": "application/octet-stream"})
            conn.getresponse().read()
            sent += len(body)
            elapsed = time.perf_counter() - start
            emit(phase="upload", upload=round(sent * 8 / elapsed / 1e6, 1), progress=min(1, elapsed / 8))
            if time.perf_counter() - t0 < 2 and size < 32_000_000:
                size *= 2
        up = sent * 8 / (time.perf_counter() - start) / 1e6
        emit(phase="done", ping=round(ping, 1), jitter=round(jitter, 1), download=round(down, 1), upload=round(up, 1))
        return 0
    except (OSError, http.client.HTTPException, statistics.StatisticsError) as e:
        emit(phase="error", message=str(e))
        return 1


# ---------------------------------------------------------------- stats (omarchy-network-status)


PROBE = "1.1.1.1"


def run_text(cmd: list[str], stdin: str | None = None) -> tuple[int, str, str]:
    try:
        p = subprocess.run(cmd, input=stdin, capture_output=True, text=True, env=os.environ | {"LC_ALL": "C"})
    except FileNotFoundError:
        return 127, "", f"{cmd[0]} is not installed"
    return p.returncode, p.stdout, p.stderr.strip()


def default_route() -> dict:
    try:
        return json.loads(run_text(["ip", "-j", "route", "get", PROBE])[1] or "[]")[0]
    except (json.JSONDecodeError, IndexError, KeyError):
        return {}


def ping_proc(host: str) -> subprocess.Popen | None:
    try:
        return subprocess.Popen(["ping", "-n", "-c", "1", "-W", "1", host], stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, text=True, env=os.environ | {"LC_ALL": "C"})
    except FileNotFoundError:
        return None


def ping_result(proc: subprocess.Popen | None) -> float | None:
    """Milliseconds, or None for a lost probe."""
    if proc is None:
        return None
    out, _ = proc.communicate()
    for part in out.split():
        if part.startswith(("time=", "time<")):
            try:
                return float(part[5:])
            except ValueError:
                return None
    return None


def stats() -> dict:
    route = default_route()
    iface = route.get("dev", "")
    if not iface:
        return {}
    gateway = route.get("gateway", "")
    # Both probes at once, so a lost one costs a second, not two
    router, internet = (ping_proc(gateway) if gateway else None), ping_proc(PROBE)
    prefix = ""
    try:
        for info in json.loads(run_text(["ip", "-j", "addr", "show", iface])[1] or "[]")[0].get("addr_info", []):
            if info.get("family") == "inet":
                prefix = str(info.get("prefixlen", ""))
                break
    except (json.JSONDecodeError, IndexError):
        pass
    net = Path(f"/sys/class/net/{iface}")
    kind = "wifi" if (net / "wireless").is_dir() else ("ethernet" if (net / "device").exists() else "virtual")
    result = {
        "iface": iface,
        "type": kind,
        "ip": route.get("prefsrc", ""),
        "prefix": prefix,
        "gateway": gateway,
        "rx_bytes": int(sysfs(iface, "statistics/rx_bytes") or 0),
        "tx_bytes": int(sysfs(iface, "statistics/tx_bytes") or 0),
        "internet_ping_ms": ping_result(internet),
    }
    if gateway:
        result["router_ping_ms"] = ping_result(router)
    return result


# ---------------------------------------------------------------- Wi-Fi band (omarchy-network-band)


NM_BANDS = {"2.4": "bg", "5": "a", "6": "6GHz"}


def nm_get(*args: str) -> list[str]:
    """nmcli -g values, unescaped (an SSID may contain ':')."""
    code, out, _ = run_text(["nmcli", "-e", "no", "-g", *args])
    return out.splitlines() if code == 0 else []


def band_for_freq(freq: str) -> str:
    digits = "".join(ch for ch in freq.split(".")[0] if ch.isdigit())
    mhz = int(digits) if digits else 0
    if 2400 <= mhz < 2500:
        return "2.4"
    if 4900 <= mhz < 5925:
        return "5"
    if 5925 <= mhz < 7125:
        return "6"
    return ""


def wifi_device() -> str:
    for line in nm_get("DEVICE,TYPE,STATE", "device", "status"):
        dev, kind, state = (line.split(":", 2) + ["", ""])[:3]
        if kind == "wifi" and state.startswith("connected"):
            return dev
    return ""


def wifi_profile(dev: str) -> str:
    values = nm_get("GENERAL.CONNECTION", "device", "show", dev)
    return values[0] if values else ""


def band_status() -> dict:
    dev = wifi_device()
    if not dev:
        return {}
    # FREQ first, SSID last: an SSID with ':' is joined back together
    aps = []
    for line in nm_get("IN-USE,FREQ,SSID", "device", "wifi", "list", "ifname", dev, "--rescan", "no"):
        in_use, freq, ssid = (line.split(":", 2) + ["", ""])[:3]
        aps.append((in_use == "*", freq, ssid))
    current = next(((freq, ssid) for used, freq, ssid in aps if used), None)
    if not current:
        return {}
    band, ssid = band_for_freq(current[0]), current[1]
    # Every band the network answers on (the one in use always counts); a pin to a band
    # it doesn't answer on would drop the connection
    available = {band} | {band_for_freq(freq) for _, freq, name in aps if name == ssid}
    available.discard("")
    selected = (nm_get("802-11-wireless.band", "connection", "show", wifi_profile(dev)) or [""])[0]
    selected = {v: k for k, v in NM_BANDS.items()}.get(selected, "auto")
    return {"band": band, "available": sorted(available, key=float), "selected": selected}


def set_band(target: str) -> int:
    dev = wifi_device()
    profile = wifi_profile(dev) if dev else ""
    if not profile:
        print("no connected Wi-Fi", file=sys.stderr)
        return 1
    if target != "auto" and target not in band_status().get("available", []):
        print(f"{target} GHz is not available on this network", file=sys.stderr)
        return 1
    desired = "" if target == "auto" else NM_BANDS[target]
    previous = (nm_get("802-11-wireless.band", "connection", "show", profile) or [""])[0]
    if previous == desired:
        return 0
    run_text(["nmcli", "connection", "modify", profile, "802-11-wireless.band", desired])
    # The band changes on reassociation; if it can't come back up there, put the old
    # setting back rather than leave the machine offline
    if run_text(["nmcli", "connection", "up", profile])[0] != 0:
        run_text(["nmcli", "connection", "modify", profile, "802-11-wireless.band", previous])
        run_text(["nmcli", "connection", "up", profile])
        print(f"could not connect on {target} GHz; went back to the previous band", file=sys.stderr)
        return 1
    return 0


# ---------------------------------------------------------------- QR code and password (omarchy-network-qr, -password)


def wifi_secrets(iface: str) -> dict:
    """SSID, security and password of the Wi-Fi connection active on iface."""
    uuid = (nm_get("GENERAL.CON-UUID", "device", "show", iface) or [""])[0]
    if not uuid or uuid == "--":
        raise ValueError("No active Wi-Fi connection")
    code, out, _ = run_text(["nmcli", "--show-secrets", "-e", "no", "-g",
                             "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,"
                             "802-11-wireless.hidden,802-11-wireless-security.wep-key0", "connection", "show", "uuid", uuid])
    ssid, key_mgmt, psk, hidden, wep = (out.splitlines() + [""] * 5)[:5]
    if not ssid:
        raise ValueError("Could not read the Wi-Fi name")
    if "eap" in key_mgmt or "ieee8021x" in key_mgmt:
        raise ValueError("Enterprise Wi-Fi has no shareable password")
    if key_mgmt and key_mgmt != "none":
        security, password = "WPA", psk
    elif wep:
        security, password = "WEP", wep  # NetworkManager: key-mgmt "none" plus a WEP key
    else:
        security, password = "nopass", ""
    if security != "nopass" and not password:
        raise ValueError("Could not read the Wi-Fi password")
    return {"ssid": ssid, "security": security, "password": password, "hidden": hidden == "yes"}


def qr_escape(value: str) -> str:
    for ch in "\\;,:":
        value = value.replace(ch, "\\" + ch)
    return value


def qr(iface: str) -> int:
    if not iface:
        # the default route's device when it's Wi-Fi, else the first connected Wi-Fi
        dev = default_route().get("dev", "")
        iface = dev if dev and Path(f"/sys/class/net/{dev}/wireless").is_dir() else wifi_device()
    try:
        if not iface:
            raise ValueError("No active Wi-Fi connection")
        secrets = wifi_secrets(iface)
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    payload = f"WIFI:T:{secrets['security']};S:{qr_escape(secrets['ssid'])};P:{qr_escape(secrets['password'])};"
    if secrets["hidden"]:
        payload += "H:true;"
    payload += ";"
    # ASCII art is two characters per module: one 0/1 per pair. Margin 4 is the quiet zone.
    code, out, err = run_text(["qrencode", "--type", "ASCII", "--margin", "4", "--output", "-"], stdin=payload)
    if code != 0:
        print(err or "Could not make the QR code", file=sys.stderr)
        return 1
    matrix = ["".join("1" if "#" in line[i:i + 2] else "0" for i in range(0, len(line), 2)) for line in out.splitlines() if line]
    print(json.dumps({"iface": iface, "ssid": secrets["ssid"], "security": secrets["security"], "rows": matrix}))
    return 0


def password(iface: str) -> int:
    try:
        secrets = wifi_secrets(iface)
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    if not secrets["password"]:
        print("This network has no password", file=sys.stderr)
        return 1
    print(secrets["password"])
    return 0


# ---------------------------------------------------------------- WPA-Enterprise


def eap(ssid: str, identity: str) -> int:
    """PEAP/MSCHAPv2 profile; the password comes on stdin and goes to nmcli's editor on
    stdin too, never as an argument (arguments are readable in /proc)."""
    secret = sys.stdin.readline().rstrip("\n")
    uuid = run_text(["uuidgen"])[1].strip()
    code, _, err = run_text(["nmcli", "connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid,
                             "connection.uuid", uuid, "wifi-sec.key-mgmt", "wpa-eap", "802-1x.eap", "peap",
                             "802-1x.phase2-auth", "mschapv2", "802-1x.identity", identity, "802-1x.auth-timeout", "8"])
    if code == 0:
        code, _, err = run_text(["nmcli", "connection", "edit", "uuid", uuid],
                                stdin=f"set 802-1x.password {secret}\nsave\nquit\n")
    if code == 0:
        code, _, err = run_text(["nmcli", "connection", "up", "uuid", uuid])
    if code != 0:
        run_text(["nmcli", "connection", "delete", "uuid", uuid])
        print(err or "Connection failed", file=sys.stderr)
    return code


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    cmd, args = argv[0], argv[1:]
    if cmd == "status":
        print(json.dumps(status()))
        return 0
    if cmd == "wired" and len(args) == 2 and args[0] in ("on", "off"):
        code, _, err = nmcli("device", "connect" if args[0] == "on" else "disconnect", args[1])
    elif cmd == "vpn" and len(args) == 2 and args[0] in ("up", "down", "delete"):
        code, _, err = nmcli("connection", args[0], "id", args[1])
    elif cmd == "vpn" and len(args) == 2 and args[0] == "import":
        code, _, err = nmcli("connection", "import", "type", "wireguard", "file", args[1])
    elif cmd == "dns" and args and (args[0] in DNS_PROVIDERS or args[0] == "auto"):
        return set_dns(args[0])
    elif cmd == "dns" and len(args) == 2 and args[0] == "custom":
        return set_dns("custom", args[1])
    elif cmd == "speedtest":
        return speedtest()
    elif cmd == "stats" and not args:
        print(json.dumps(stats()))
        return 0
    elif cmd == "band" and not args:
        print(json.dumps(band_status()))
        return 0
    elif cmd == "band" and len(args) == 1 and args[0] in ("auto", *NM_BANDS):
        return set_band(args[0])
    elif cmd == "qr" and len(args) <= 1:
        return qr(args[0] if args else "")
    elif cmd == "password" and len(args) == 1:
        return password(args[0])
    elif cmd == "eap" and len(args) == 2:
        return eap(args[0], args[1])
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    if code != 0:
        print(err, file=sys.stderr)
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
