import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Battery details and power mode (the modes: services/Battery.qml)
Dropdown {
    id: root

    name: "battery"
    // the power mode buttons share the width equally, each wide enough for the longest label
    contentWidth: Math.max(340, modes.count * (modeWidth + 20) + (modes.count - 1) * 6 + Theme.padding * 2)

    readonly property int modeWidth: {
        // advanceWidth() alone doesn't update when the font changes
        modeMetrics.font;
        return Math.ceil(Math.max(...modes.model.map(m => modeMetrics.advanceWidth(m.label))));
    }

    FontMetrics {
        id: modeMetrics

        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        font.weight: Font.DemiBold
    }

    Hero {
        icon: Battery.icon
        iconColor: Hues.battery
        title: `${Math.round(Battery.percent * 100)}%`
        status: Battery.state.toUpperCase()
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 12
        rowSpacing: 4

        Label {
            text: "Remaining"
        }

        Value {
            text: Battery.timeLeft || "--"
        }

        Label {
            text: Battery.charging ? "Charging at" : "Power draw"
        }

        Value {
            text: Battery.watts > 0 ? `${Battery.watts.toFixed(1)} W` : "--"
        }

        // the full charge against when new
        Label {
            visible: Battery.health >= 0
            text: "Health"
        }

        Value {
            visible: Battery.health >= 0
            text: `${Math.round(Battery.health)}%`
        }
    }

    Separator {}

    Caption {
        text: "POWER MODE"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            id: modes

            model: Battery.powerModes

            Chip {
                required property var modelData

                // equal shares of the row
                Layout.preferredWidth: 1
                visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                icon: modelData.icon
                text: modelData.label
                current: PowerProfiles.profile === modelData.profile
                onClicked: PowerProfiles.profile = modelData.profile
            }
        }
    }
}
