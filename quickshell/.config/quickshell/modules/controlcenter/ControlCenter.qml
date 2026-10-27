import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Right-hand panel: quick toggles, sliders, media and notification history
PanelWindow {
    id: root

    readonly property bool shown: Panels.controlCenter

    screen: Panels.focusedScreen
    visible: shown
    color: "transparent"
    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: 6
        right: 6
        bottom: 6
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: 420
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            System.refresh();
            Network.refresh();
        }
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root]
        onCleared: Panels.controlCenter = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        focus: root.shown
        Keys.onEscapePressed: Panels.controlCenter = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Qt.formatDateTime(Time.date, "HH:mm")
                        font.pixelSize: 28
                        font.weight: Font.Bold
                    }

                    StyledText {
                        text: Qt.formatDateTime(Time.date, "dddd, d MMMM")
                        color: Theme.subtext0
                    }
                }

            }

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
                    icon: Icons.gamepad
                    label: "Game mode"
                    checked: System.gamemode
                    onClicked: System.toggleGamemode()
                }

                QuickToggle {
                    icon: Icons.palette
                    label: "Theme"
                    sublabel: Theme.themeName
                    onClicked: Panels.toggleLauncher("themes")
                }
            }

            // Sliders
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconButton {
                    icon: Audio.icon
                    color: Audio.muted ? Theme.red : Theme.accent
                    onClicked: Audio.toggleMute(Audio.sink)
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: Audio.volume
                    to: 1.2
                    color: Audio.muted ? Theme.overlay0 : Theme.accent
                    onMoved: v => Audio.setVolume(Audio.sink, v)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: System.hasBrightness
                spacing: 8

                Icon {
                    Layout.preferredWidth: 30
                    text: Icons.sun
                    color: Theme.yellow
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: System.brightness
                    color: Theme.yellow
                    onMoved: v => System.setBrightness(v)
                }
            }

            MediaCard {
                Layout.fillWidth: true
            }

            SectionHeader {
                title: "Notifications"

                MouseArea {
                    visible: Notifs.count > 0
                    implicitWidth: clearLabel.implicitWidth + 16
                    implicitHeight: 26
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()

                    StyledText {
                        id: clearLabel

                        anchors.centerIn: parent
                        text: `${Icons.clearAll}  Clear`
                        color: Theme.subtext0
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: notifList

                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    model: Notifs.list.slice().reverse()

                    delegate: NotificationCard {
                        required property var modelData

                        width: ListView.view.width
                        notification: modelData
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: notifList.count === 0
                    text: `${Icons.bell}  No notifications`
                    color: Theme.overlay1
                }
            }

            // Session actions
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: System.sessionActions

                    MouseArea {
                        id: action

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 52
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Panels.closeAll();
                            System.runAction(modelData.id);
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.smallRadius
                            color: action.containsMouse ? Theme.hoverBg : Theme.cardBg
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                text: action.modelData.icon
                                color: Theme[action.modelData.color]
                                font.pixelSize: 16
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: action.modelData.label
                                color: Theme.subtext0
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                    }
                }
            }
        }
    }
}
