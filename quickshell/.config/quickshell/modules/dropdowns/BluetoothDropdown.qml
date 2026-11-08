import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as BT
import qs.config
import qs.components
import qs.services

// Bluetooth: on or off, searching while open, and the devices (connected and paired first)
Dropdown {
    id: root

    name: "bluetooth"
    onShownChanged: Bluetooth.setDiscovering(shown)

    Hero {
        icon: !Bluetooth.enabled ? Icons.bluetoothOff : (Bluetooth.connected.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth)
        iconColor: Bluetooth.enabled ? Theme.highlight : Theme.overlay1
        title: Bluetooth.connected.length > 0 ? Bluetooth.connected.map(d => d.name).join(", ") : "Bluetooth"
        status: {
            if (!Bluetooth.available)
                return "NO BLUETOOTH ADAPTER";
            if (!Bluetooth.enabled)
                return "BLUETOOTH IS OFF";
            if (Bluetooth.connected.length > 0)
                return "CONNECTED";
            return Bluetooth.discovering ? "SEARCHING FOR DEVICES" : "NOT CONNECTED";
        }

        IconButton {
            visible: Bluetooth.enabled
            icon: Icons.refresh
            color: Bluetooth.discovering ? Theme.highlight : Theme.subtext0
            onClicked: Bluetooth.setDiscovering(!Bluetooth.discovering)
        }

        Switch {
            visible: Bluetooth.available
            checked: Bluetooth.enabled
            onToggled: Bluetooth.toggle()
        }
    }

    Separator {
        visible: Bluetooth.enabled
    }

    Caption {
        visible: Bluetooth.enabled
        text: Bluetooth.devices.length > 0 ? "DEVICES" : "SEARCHING FOR DEVICES…"
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: Math.min(list.implicitHeight, 360)
        visible: Bluetooth.enabled && Bluetooth.devices.length > 0

        Flickable {
            id: deviceList

            anchors.fill: parent
            contentHeight: list.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: list

                width: deviceList.width
                spacing: 2

                Repeater {
                    model: Bluetooth.devices

                    ListItem {
                        id: dev

                        required property BT.BluetoothDevice modelData
                        readonly property bool busy: modelData.state === BT.BluetoothDeviceState.Connecting || modelData.state === BT.BluetoothDeviceState.Disconnecting || modelData.pairing

                        icon: Bluetooth.iconFor(modelData)
                        label: modelData.name
                        sublabel: busy ? "Working…" : modelData.connected ? (modelData.batteryAvailable ? `Connected · ${Math.round(modelData.battery * 100)}%` : "Connected") : modelData.paired ? "Paired" : "Not paired"
                        highlighted: modelData.connected
                        onClicked: Bluetooth.activate(modelData)

                        // Forget a paired device
                        IconButton {
                            visible: dev.modelData.paired && !dev.modelData.connected && dev.containsMouse
                            icon: Icons.closeCircle
                            color: Theme.red
                            size: 26
                            onClicked: dev.modelData.forget()
                        }
                    }
                }
            }
        }

        ScrollBar {
            flick: deviceList
        }
    }

    FooterLink {
        text: "Bluetooth manager"
        onClicked: {
            Panels.dropdown = "";
            System.run(["blueman-manager"]);
        }
    }
}
