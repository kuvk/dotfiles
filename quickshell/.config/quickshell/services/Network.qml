pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// NetworkManager state through nmcli (Wi-Fi) and ~/.config/scripts/network.py
// (wired, VPN, details, DNS, speed test). `nmcli monitor` triggers refreshes.
Singleton {
    id: root

    property bool wifiEnabled: true
    property string type: "none" // "ethernet" | "wifi" | "none"
    property string connection: ""
    property int strength: 0
    property var networks: [] // { ssid, signal, security, active, saved }
    property var savedNetworks: []
    property bool scanning: false
    property string connectingTo: ""
    property string error: ""

    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/network.py"
    // network.py status: { wired, vpns, wireguardFiles, active, dns }
    property var details: ({ wired: [], vpns: [], wireguardFiles: [], active: null, dns: { mode: "auto", servers: [] } })
    readonly property var activeVpns: (details.vpns ?? []).filter(v => v.active)

    // Speed test progress: { phase, ping, jitter, download, upload, progress, message }
    property var speed: ({})
    readonly property bool testing: speedProc.running

    // Throughput of the active interface (bytes/s), measured while `monitoring`
    property bool monitoring: false
    property real rxRate: 0
    property real txRate: 0

    readonly property string tooltip: {
        const lines = ["Network"];
        if (type === "ethernet")
            lines.push(`Wired: ${connection}`);
        else if (type === "wifi")
            lines.push(`Wi-Fi: ${connection}`, `Signal ${strength}%`);
        else
            lines.push(wifiEnabled ? "Not connected" : "Wi-Fi off");
        for (const v of activeVpns)
            lines.push(`VPN: ${v.name}`);
        return lines.join("\n");
    }

    readonly property string icon: {
        if (type === "ethernet")
            return Icons.ethernet;
        if (type === "wifi")
            return Icons.wifiLevels[Math.min(4, Math.floor(strength / 20))];
        return Icons.wifiOff;
    }

    function refresh(): void {
        statusProc.running = true;
        wifiProc.running = true;
        savedProc.running = true;
        detailsProc.running = true;
    }

    function run(args: var): void {
        actionProc.command = [script, ...args];
        actionProc.running = true;
    }

    function setWired(iface: string, on: bool): void {
        run(["wired", on ? "on" : "off", iface]);
    }

    function setVpn(name: string, up: bool): void {
        run(["vpn", up ? "up" : "down", name]);
    }

    function importVpn(path: string): void {
        run(["vpn", "import", path]);
    }

    function deleteVpn(name: string): void {
        run(["vpn", "delete", name]);
    }

    function setDns(mode: string, servers: string): void {
        run(mode === "custom" ? ["dns", "custom", servers] : ["dns", mode]);
    }

    function startSpeedtest(): void {
        if (speedProc.running)
            return;
        speed = { phase: "ping" };
        speedProc.running = true;
    }

    function formatRate(bytes: real): string {
        const bits = bytes * 8;
        if (bits >= 1e9)
            return `${(bits / 1e9).toFixed(1)} Gb/s`;
        if (bits >= 1e6)
            return `${(bits / 1e6).toFixed(1)} Mb/s`;
        return `${Math.round(bits / 1e3)} kb/s`;
    }

    function scan(): void {
        if (!wifiEnabled || scanning)
            return;
        scanning = true;
        scanProc.running = true;
    }

    function setWifiEnabled(on: bool): void {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        wifiEnabled = on;
    }

    function connect(ssid: string, password: string): void {
        error = "";
        connectingTo = ssid;
        const cmd = ["nmcli", "device", "wifi", "connect", ssid];
        if (password)
            cmd.push("password", password);
        connectProc.command = cmd;
        connectProc.running = true;
    }

    function disconnect(): void {
        if (type === "wifi" && connection)
            Quickshell.execDetached(["nmcli", "connection", "down", "id", connection]);
    }

    function forget(ssid: string): void {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]);
        debounce.restart();
    }

    // nmcli -t escapes ':' inside fields as '\:'
    function splitFields(line: string): var {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (ch === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }

    function lines(text: string): var {
        return text.split("\n").filter(l => l.length > 0);
    }

    Component.onCompleted: refresh()

    Timer {
        id: debounce

        interval: 500
        onTriggered: root.refresh()
    }

    // Signal strength isn't reported by `nmcli monitor`
    Timer {
        interval: 15000
        running: root.type === "wifi"
        repeat: true
        onTriggered: wifiProc.running = true
    }

    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Process {
        id: statusProc

        command: ["sh", "-c", "nmcli radio wifi; nmcli -t -f TYPE,STATE,CONNECTION device"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = root.lines(text);
                root.wifiEnabled = all[0] === "enabled";
                let type = "none", conn = "";
                for (const line of all.slice(1)) {
                    const [t, state, c] = root.splitFields(line);
                    if (state !== "connected")
                        continue;
                    if (t === "ethernet") {
                        type = "ethernet";
                        conn = c;
                        break;
                    }
                    if (t === "wifi" && type === "none") {
                        type = "wifi";
                        conn = c;
                    }
                }
                root.type = type;
                root.connection = conn;
            }
        }
    }

    Process {
        id: wifiProc

        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bySsid = {};
                for (const line of root.lines(text)) {
                    const [inUse, signal, security, ssid] = root.splitFields(line);
                    if (!ssid)
                        continue;
                    const net = {
                        ssid: ssid,
                        signal: parseInt(signal) || 0,
                        security: security === "--" ? "" : security,
                        active: inUse === "*",
                        saved: root.savedNetworks.includes(ssid)
                    };
                    const prev = bySsid[ssid];
                    if (!prev || net.active || (!prev.active && net.signal > prev.signal))
                        bySsid[ssid] = net;
                }
                const nets = Object.values(bySsid).sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.networks = nets;
                const active = nets.find(n => n.active);
                root.strength = active ? active.signal : 0;
            }
        }
    }

    Process {
        id: savedProc

        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.savedNetworks = root.lines(text).map(l => root.splitFields(l)).filter(f => f[1] === "802-11-wireless").map(f => f[0]);
                root.networks = root.networks.map(n => Object.assign({}, n, {
                    saved: root.savedNetworks.includes(n.ssid)
                }));
            }
        }
    }

    Process {
        id: detailsProc

        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.details = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: actionProc

        stderr: StdioCollector {
            id: actionErr
        }
        onExited: code => {
            root.error = code !== 0 ? (actionErr.text.trim().replace(/^Error: /, "") || "Failed") : "";
            debounce.restart();
        }
    }

    Process {
        id: speedProc

        command: [root.script, "speedtest"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.speed = Object.assign({}, root.speed, JSON.parse(line));
                } catch (e) {}
            }
        }
    }

    // rx/tx byte counters of the active interface, once a second
    Process {
        id: rateProc

        property real lastRx: -1
        property real lastTx: -1
        property bool rxNext: true

        running: root.monitoring && (root.details.active?.iface ?? "") !== ""
        command: ["sh", "-c", `while :; do cat /sys/class/net/${root.details.active?.iface}/statistics/rx_bytes /sys/class/net/${root.details.active?.iface}/statistics/tx_bytes; sleep 1; done`]
        onRunningChanged: {
            lastRx = -1;
            lastTx = -1;
            rxNext = true;
        }
        stdout: SplitParser {
            onRead: line => {
                const v = parseFloat(line);
                if (rateProc.rxNext) {
                    if (rateProc.lastRx >= 0)
                        root.rxRate = Math.max(0, v - rateProc.lastRx);
                    rateProc.lastRx = v;
                } else {
                    if (rateProc.lastTx >= 0)
                        root.txRate = Math.max(0, v - rateProc.lastTx);
                    rateProc.lastTx = v;
                }
                rateProc.rxNext = !rateProc.rxNext;
            }
        }
    }

    Process {
        id: scanProc

        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: {
            root.scanning = false;
            wifiProc.running = true;
        }
    }

    Process {
        id: connectProc

        stderr: StdioCollector {
            id: connectErr
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.error = connectErr.text.trim().replace(/^Error: /, "") || "Connection failed";
            root.connectingTo = "";
            root.refresh();
        }
    }
}
