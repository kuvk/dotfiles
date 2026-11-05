import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Network: Wi-Fi, wired, VPN (WireGuard and NetworkManager VPNs) and tools
// (details, live throughput, DNS, speed test).
Popout {
    id: root

    name: "network"
    contentWidth: 380

    property string tab: "wifi"
    // SSID whose password field is open
    property string askPassword: ""
    property string customDns: ""

    readonly property var tabs: [
        { id: "wifi", label: "Wi-Fi", icon: Icons.wifiLevels[4] },
        { id: "wired", label: "Wired", icon: Icons.ethernet },
        { id: "vpn", label: "VPN", icon: Icons.shield },
        { id: "tools", label: "Tools", icon: Icons.gauge }
    ]

    onShownChanged: {
        askPassword = "";
        Network.monitoring = shown;
        if (shown) {
            tab = Network.type === "ethernet" ? "wired" : "wifi";
            Network.refresh();
            Network.scan();
        }
    }

    SectionHeader {
        title: "Network"

        IconButton {
            icon: Icons.refresh
            color: Network.scanning ? Theme.highlight : Theme.subtext0
            onClicked: {
                Network.refresh();
                Network.scan();
            }
        }
    }

    // Tabs
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: root.tabs

            MouseArea {
                id: tabButton

                required property var modelData
                readonly property bool current: root.tab === modelData.id

                Layout.fillWidth: true
                implicitHeight: 32
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.tab = modelData.id

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.smallRadius
                    color: tabButton.current ? Theme.alpha(Theme.highlight, 0.2) : (tabButton.containsMouse ? Theme.hoverBg : "transparent")
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        text: tabButton.modelData.icon
                        color: tabButton.current ? Theme.highlight : Theme.subtext0
                        font.pixelSize: Theme.iconSize - 1
                    }

                    StyledText {
                        text: tabButton.modelData.label
                        color: tabButton.current ? Theme.highlight : Theme.text
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Network.error !== ""
        text: Network.error
        color: Theme.red
        wrapMode: Text.Wrap
    }

    // ---------------------------------------------------------------- Wi-Fi
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "wifi"
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: Network.wifiEnabled ? "Wi-Fi is on" : "Wi-Fi is off"
                color: Theme.subtext0
            }

            Switch {
                checked: Network.wifiEnabled
                onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 320)
            visible: Network.wifiEnabled
            contentHeight: list.implicitHeight
            clip: true

            ColumnLayout {
                id: list

                width: parent.width
                spacing: 2

                Repeater {
                    model: Network.networks

                    ColumnLayout {
                        id: net

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 4

                        ListItem {
                            icon: Icons.wifiLevels[Math.min(4, Math.floor(net.modelData.signal / 20))]
                            label: net.modelData.ssid
                            sublabel: Network.connectingTo === net.modelData.ssid ? "Connecting…" : net.modelData.active ? "Connected" : net.modelData.saved ? "Saved" : (net.modelData.security || "Open")
                            highlighted: net.modelData.active
                            onClicked: {
                                if (net.modelData.active)
                                    Network.disconnect();
                                else if (net.modelData.saved || !net.modelData.security)
                                    Network.connect(net.modelData.ssid, "");
                                else
                                    root.askPassword = root.askPassword === net.modelData.ssid ? "" : net.modelData.ssid;
                            }

                            Icon {
                                visible: net.modelData.security !== ""
                                text: Icons.lock
                                color: Theme.overlay1
                                font.pixelSize: 11
                                width: 20
                                height: 30
                            }

                            IconButton {
                                visible: net.modelData.saved && !net.modelData.active
                                icon: Icons.trash
                                color: Theme.overlay1
                                size: 26
                                onClicked: Network.forget(net.modelData.ssid)
                            }
                        }

                        PasswordField {
                            visible: root.askPassword === net.modelData.ssid
                            active: visible
                            onAccepted: password => {
                                Network.connect(net.modelData.ssid, password);
                                root.askPassword = "";
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- Wired
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "wired"
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            visible: (Network.details.wired ?? []).length === 0
            text: "No wired network adapter"
            color: Theme.subtext0
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: Network.details.wired ?? []

            ListItem {
                id: wired

                required property var modelData
                readonly property bool connected: modelData.state === "connected"

                icon: Icons.ethernet
                label: modelData.connection || modelData.iface
                sublabel: connected ? `Connected · ${modelData.iface}` : modelData.state === "unavailable" ? "Cable unplugged" : "Disconnected"
                highlighted: connected
                cursorShape: Qt.ArrowCursor

                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: wired.connected
                    enabled: wired.modelData.state !== "unavailable"
                    onToggled: Network.setWired(wired.modelData.iface, !wired.connected)
                }
            }
        }
    }

    // ---------------------------------------------------------------- VPN
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "vpn"
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            visible: (Network.details.vpns ?? []).length === 0 && (Network.details.wireguardFiles ?? []).length === 0
            text: "No VPNs yet. Put WireGuard .conf files in\n~/.config/wireguard or ~/Downloads to import them."
            color: Theme.subtext0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
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
                    visible: !vpn.modelData.active
                    icon: Icons.trash
                    color: Theme.overlay1
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

        StyledText {
            Layout.topMargin: 6
            visible: (Network.details.wireguardFiles ?? []).length > 0
            text: "Import WireGuard config"
            color: Theme.subtext0
            font.pixelSize: Theme.fontSize - 1
        }

        Repeater {
            model: Network.details.wireguardFiles ?? []

            ListItem {
                required property string modelData

                icon: Icons.plus
                label: modelData.slice(modelData.lastIndexOf("/") + 1)
                sublabel: modelData.slice(0, modelData.lastIndexOf("/")).replace(/^\/home\/[^/]+/, "~")
                implicitHeight: 40
                onClicked: Network.importVpn(modelData)
            }
        }
    }

    // ---------------------------------------------------------------- Tools
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "tools"
        spacing: Theme.spacing

        readonly property var active: Network.details.active

        StyledText {
            visible: parent.active === null
            text: "Not connected"
            color: Theme.subtext0
        }

        // Details and live throughput
        GridLayout {
            Layout.fillWidth: true
            visible: parent.active !== null
            columns: 2
            columnSpacing: 12
            rowSpacing: 4

            Repeater {
                model: {
                    const a = Network.details.active;
                    if (!a)
                        return [];
                    const rows = [
                        ["Connection", `${a.connection} (${a.iface})`],
                        ["IP address", a.ip4 || "—"],
                        ["Gateway", a.gateway || "—"],
                        ["DNS", (a.dns ?? []).join(", ") || "—"]
                    ];
                    if (a.link_speed)
                        rows.push(["Link speed", `${a.link_speed} Mb/s`]);
                    if (a.type === "wifi")
                        rows.push(["Signal", `${Network.strength}%`]);
                    rows.push(["Download", Network.formatRate(Network.rxRate)], ["Upload", Network.formatRate(Network.txRate)]);
                    return rows;
                }

                Item {
                    required property var modelData
                    required property int index

                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    implicitHeight: 20

                    StyledText {
                        anchors.left: parent.left
                        text: parent.modelData[0]
                        color: Theme.overlay1
                    }

                    StyledText {
                        anchors.right: parent.right
                        width: Math.min(implicitWidth, parent.width - 110)
                        horizontalAlignment: Text.AlignRight
                        text: parent.modelData[1]
                    }
                }
            }
        }

        // DNS
        StyledText {
            Layout.topMargin: 4
            text: "DNS"
            color: Theme.subtext0
            font.pixelSize: Theme.fontSize - 1
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { id: "auto", label: "Automatic" },
                    { id: "cloudflare", label: "Cloudflare" },
                    { id: "google", label: "Google" },
                    { id: "quad9", label: "Quad9" },
                    { id: "custom", label: "Custom" }
                ]

                MouseArea {
                    id: dnsChip

                    required property var modelData
                    readonly property bool current: (Network.details.dns?.mode ?? "auto") === modelData.id

                    width: dnsLabel.implicitWidth + 20
                    height: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.id === "custom")
                            root.customDns = current ? (Network.details.dns.servers ?? []).join(" ") : " ";
                        else
                            Network.setDns(modelData.id, "");
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: dnsChip.current ? Theme.alpha(Theme.highlight, 0.25) : (dnsChip.containsMouse ? Theme.hoverBg : Theme.cardBg)
                        border.color: dnsChip.current ? Theme.highlight : "transparent"
                        border.width: Theme.borderWidth
                    }

                    StyledText {
                        id: dnsLabel

                        anchors.centerIn: parent
                        text: dnsChip.modelData.label
                        color: dnsChip.current ? Theme.highlight : Theme.text
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.customDns !== ""
            implicitHeight: 34
            radius: Theme.smallRadius
            color: Theme.cardBg
            border.color: dnsInput.activeFocus ? Theme.highlight : "transparent"
            border.width: Theme.borderWidth

            TextInput {
                id: dnsInput

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                clip: true
                text: root.customDns.trim()
                onAccepted: {
                    if (text.trim() !== "")
                        Network.setDns("custom", text.trim());
                    root.customDns = "";
                }

                StyledText {
                    anchors.fill: parent
                    visible: dnsInput.text === ""
                    text: "Servers, e.g. 1.1.1.1 9.9.9.9 (Enter)"
                    color: Theme.overlay1
                }
            }
        }

        // Speed test
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4

            StyledText {
                Layout.fillWidth: true
                text: "Speed test"
                color: Theme.subtext0
                font.pixelSize: Theme.fontSize - 1
            }

            TextButton {
                text: Network.testing ? "Testing…" : "Run"
                primary: !Network.testing
                enabled: !Network.testing
                onClicked: Network.startSpeedtest()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Network.speed.phase !== undefined
            spacing: 6

            Repeater {
                model: [
                    { label: "Ping", value: Network.speed.ping !== undefined ? `${Network.speed.ping} ms` : "…", active: Network.speed.phase === "ping" },
                    { label: "Download", value: Network.speed.download !== undefined ? `${Network.speed.download}` : (Network.speed.phase === "download" ? `${Network.speed.mbps ?? 0}` : "…"), unit: "Mb/s", active: Network.speed.phase === "download" },
                    { label: "Upload", value: Network.speed.upload !== undefined ? `${Network.speed.upload}` : (Network.speed.phase === "upload" ? `${Network.speed.mbps ?? 0}` : "…"), unit: "Mb/s", active: Network.speed.phase === "upload" }
                ]

                Card {
                    id: speedCard

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 58
                    border.color: modelData.active ? Theme.highlight : "transparent"
                    border.width: Theme.borderWidth

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: speedCard.modelData.value
                            font.pixelSize: Theme.fontSize + 3
                            font.weight: Font.Bold
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: speedCard.modelData.label + (speedCard.modelData.unit ? ` (${speedCard.modelData.unit})` : "")
                            color: Theme.overlay1
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: Network.speed.phase === "error"
            text: `Speed test failed: ${Network.speed.message ?? ""}`
            color: Theme.red
            wrapMode: Text.Wrap
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: "Connection editor"
        color: Theme.highlight
        horizontalAlignment: Text.AlignRight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Panels.popout = "";
                System.run(["nm-connection-editor"]);
            }
        }
    }
}
