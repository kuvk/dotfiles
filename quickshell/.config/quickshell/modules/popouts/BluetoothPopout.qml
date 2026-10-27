import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as BT
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    name: "bluetooth"
    onShownChanged: Bluetooth.setDiscovering(shown)

    SectionHeader {
        title: "Bluetooth"

        IconButton {
            icon: Icons.refresh
            color: Bluetooth.discovering ? Theme.accent : Theme.subtext0
            onClicked: Bluetooth.setDiscovering(!Bluetooth.discovering)
        }

        Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Bluetooth.enabled
            onToggled: Bluetooth.toggle()
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: !Bluetooth.enabled || Bluetooth.devices.length === 0
        text: !Bluetooth.available ? "No Bluetooth adapter" : !Bluetooth.enabled ? "Bluetooth is off" : "Searching for devices…"
        color: Theme.subtext0
        horizontalAlignment: Text.AlignHCenter
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 360)
        visible: Bluetooth.enabled
        contentHeight: list.implicitHeight
        clip: true

        ColumnLayout {
            id: list

            width: parent.width
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

                    IconButton {
                        visible: dev.modelData.paired && !dev.modelData.connected
                        icon: Icons.trash
                        color: Theme.overlay1
                        size: 26
                        onClicked: dev.modelData.forget()
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: "Bluetooth manager"
        color: Theme.accent2
        horizontalAlignment: Text.AlignRight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Panels.popout = "";
                System.run(["blueman-manager"]);
            }
        }
    }
}
