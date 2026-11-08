import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Quick toggles: Wi-Fi, Bluetooth, Do not disturb, Stay Awake, Work-Game, Night Light (Control Center)
ColumnLayout {
    Layout.fillWidth: true
    spacing: 14

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        QuickToggle {
            icon: Network.icon
            label: "Wi-Fi"
            sublabel: Network.type === "ethernet" ? "Ethernet" : (Network.type === "wifi" ? Network.connection : (Network.wifiEnabled ? "Not connected" : "Off"))
            checked: Network.wifiEnabled
            onClicked: Network.setWifiEnabled(!Network.wifiEnabled)
        }

        QuickToggle {
            icon: Bluetooth.enabled ? Icons.bluetooth : Icons.bluetoothOff
            label: "Bluetooth"
            sublabel: !Bluetooth.enabled ? "Off" : (Bluetooth.connected.length > 0 ? Bluetooth.connected[0].name : "On")
            checked: Bluetooth.enabled
            onClicked: Bluetooth.toggle()
        }

        QuickToggle {
            icon: Icons.bellDnd
            label: "Do not disturb"
            checked: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }

        QuickToggle {
            icon: Icons.nightlight
            label: "Night light"
            checked: System.nightlight
            onClicked: System.toggleNightlight()
        }

        QuickToggle {
            icon: Icons.rocket
            label: "Work-Game"
            sublabel: System.modeLabel
            checked: System.gamemode
            onClicked: System.cycleMode()
        }

        QuickToggle {
            icon: Icons.palette
            label: "Theme"
            sublabel: Theme.themeName
            onClicked: Panels.toggleThemes()
        }
    }
}
