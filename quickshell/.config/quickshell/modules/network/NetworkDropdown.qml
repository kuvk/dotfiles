import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Network: the connection with its live stats, the Wi-Fi band, DNS, VPNs, wired ports and
// the Wi-Fi networks (connected, known, other), with buttons for the Wi-Fi QR code and the
// speed test.
//
// The layout and behavior follow Omarchy's network panel (shell/plugins/panels/network,
// github.com/basecamp/omarchy, MIT), in this shell's style.
Dropdown {
    id: root

    name: "network"
    // wide enough for the stats grid, or the DNS choices on one line
    contentWidth: Math.max(400, dnsRowWidth + Theme.padding * 2)

    // SSID whose password field is open
    property string passwordSsid: ""
    property string passwordText: ""
    property string identityText: ""
    property string customDns: ""

    readonly property var dnsChoices: [
        { id: "auto", label: "Automatic" },
        { id: "cloudflare", label: "Cloudflare" },
        { id: "google", label: "Google" },
        { id: "quad9", label: "Quad9" },
        { id: "custom", label: "Custom" }
    ]

    readonly property int dnsRowWidth: {
        // advanceWidth() alone doesn't update when the font changes
        dnsMetrics.font;
        return dnsChoices.reduce((sum, choice) => sum + Math.ceil(dnsMetrics.advanceWidth(choice.label)) + 20 + 6, -6);
    }

    FontMetrics {
        id: dnsMetrics

        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
    }

    // Omarchy's lines under a working connection, one every few seconds
    readonly property var phrases: ["Wiring bits", "Handling packets", "Sorting frames", "Hauling bytes", "Routing crumbs", "Counting collisions", "Bending light"]
    property int phrase: 0

    readonly property bool canShareWifi: Network.type === "wifi" && Network.connectedWifi !== null && !Network.isEnterprise(Network.connectedWifi.security)

    function openPassword(ssid: string): void {
        if (passwordSsid !== ssid) {
            passwordText = "";
            identityText = "";
        }
        passwordSsid = ssid;
    }

    function closePassword(): void {
        passwordSsid = "";
        passwordText = "";
        identityText = "";
    }

    function activate(net: var): void {
        if (Network.busy)
            return;
        if (net.connected)
            Network.disconnect(net.ssid);
        else if (net.secured && !net.known)
            passwordSsid === net.ssid ? closePassword() : openPassword(net.ssid);
        else
            Network.connect(net.ssid);
    }

    function submitPassword(net: var): void {
        if (Network.busy || passwordText === "")
            return;
        if (!Network.isEnterprise(net.security))
            Network.connectWithPassword(net.ssid, passwordText);
        else if (identityText !== "")
            Network.connectEnterprise(net.ssid, identityText, passwordText);
        else
            return;
        passwordText = "";
    }

    function formatPing(ms: real): string {
        if (!Network.hasPing)
            return "--";
        if (ms < 0)
            return "Timeout";
        return `${ms > 0 && ms < 10 ? ms.toFixed(1) : Math.round(ms)} ms`;
    }

    onShownChanged: {
        closePassword();
        Network.promptSsid = "";
        Network.failureSsid = "";
        customDns = "";
    }

    // A wrong or missing password opens that network's field again
    Connections {
        target: Network

        function onPromptSsidChanged(): void {
            if (Network.promptSsid !== "" && root.shown)
                root.openPassword(Network.promptSsid);
        }

        function onActionKindChanged(): void {
            if (Network.actionKind === "" && Network.failureSsid === "" && root.passwordSsid !== "" && Network.networkFor(root.passwordSsid)?.connected)
                root.closePassword();
        }
    }

    Timer {
        interval: 2800
        repeat: true
        running: root.shown && Network.type !== "none" && !Network.restricted
        onTriggered: phraseFade.restart()
    }

    SequentialAnimation {
        id: phraseFade

        NumberAnimation {
            target: hero.statusItem
            property: "opacity"
            to: 0
            duration: Theme.animDuration
        }

        ScriptAction {
            script: root.phrase = (root.phrase + 1) % root.phrases.length
        }

        NumberAnimation {
            target: hero.statusItem
            property: "opacity"
            to: 1
            duration: Theme.animDuration * 1.3
        }
    }

    // ---------------------------------------------------------------- the connection

    Hero {
        id: hero

        icon: Network.icon
        iconColor: Network.restricted ? Theme.red : (Network.type !== "none" ? Theme.highlight : Theme.overlay1)
        title: {
            if (Network.type === "wifi")
                return Network.connection;
            if (Network.type === "ethernet") {
                const speed = Network.wiredDevice?.linkSpeed ?? 0;
                return speed > 0 ? `Ethernet (${speed >= 1000 ? `${speed / 1000} Gb/s` : `${speed} Mb/s`})` : "Ethernet";
            }
            return "Disconnected";
        }
        status: {
            if (Network.connectivity === "portal")
                return "SIGN-IN REQUIRED";
            if (Network.restricted)
                return "LIMITED INTERNET ACCESS";
            if (Network.type !== "none")
                return root.phrases[root.phrase].toUpperCase();
            return Network.hasWifi && !Network.wifiEnabled ? "WI-FI IS OFF" : "NOT CONNECTED";
        }
        statusColor: Network.restricted ? Theme.red : Theme.subtext0

        IconButton {
            visible: root.canShareWifi
            icon: Icons.qrcode
            color: Theme.subtext0
            onClicked: Panels.toggleWifiQr()
        }

        IconButton {
            visible: (Network.stats.iface ?? "") !== ""
            icon: Icons.speedometer
            color: Theme.subtext0
            onClicked: Panels.toggleSpeedTest()
        }

        Switch {
            visible: Network.hasWifi
            checked: Network.wifiEnabled
            onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
        }
    }

    // NetworkManager found a login page between the link and the internet
    TextButton {
        Layout.fillWidth: true
        visible: Network.connectivity === "portal"
        text: `${Icons.web}  Sign in to the network`
        primary: true
        onClicked: {
            Panels.closeDropdown(root.name);
            Quickshell.execDetached(["xdg-open", "http://ping.archlinux.org/nm-check.txt"]);
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Network.error !== ""
        text: Network.error
        color: Theme.red
        wrapMode: Text.Wrap
    }

    // Every row stays while waiting for numbers ("--"), so nothing moves when they arrive
    GridLayout {
        Layout.fillWidth: true
        visible: (Network.stats.iface ?? "") !== ""
        columns: 4
        columnSpacing: 12
        rowSpacing: 4

        Label {
            text: "Ping"
        }

        Value {
            text: root.formatPing(Network.ping)
            color: Network.hasPing && Network.packetLoss > 0 ? Theme.red : Theme.text
        }

        Label {
            text: "Packet loss"
        }

        Value {
            text: Network.hasPing ? `${Network.packetLoss}%` : "--"
            color: Network.hasPing && Network.packetLoss > 0 ? Theme.red : Theme.text
        }

        Label {
            text: "Receiving"
        }

        Value {
            text: Network.hasStats && Network.lastSample ? Network.formatRate(Network.rxRate) : "--"
        }

        Label {
            text: "Sending"
        }

        Value {
            text: Network.hasStats && Network.lastSample ? Network.formatRate(Network.txRate) : "--"
        }

        Label {
            text: "Downloaded"
        }

        Value {
            text: Network.hasStats ? Network.formatBytes(Network.stats.rx_bytes) : "--"
        }

        Label {
            text: "Uploaded"
        }

        Value {
            text: Network.hasStats ? Network.formatBytes(Network.stats.tx_bytes) : "--"
        }

        Label {
            text: "IP address"
        }

        Value {
            text: Network.stats.ip || "--"
            copyable: true
        }

        Label {
            text: "Gateway"
        }

        Value {
            text: Network.stats.gateway || "--"
            copyable: true
        }
    }

    // ---------------------------------------------------------------- Wi-Fi band

    Separator {
        visible: Network.canSelectBand
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Network.canSelectBand

        Caption {
            Layout.fillWidth: true
            // under Automatic the header names the band in use; a pin shows in the buttons
            text: !Network.bandPinned && Network.bandCurrent ? `WI-FI BAND: ${Network.bandCurrent} GHZ` : "WI-FI BAND"
        }

        Caption {
            text: "AUTOMATIC"
        }

        Switch {
            checked: !Network.bandPinned
            opacity: Network.bandBusy ? 0.5 : 1
            onToggled: Network.setBand(Network.bandPinned ? "auto" : (Network.bandCurrent || Network.bandAvailable[0]))
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Network.canSelectBand && Network.bandPinned
        spacing: 6

        Repeater {
            model: Network.bandAvailable

            Chip {
                required property string modelData

                text: `${modelData} GHz`
                current: Network.bandEffective === modelData
                onClicked: Network.setBand(modelData)
            }
        }
    }

    // ---------------------------------------------------------------- DNS

    Separator {}

    Caption {
        text: "DNS"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: root.dnsChoices

            Chip {
                required property var modelData

                text: modelData.label
                current: Network.dnsMode === modelData.id
                onClicked: {
                    if (modelData.id === "custom")
                        root.customDns = current ? (Network.details.dns?.servers ?? []).join(" ") : " ";
                    else
                        Network.setDns(modelData.id, "");
                }
            }
        }
    }

    InputField {
        visible: root.customDns !== ""
        placeholder: "Servers, e.g. 1.1.1.1 9.9.9.9 (Enter)"
        text: root.customDns.trim()
        active: visible
        onAccepted: value => {
            if (value.trim() !== "")
                Network.setDns("custom", value.trim());
            root.customDns = "";
        }
        onCanceled: root.customDns = ""
    }

    // ---------------------------------------------------------------- VPN

    Separator {
        visible: vpnSection.visible
    }

    ColumnLayout {
        id: vpnSection

        Layout.fillWidth: true
        visible: (Network.details.vpns ?? []).length > 0 || (Network.details.wireguardFiles ?? []).length > 0
        spacing: 2

        Caption {
            text: "VPN"
        }

        Repeater {
            model: Network.details.vpns ?? []

            ListItem {
                id: vpn

                required property var modelData

                icon: Icons.shield
                label: modelData.name
                sublabel: (modelData.type === "wireguard" ? "WireGuard" : "VPN") + (modelData.active ? " · Connected" : "")
                highlighted: modelData.active
                onClicked: Network.setVpn(modelData.name, !modelData.active)

                IconButton {
                    visible: !vpn.modelData.active && vpn.containsMouse
                    icon: Icons.closeCircle
                    color: Theme.red
                    size: 26
                    onClicked: Network.deleteVpn(vpn.modelData.name)
                }

                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: vpn.modelData.active
                    onToggled: Network.setVpn(vpn.modelData.name, !vpn.modelData.active)
                }
            }
        }

        Repeater {
            model: Network.details.wireguardFiles ?? []

            ListItem {
                required property string modelData

                icon: Icons.plus
                label: `Import ${modelData.slice(modelData.lastIndexOf("/") + 1)}`
                sublabel: modelData.slice(0, modelData.lastIndexOf("/")).replace(/^\/home\/[^/]+/, "~")
                implicitHeight: 40
                onClicked: Network.importVpn(modelData)
            }
        }
    }

    // ---------------------------------------------------------------- wired ports with a cable

    Separator {
        visible: wiredSection.visible
    }

    ColumnLayout {
        id: wiredSection

        readonly property var ports: (Network.details.wired ?? []).filter(w => w.state !== "unavailable")

        Layout.fillWidth: true
        visible: ports.length > 0
        spacing: 2

        Caption {
            text: "WIRED"
        }

        Repeater {
            model: wiredSection.ports

            ListItem {
                id: wired

                required property var modelData
                readonly property bool connected: modelData.state === "connected"

                icon: Icons.ethernet
                label: modelData.connection || modelData.iface
                sublabel: connected ? `Connected · ${modelData.iface}` : `Disconnected · ${modelData.iface}`
                highlighted: connected
                onClicked: Network.setWired(modelData.iface, !connected)

                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: wired.connected
                    onToggled: Network.setWired(wired.modelData.iface, !wired.connected)
                }
            }
        }
    }

    // ---------------------------------------------------------------- Wi-Fi networks

    Separator {
        visible: Network.hasWifi && Network.wifiEnabled
    }

    Caption {
        visible: Network.hasWifi && Network.wifiEnabled && (Network.scanning || Network.networks.length === 0)
        text: Network.scanning ? "SCANNING WI-FI…" : "NO NETWORKS FOUND"
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: Math.min(rows.implicitHeight, 300)
        visible: Network.hasWifi && Network.wifiEnabled && Network.networks.length > 0

        Flickable {
            id: networkList

            anchors.fill: parent
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: rows

                width: networkList.width
                spacing: 2

                Repeater {
                    model: Network.networks

                    WifiRow {
                        dropdown: root
                    }
                }
            }
        }

        ScrollBar {
            flick: networkList
        }
    }

    FooterLink {
        text: "Connection editor"
        onClicked: {
            Panels.dropdown = "";
            System.run(["nm-connection-editor"]);
        }
    }
}
