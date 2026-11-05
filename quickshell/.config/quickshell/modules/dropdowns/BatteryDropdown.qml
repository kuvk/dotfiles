import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Battery details and power profile (power-profiles-daemon; on ASUS laptops
// asusd maps these to Quiet / Balanced / Performance).
Dropdown {
    id: root

    name: "battery"
    contentWidth: 320

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Icon {
            text: Battery.icon
            color: Battery.color
            font.pixelSize: 32
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: `${Math.round(Battery.percent * 100)}%`
                font.pixelSize: 26
                font.weight: Font.Bold
            }

            StyledText {
                Layout.fillWidth: true
                text: Battery.state
                color: Theme.subtext0
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 12
        rowSpacing: 6

        StyledText {
            text: "Remaining"
            color: Theme.overlay1
        }

        StyledText {
            Layout.fillWidth: true
            text: Battery.timeLeft || "—"
            horizontalAlignment: Text.AlignRight
        }

        StyledText {
            text: Battery.charging ? "Charging at" : "Power draw"
            color: Theme.overlay1
        }

        StyledText {
            Layout.fillWidth: true
            text: Battery.watts > 0 ? `${Battery.watts.toFixed(1)} W` : "—"
            horizontalAlignment: Text.AlignRight
        }

        StyledText {
            visible: Battery.device?.healthSupported ?? false
            text: "Health"
            color: Theme.overlay1
        }

        StyledText {
            Layout.fillWidth: true
            visible: Battery.device?.healthSupported ?? false
            text: `${Math.round(Battery.device?.healthPercentage ?? 0)}%`
            horizontalAlignment: Text.AlignRight
        }
    }

    StyledText {
        text: "Power mode"
        color: Theme.subtext0
        font.pixelSize: Theme.fontSize - 1
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { label: "Quiet", profile: PowerProfile.PowerSaver, icon: Icons.moon },
                { label: "Balanced", profile: PowerProfile.Balanced, icon: Icons.sliders },
                { label: "Performance", profile: PowerProfile.Performance, icon: Icons.g(0xf0e7) }
            ]

            MouseArea {
                id: mode

                required property var modelData
                readonly property bool selected: PowerProfiles.profile === modelData.profile

                Layout.fillWidth: true
                implicitHeight: 52
                visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: PowerProfiles.profile = modelData.profile

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.smallRadius
                    color: mode.selected ? Theme.alpha(Theme.highlight, 0.25) : (mode.containsMouse ? Theme.hoverBg : Theme.cardBg)
                    border.color: mode.selected ? Theme.highlight : "transparent"
                    border.width: Theme.borderWidth
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        text: mode.modelData.icon
                        color: mode.selected ? Theme.highlight : Theme.subtext0
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: mode.modelData.label
                        color: mode.selected ? Theme.highlight : Theme.text
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
