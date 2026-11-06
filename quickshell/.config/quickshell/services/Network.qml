pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

// Network state. Wi-Fi comes straight from NetworkManager over D-Bus (Quickshell.Networking):
// the network list fills in as scans report, and connecting, forgetting and the Wi-Fi switch
// go through it. ~/.config/scripts/network.py has the rest: wired, VPN, DNS, live stats with
// ping, the Wi-Fi band, the QR code and the speed test.
//
// Modeled on Omarchy's network panel (shell/plugins/panels/network,
// github.com/basecamp/omarchy, MIT): rows sorted connected, known, other, the scanner on only
// while the dropdown is open, connection failures read from NetworkManager's reasons.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/scripts/network.py"

    // ---------------------------------------------------------------- devices

    // Quickshell's object lists index like arrays but aren't iterable: copied into arrays
    function array(list: var): var {
        const out = [];
        for (let i = 0; i < (list?.length ?? 0); i++)
            out.push(list[i]);
        return out;
    }

    readonly property var devices: array(Networking.devices?.values)
    // A connected device first: an idle port can sit next to the one in use
    function findDevice(type: int): var {
        let fallback = null;
        for (let i = 0; i < (devices?.length ?? 0); i++) {
            const d = devices[i];
            if (d?.type !== type)
                continue;
            if (d.connected)
                return d;
            fallback = fallback ?? d;
        }
        return fallback;
    }
    readonly property var wifiDevice: findDevice(DeviceType.Wifi)
    readonly property var wiredDevice: findDevice(DeviceType.Wired)
    readonly property bool hasWifi: wifiDevice !== null
    readonly property var wifiNetworkObjects: array(wifiDevice?.networks?.values)
    readonly property var connectedWifi: {
        for (let i = 0; i < (wifiNetworkObjects?.length ?? 0); i++) {
            if (wifiNetworkObjects[i]?.connected)
                return wifiNetworkObjects[i];
        }
        return null;
    }

    // ---------------------------------------------------------------- summary (bar, Control Center)

    readonly property bool wifiEnabled: Networking.wifiEnabled
    // "ethernet" | "wifi" | "none"; wired wins when both are up, like the default route
    readonly property string type: wiredDevice?.connected ? "ethernet" : ((connectedWifi || wifiDevice?.connected) ? "wifi" : "none")
    readonly property string connection: type === "ethernet" ? (wiredDevice?.network?.name || details.active?.connection || "Wired") : type === "wifi" ? (connectedWifi?.name || details.active?.connection || "Wi-Fi") : ""
    // The connected network's strength; between scans some networks report none, then
    // the access point in use is read from nmcli
    property int apSignal: 0
    readonly property int strength: type !== "wifi" ? 0 : (Math.round((connectedWifi?.signalStrength ?? 0) * 100) || apSignal)

    // NetworkManager's own connectivity check: a captive portal or no internet behind the link
    readonly property string connectivity: {
        if (type === "none")
            return "none";
        if (!Networking.canCheckConnectivity || !Networking.connectivityCheckEnabled)
            return "unknown";
        switch (Networking.connectivity) {
        case NetworkConnectivity.Portal:
            return "portal";
        case NetworkConnectivity.Limited:
            return "limited";
        case NetworkConnectivity.Full:
            return "full";
        case NetworkConnectivity.None:
            return "none";
        }
        return "unknown";
    }
    readonly property bool restricted: connectivity === "portal" || connectivity === "limited"

    readonly property string tooltip: {
        const lines = ["Network"];
        if (type === "ethernet")
            lines.push(`Wired: ${connection}`);
        else if (type === "wifi")
            lines.push(`Wi-Fi: ${connection}`, `Signal ${strength}%`);
        else
            lines.push(wifiEnabled ? "Not connected" : "Wi-Fi off");
        if (connectivity === "portal")
            lines.push("Sign-in required");
        else if (connectivity === "limited")
            lines.push("Limited internet access");
        for (const v of activeVpns)
            lines.push(`VPN: ${v.name}`);
        return lines.join("\n");
    }

    function wifiIcon(signal: int): string {
        return Icons.wifiLevels[Math.max(0, Math.min(4, Math.ceil(signal / 20) - 1))];
    }

    readonly property string icon: {
        if (type === "ethernet")
            return restricted ? Icons.ethernetOff : Icons.ethernet;
        if (type === "wifi")
            return restricted ? Icons.wifiAlert : wifiIcon(strength);
        return Icons.wifiOff;
    }

    function setWifiEnabled(on: bool): void {
        Networking.wifiEnabled = on;
    }

    // ---------------------------------------------------------------- Wi-Fi list

    // Plain values only: a WifiNetwork can be destroyed by a scan while a delegate still
    // holds it. networkFor(ssid) looks the live object up when acting on a row.
    property var networks: [] // { ssid, signal, security, secured, connected, known }
    property bool scanning: false

    function networkFor(ssid: string): var {
        for (let i = 0; i < (wifiNetworkObjects?.length ?? 0); i++) {
            if (wifiNetworkObjects[i]?.name === ssid)
                return wifiNetworkObjects[i];
        }
        return null;
    }

    function requiresCredentials(security: int): bool {
        // only the explicitly passwordless types skip the prompt
        return security !== WifiSecurityType.Open && security !== WifiSecurityType.Owe;
    }

    function isEnterprise(security: int): bool {
        return security === WifiSecurityType.Wpa2Eap || security === WifiSecurityType.WpaEap;
    }

    function syncNetworks(): void {
        const rows = [];
        for (let i = 0; i < (wifiNetworkObjects?.length ?? 0); i++) {
            const n = wifiNetworkObjects[i];
            if (!n)
                continue;
            checkAction(n);
            rows.push({
                ssid: n.name || "",
                signal: Math.round((n.signalStrength || 0) * 100),
                security: n.security,
                secured: requiresCredentials(n.security),
                connected: !!n.connected,
                known: !!n.known
            });
        }
        rows.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signal - a.signal));
        networks = rows;
    }

    // a scan's results came in
    onWifiNetworkObjectsChanged: {
        syncNetworks();
        scanning = false;
    }
    onWifiDeviceChanged: {
        apSignal = 0;
        syncNetworks();
        updateScanner();
    }

    // Each network's own changes (signal, connected, known) don't change the list itself
    Instantiator {
        model: root.wifiNetworkObjects

        delegate: Connections {
            required property var modelData

            target: modelData

            function onSignalStrengthChanged(): void {
                rowsDelay.restart();
            }

            function onConnectedChanged(): void {
                root.checkAction(modelData);
                rowsDelay.restart();
            }

            function onKnownChanged(): void {
                root.checkAction(modelData);
                rowsDelay.restart();
            }

            function onStateChangingChanged(): void {
                root.checkAction(modelData);
            }

            function onConnectionFailed(reason: int): void {
                root.failAction(modelData, reason);
            }
        }
    }

    Timer {
        id: rowsDelay

        interval: 150
        onTriggered: root.syncNetworks()
    }

    // ---------------------------------------------------------------- scanning

    // While a network dropdown is open (on any monitor): the scanner runs, stats are polled
    readonly property bool monitoring: Panels.dropdown === "network"
    property var scannerDevice: null

    function updateScanner(): void {
        const next = monitoring ? wifiDevice : null;
        if (scannerDevice && scannerDevice !== next)
            scannerDevice.scannerEnabled = false;
        scannerDevice = next;
        if (scannerDevice)
            scannerDevice.scannerEnabled = true;
    }

    // A fresh scan: the scanner off and on again; "scanning" until the list changes, at most 5 s
    function scan(): void {
        if (!wifiDevice || !wifiEnabled)
            return;
        scanning = true;
        if (scannerDevice)
            scannerDevice.scannerEnabled = false;
        scanRestart.restart();
    }

    onMonitoringChanged: {
        if (monitoring) {
            refresh();
            scan();
        } else {
            scanRestart.stop();
            updateScanner();
            resetStats();
        }
    }

    Timer {
        id: scanRestart

        interval: 100
        onTriggered: {
            root.updateScanner();
            scanDone.restart();
        }
    }

    Timer {
        id: scanDone

        interval: 5000
        onTriggered: {
            root.syncNetworks();
            root.scanning = false;
        }
    }

    // ---------------------------------------------------------------- connecting

    // One action at a time: { kind: "connect" | "disconnect" | "forget", ssid }
    property string actionKind: ""
    property string actionSsid: ""
    property string failureSsid: ""
    property string failureReason: ""
    // The row whose password field should open (after NoSecrets or a wrong password)
    property string promptSsid: ""
    readonly property bool busy: actionKind !== ""

    function startAction(kind: string, ssid: string, run: var): void {
        const network = networkFor(ssid);
        if (busy || !network)
            return;
        actionKind = kind;
        actionSsid = ssid;
        failureSsid = "";
        failureReason = "";
        run(network);
        actionTimeout.restart();
    }

    function clearAction(): void {
        actionTimeout.stop();
        actionKind = "";
        actionSsid = "";
        rowsDelay.restart();
    }

    function checkAction(network: var): void {
        if (!network || !busy || actionSsid !== network.name)
            return;
        if (actionKind === "connect" && network.connected)
            clearAction();
        else if (actionKind === "disconnect" && !network.connected && !network.stateChanging)
            clearAction();
        else if (actionKind === "forget" && !network.known && !network.stateChanging)
            clearAction();
    }

    function failAction(network: var, reason: int): void {
        if (!network || actionSsid !== network.name)
            return;
        const credentials = requiresCredentials(network.security);
        failureSsid = actionSsid;
        failureReason = failureText(reason, credentials);
        // a missing or wrong password: ask for it (again)
        if (credentials && (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout))
            promptSsid = actionSsid;
        clearAction();
    }

    function failureText(reason: int, credentials: bool): string {
        if (credentials && reason === ConnectionFailReason.NoSecrets)
            return "Password required";
        if (credentials && reason === ConnectionFailReason.WifiAuthTimeout)
            return "Wrong password";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "Network lost";
        if (reason === ConnectionFailReason.WifiClientDisconnected)
            return "Disconnected";
        if (reason === ConnectionFailReason.WifiClientFailed)
            return "Connection failed";
        return "Failed to connect";
    }

    function connect(ssid: string): void {
        startAction("connect", ssid, n => n.connect());
    }

    function connectWithPassword(ssid: string, password: string): void {
        startAction("connect", ssid, n => n.connectWithPsk(password));
    }

    // WPA-Enterprise: network.py makes the profile, the password on stdin
    function connectEnterprise(ssid: string, identity: string, password: string): void {
        startAction("connect", ssid, n => {
            eapProc.secret = password;
            eapProc.command = [root.script, "eap", ssid, identity];
            eapProc.running = true;
        });
    }

    function disconnect(ssid: string): void {
        startAction("disconnect", ssid, n => n.disconnect());
    }

    function forget(ssid: string): void {
        startAction("forget", ssid, n => n.forget());
    }

    // NetworkManager gives up on a wrong saved password after 25 s; wait longer than that
    Timer {
        id: actionTimeout

        interval: 30000
        onTriggered: {
            root.failureSsid = root.actionSsid;
            root.failureReason = root.actionKind === "connect" ? "Timed out connecting" : root.actionKind === "disconnect" ? "Timed out disconnecting" : "Timed out forgetting";
            root.clearAction();
        }
    }

    Process {
        id: eapProc

        property string secret: ""

        stdinEnabled: true
        onStarted: {
            write(secret + "\n");
            secret = "";
        }
        stderr: StdioCollector {
            id: eapErr
        }
        onExited: code => {
            if (code !== 0 && root.actionKind === "connect") {
                root.failureSsid = root.actionSsid;
                root.failureReason = eapErr.text.trim().replace(/^Error: /, "") || "Connection failed";
                root.clearAction();
            }
        }
    }

    // ---------------------------------------------------------------- wired, VPN, DNS (network.py status)

    property string error: ""
    // { wired, vpns, wireguardFiles, active, dns }
    property var details: ({ wired: [], vpns: [], wireguardFiles: [], active: null, dns: { mode: "auto", servers: [] } })
    readonly property var activeVpns: (details.vpns ?? []).filter(v => v.active)

    function refresh(): void {
        detailsProc.running = true;
        if (monitoring) {
            statsProc.running = true;
            bandProc.running = true;
        }
        if (type === "wifi" && strength === 0)
            apSignalProc.running = true;
        if (Networking.canCheckConnectivity && Networking.connectivityCheckEnabled && type !== "none")
            Networking.checkConnectivity();
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

    // The pill shows the choice at once; it falls back if setting it fails
    property string pendingDns: ""
    readonly property string dnsMode: pendingDns || (details.dns?.mode ?? "auto")

    function setDns(mode: string, servers: string): void {
        pendingDns = mode;
        run(mode === "custom" ? ["dns", "custom", servers] : ["dns", mode]);
    }

    Component.onCompleted: refresh()

    // NetworkManager state changes (VPN up, cable in) refresh the details
    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce

        interval: 500
        onTriggered: root.refresh()
    }

    onTypeChanged: {
        apSignal = 0;
        debounce.restart();
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
            root.pendingDns = "";
            debounce.restart();
        }
    }

    // Strength of the access point in use, for a connected network that reports none
    Process {
        id: apSignalProc

        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/^\*:(\d+)$/m);
                root.apSignal = m ? parseInt(m[1]) : 0;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.type === "wifi" && Math.round((root.connectedWifi?.signalStrength ?? 0) * 100) === 0
        onTriggered: apSignalProc.running = true
    }

    // ---------------------------------------------------------------- live stats (network.py stats)

    // { iface, type, ip, prefix, gateway, rx_bytes, tx_bytes, router_ping_ms, internet_ping_ms }
    property var stats: ({})
    property real rxRate: 0 // bytes/s
    property real txRate: 0
    property var lastSample: null // { iface, rx, tx, time }
    // Last pings to 1.1.1.1, null for a lost one: ping is the average of the last 5, loss
    // counts all of them
    property var pings: []
    readonly property bool hasStats: stats.rx_bytes !== undefined
    readonly property bool hasPing: pings.length > 0 && connectivity !== "portal" && connectivity !== "limited" && connectivity !== "none"
    readonly property real ping: {
        const recent = pings.slice(-5).filter(p => p !== null);
        return recent.length ? recent.reduce((a, b) => a + b, 0) / recent.length : -1;
    }
    readonly property int packetLoss: pings.length ? Math.round(pings.filter(p => p === null).length * 100 / pings.length) : 0

    function resetStats(): void {
        lastSample = null;
        rxRate = 0;
        txRate = 0;
        pings = [];
    }

    function takeStats(next: var): void {
        const now = Date.now() / 1000;
        if (!next.iface || next.iface !== lastSample?.iface) {
            rxRate = 0;
            txRate = 0;
            pings = [];
        } else if (now > lastSample.time) {
            rxRate = Math.max(0, (next.rx_bytes - lastSample.rx) / (now - lastSample.time));
            txRate = Math.max(0, (next.tx_bytes - lastSample.tx) / (now - lastSample.time));
        }
        lastSample = next.iface ? { iface: next.iface, rx: next.rx_bytes, tx: next.tx_bytes, time: now } : null;
        if (next.iface && "internet_ping_ms" in next)
            pings = pings.concat([next.internet_ping_ms]).slice(-24);
        stats = next;
    }

    Process {
        id: statsProc

        command: [root.script, "stats"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.takeStats(JSON.parse(text));
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.monitoring
        onTriggered: if (!statsProc.running) statsProc.running = true
    }

    function formatBytes(bytes: real): string {
        const n = Math.max(0, bytes || 0);
        if (n < 1024)
            return `${Math.round(n)} B`;
        if (n < 1024 ** 2)
            return `${(n / 1024).toFixed(1)} KB`;
        if (n < 1024 ** 3)
            return `${(n / 1024 ** 2).toFixed(1)} MB`;
        return `${(n / 1024 ** 3).toFixed(2)} GB`;
    }

    function formatRate(bytes: real): string {
        return formatBytes(bytes) + "/s";
    }

    // ---------------------------------------------------------------- Wi-Fi band (network.py band)

    property string bandCurrent: "" // "2.4" | "5" | "6"
    property string bandSelected: "auto"
    property var bandAvailable: []
    property string pendingBand: ""
    readonly property bool bandBusy: pendingBand !== ""
    readonly property string bandEffective: pendingBand || bandSelected
    readonly property bool bandPinned: bandEffective !== "auto"
    // Worth showing with a real choice, or with a pin in force (so it can be cleared)
    readonly property bool canSelectBand: (type === "wifi" || bandBusy) && (bandAvailable.length > 1 || bandPinned)

    function setBand(band: string): void {
        if (bandBusy || band === bandEffective)
            return;
        pendingBand = band;
        bandSetProc.command = [script, "band", band];
        bandSetProc.running = true;
    }

    Process {
        id: bandProc

        command: [root.script, "band"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const b = JSON.parse(text);
                    // mid-reconnect nothing is connected: keep what was shown
                    if (root.bandBusy && !b.band)
                        return;
                    root.bandCurrent = b.band ?? "";
                    root.bandSelected = b.selected ?? "auto";
                    root.bandAvailable = b.available ?? [];
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.monitoring
        onTriggered: if (!bandProc.running) bandProc.running = true
    }

    Process {
        id: bandSetProc

        stderr: StdioCollector {
            id: bandErr
        }
        onExited: code => {
            root.error = code !== 0 ? bandErr.text.trim() : "";
            if (code === 0)
                root.bandSelected = root.pendingBand;
            root.pendingBand = "";
            root.refresh();
        }
    }

    // ---------------------------------------------------------------- speed test (network.py speedtest)

    // { phase: "ping" | "download" | "upload" | "done" | "error", ping, jitter, download, upload, message }
    property var speed: ({})
    readonly property bool testing: speedProc.running

    function startSpeedtest(): void {
        if (speedProc.running)
            return;
        speed = { phase: "ping" };
        speedProc.running = true;
    }

    function stopSpeedtest(): void {
        speedProc.running = false;
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
}
