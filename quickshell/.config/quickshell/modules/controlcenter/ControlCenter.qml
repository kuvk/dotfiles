import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Control Center: quick toggles, sliders, media, notifications and session buttons
PanelWindow {
    id: root

    readonly property bool shown: Panels.controlCenter

    screen: Panels.overlayScreen ?? Panels.focusedScreen
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
    // keyboard while open, for Esc, Shift+C (clear) and Shift+D (do not disturb)
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
        border.width: Theme.borderWidth

        focus: root.shown
        Keys.onEscapePressed: Panels.controlCenter = false
        Keys.onPressed: event => {
            if (!(event.modifiers & Qt.ShiftModifier))
                return;
            if (event.key === Qt.Key_C) {
                Notifs.clearAll();
                event.accepted = true;
            } else if (event.key === Qt.Key_D) {
                Notifs.dnd = !Notifs.dnd;
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Header: time with the Settings gear level with it, date below
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(Time.date, "HH:mm")
                        font.pixelSize: 28
                        font.weight: Font.Bold
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: -6
                        icon: Icons.cog
                        color: Theme.subtext0
                        onClicked: Panels.toggleSettings()
                    }
                }

                StyledText {
                    text: Qt.formatDateTime(Time.date, "dddd, d MMMM")
                    color: Theme.subtext0
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
                    icon: Icons.rocket
                    label: "Work-Game Mode"
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
                    color: Audio.muted ? Theme.red : Theme.highlight
                    onClicked: Audio.toggleMute(Audio.sink)
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: Audio.volume
                    to: 1.2
                    color: Audio.muted ? Theme.overlay0 : Theme.highlight
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

                    // Groups whose older notifications are shown
                    property var expanded: ({})

                    anchors.fill: parent
                    clip: true
                    spacing: 12
                    model: Notifs.groups

                    delegate: ColumnLayout {
                        id: group

                        required property var modelData
                        readonly property bool open: notifList.expanded[modelData.app] === true
                        readonly property string iconSource: {
                            const icon = modelData.icon;
                            if (!icon)
                                return "";
                            if (icon.startsWith("/"))
                                return "file://" + icon;
                            return icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
                        }

                        width: ListView.view.width
                        spacing: 6

                        // App header: icon, name, count, clear
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconImage {
                                implicitSize: 18
                                source: group.iconSource
                                visible: group.iconSource !== ""
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: group.modelData.app
                                color: Theme.highlight
                                font.weight: Font.DemiBold
                            }

                            StyledText {
                                text: group.modelData.list.length
                                color: Theme.overlay1
                                font.pixelSize: Theme.fontSize - 1
                            }

                            IconButton {
                                size: 24
                                icon: Icons.trash
                                color: Theme.overlay1
                                onClicked: Notifs.clearGroup(group.modelData.app)
                            }
                        }

                        Repeater {
                            model: group.open ? group.modelData.list : group.modelData.list.slice(0, 3)

                            NotificationCard {
                                required property var modelData

                                Layout.fillWidth: true
                                notification: modelData
                                showAppName: false
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: group.modelData.list.length > 3
                            text: group.open ? "Show less" : `Show ${group.modelData.list.length - 3} more`
                            color: Theme.subtext0
                            font.pixelSize: Theme.fontSize - 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const e = Object.assign({}, notifList.expanded);
                                    e[group.modelData.app] = !group.open;
                                    notifList.expanded = e;
                                }
                            }
                        }
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
                        implicitHeight: 44
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

                        SessionIcon {
                            anchors.centerIn: parent
                            entry: action.modelData
                            size: 18
                        }
                    }
                }
            }
        }
    }
}
