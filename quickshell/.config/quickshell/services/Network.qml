pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// NetworkManager state through nmcli. `nmcli monitor` triggers refreshes.
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
