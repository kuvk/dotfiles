pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as BT
import qs.config

Singleton {
    id: root

    readonly property BT.BluetoothAdapter adapter: BT.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    // Paired/connected first, then by name; unnamed devices are noise
    readonly property var devices: (adapter?.devices.values ?? []).filter(d => d.name && d.name !== d.address).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    readonly property var connected: devices.filter(d => d.connected)

    function toggle(): void {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function setDiscovering(on: bool): void {
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }

    function activate(device: BT.BluetoothDevice): void {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    function iconFor(device: BT.BluetoothDevice): string {
        const icon = device.icon ?? "";
        if (icon.includes("headset") || icon.includes("headphone") || icon.includes("audio"))
            return Icons.headphones;
        if (icon.includes("keyboard"))
            return Icons.keyboard;
        if (icon.includes("gaming") || icon.includes("joystick"))
            return Icons.gamepad;
        return Icons.bluetooth;
    }
}
