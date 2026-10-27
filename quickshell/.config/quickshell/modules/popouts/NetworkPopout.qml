import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    name: "network"
    // SSID whose password field is open
    property string askPassword: ""

    onShownChanged: {
        askPassword = "";
        if (shown) {
            Network.refresh();
            Network.scan();
        }
    }

    SectionHeader {
        title: "Wi-Fi"

        IconButton {
            icon: Icons.refresh
            color: Network.scanning ? Theme.highlight : Theme.subtext0
            onClicked: Network.scan()
        }

        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Network.wifiEnabled
            onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
        }
    }

    ListItem {
        visible: Network.type === "ethernet"
        icon: Icons.ethernet
        label: Network.connection
        sublabel: "Wired, connected"
        highlighted: true
        cursorShape: Qt.ArrowCursor
    }

    StyledText {
        Layout.fillWidth: true
        visible: Network.error !== ""
        text: Network.error
        color: Theme.red
        wrapMode: Text.Wrap
    }

    StyledText {
        Layout.fillWidth: true
        visible: !Network.wifiEnabled
        text: "Wi-Fi is off"
        color: Theme.subtext0
        horizontalAlignment: Text.AlignHCenter
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 360)
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

    StyledText {
        Layout.fillWidth: true
        text: "Network settings"
        color: Theme.accent2
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
