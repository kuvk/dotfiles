import QtQuick
import Quickshell.Services.UPower
import qs.config
import qs.components

BarButton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property real pct: device?.energyCapacity > 0 ? Math.min(1, device.energy / device.energyCapacity) : 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged

    visible: device?.isLaptopBattery ?? false
    cursorShape: Qt.ArrowCursor

    Icon {
        text: root.full ? Icons.batteryFull : Icons.batteryLevels[Math.round(root.pct * 10)] + (root.charging ? Icons.batteryCharging : "")
        color: {
            if (root.charging || root.full)
                return Theme.sapphire;
            if (root.pct <= 0.15)
                return Theme.red;
            if (root.pct <= 0.4)
                return Theme.accent;
            if (root.pct <= 0.6)
                return Theme.yellow;
            return Theme.green;
        }
    }

    StyledText {
        visible: root.containsMouse
        text: `${Math.round(root.pct * 100)}%`
        color: Theme.subtext0
    }
}
