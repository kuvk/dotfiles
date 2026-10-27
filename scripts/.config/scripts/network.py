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
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    if code != 0:
        print(err, file=sys.stderr)
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
