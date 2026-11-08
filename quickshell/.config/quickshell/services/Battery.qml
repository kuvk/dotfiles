pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    readonly property real percent: device?.energyCapacity > 0 ? Math.min(1, device.energy / device.energyCapacity) : 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property real watts: Math.abs(device?.changeRate ?? 0)

    // Health: the battery's full charge against its design capacity. Read from the battery
    // itself; UPower's combined display device doesn't report it. -1 when unknown.
    readonly property UPowerDevice battery: {
        const all = UPower.devices.values;
        for (let i = 0; i < all.length; i++) {
            if (all[i].isLaptopBattery)
                return all[i];
        }
        return null;
    }
    readonly property real health: battery?.healthSupported ? battery.healthPercentage : -1

    // Power modes (power-profiles-daemon; on ASUS laptops asusd maps them to Quiet /
    // Balanced / Performance), for the battery dropdown and the OSD
    readonly property var powerModes: [
        { label: "Quiet", profile: PowerProfile.PowerSaver, icon: Icons.moon },
        { label: "Balanced", profile: PowerProfile.Balanced, icon: Icons.sliders },
        { label: "Performance", profile: PowerProfile.Performance, icon: Icons.bolt }
    ]

    // the current one (index loop: var arrays don't take .find here)
    readonly property var powerMode: {
        for (let i = 0; i < powerModes.length; i++) {
            if (powerModes[i].profile === PowerProfiles.profile)
                return powerModes[i];
        }
        return powerModes[1];
    }

    readonly property string state: {
        switch (device?.state) {
        case UPowerDeviceState.Charging:
            return "Charging";
        case UPowerDeviceState.Discharging:
            return "Discharging";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.PendingCharge:
            return "Plugged in, not charging";
        case UPowerDeviceState.Empty:
            return "Empty";
        default:
            return "Unknown";
        }
    }

    readonly property string timeLeft: {
        const secs = charging ? device?.timeToFull : device?.timeToEmpty;
        if (!secs || secs <= 0)
            return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        const t = h > 0 ? `${h}h ${m}m` : `${m}m`;
        return charging ? `${t} until full` : `${t} left`;
    }

    readonly property string icon: full ? Icons.batteryFull : Icons.batteryLevels[Math.round(percent * 10)] + (charging ? Icons.batteryCharging : "")

    readonly property color color: {
        if (charging || full)
            return Theme.sapphire;
        if (percent <= 0.15)
            return Theme.red;
        if (percent <= 0.4)
            return Theme.peach;
        if (percent <= 0.6)
            return Theme.yellow;
        return Theme.green;
    }

    readonly property string summary: [`${Math.round(percent * 100)}%`, state, timeLeft].filter(s => s).join(" · ")
}
