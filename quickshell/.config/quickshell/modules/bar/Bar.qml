import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.popouts

PanelWindow {
    id: barWindow

    required property ShellScreen modelData

    // Open a popout centered under `item`
    function toggle(name: string, item: Item): void {
        const pos = item.mapToItem(null, item.width / 2, 0);
        Panels.togglePopout(name, screen, pos.x);
    }

    function isOpen(name: string): bool {
        return Panels.popout === name && Panels.popoutScreen === screen;
    }

    screen: modelData
    visible: Panels.barVisible
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "quickshell-bar"

    // Left: launcher, workspaces, focused window (no hover dots here)
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        BarButton {
            id: launcherButton

            indicator: false
            tooltip: "Applications"
            onClicked: Panels.toggleLauncher("apps")

            Icon {
                text: Icons.arch
                color: launcherButton.containsMouse || (Panels.launcher && Panels.launcherMode === "apps") ? Theme.accent : Theme.accent2
                font.pixelSize: 17
            }
        }

        Workspaces {
            anchors.verticalCenter: parent.verticalCenter
            screen: barWindow.screen
        }

        WindowTitle {
            anchors.verticalCenter: parent.verticalCenter
            screen: barWindow.screen
        }
    }

    // Center: the clock sits exactly in the middle; layout to its left, weather to its right
    BarButton {
        id: clockButton

        anchors.centerIn: parent
        active: barWindow.isOpen("calendar")
        tooltip: Qt.formatDateTime(Time.date, "dddd, d MMMM yyyy")
        onClicked: barWindow.toggle("calendar", clockButton)

        StyledText {
            text: Qt.formatDateTime(Time.date, Config.clockFormat)
            color: Theme.text
            font.weight: Font.DemiBold
        }
    }

    BarButton {
        anchors.right: clockButton.left
        anchors.verticalCenter: parent.verticalCenter
        visible: Hypr.layout !== ""
        tooltip: `Keyboard layout: ${Hypr.layoutName || Hypr.layout}`
        onClicked: Hypr.nextLayout()

        StyledText {
            text: Hypr.layout
            color: Theme.text
            font.weight: Font.DemiBold
        }
    }

    BarButton {
        id: weatherButton

        anchors.left: clockButton.right
        anchors.verticalCenter: parent.verticalCenter
        visible: Config.showWeather && Weather.ready
        active: barWindow.isOpen("weather")
        tooltip: `${Weather.description}, feels like ${Weather.feelsLike}${Weather.unit}\n${Weather.location}`
        onClicked: barWindow.toggle("weather", weatherButton)

        Icon {
            text: Weather.icon
            color: Theme.yellow
        }

        StyledText {
            text: `${Weather.temp}°`
            color: Theme.subtext1
        }
    }

    // Right: media, tray, status, control center
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        MediaWidget {
            id: media

            active: barWindow.isOpen("media")
            tooltip: `${Media.active?.identity ?? ""}\n${Media.label}`
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    barWindow.toggle("media", media);
                else if (mouse.button === Qt.MiddleButton)
                    Media.active?.togglePlaying();
                else
                    Media.cyclePlayer();
            }
        }

        Tray {}

        BarButton {
            tooltip: System.stayAwake ? "Stay awake: on\nScreen won't lock or sleep" : "Stay awake: off"
            onClicked: System.stayAwake = !System.stayAwake

            Icon {
                text: Icons.coffee
                color: System.stayAwake ? Theme.accent : Theme.overlay1
            }
        }

        BarButton {
            active: Panels.displays
            tooltip: "Displays"
            onClicked: Panels.toggleDisplays()

            Icon {
                text: Icons.display
                color: Theme.teal
            }
        }

        BarButton {
            id: audioButton

            active: barWindow.isOpen("audio")
            tooltip: Audio.muted ? `Muted\n${Audio.nodeName(Audio.sink)}` : `Volume ${Math.round(Audio.volume * 100)}%\n${Audio.nodeName(Audio.sink)}`
            onClicked: mouse => mouse.button === Qt.RightButton ? Audio.toggleMute(Audio.sink) : barWindow.toggle("audio", audioButton)
            onWheel: wheel => Audio.setVolume(Audio.sink, Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

            Icon {
                text: Audio.icon
                color: Audio.muted ? Theme.red : Theme.mauve
            }
        }

        BarButton {
            id: btButton

            active: barWindow.isOpen("bluetooth")
            tooltip: !Bluetooth.enabled ? "Bluetooth: off" : Bluetooth.connected.length > 0 ? `Bluetooth: ${Bluetooth.connected.map(d => d.name).join(", ")}` : "Bluetooth: on"
            onClicked: mouse => mouse.button === Qt.RightButton ? Bluetooth.toggle() : barWindow.toggle("bluetooth", btButton)

            Icon {
                text: !Bluetooth.enabled ? Icons.bluetoothOff : (Bluetooth.connected.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth)
                color: !Bluetooth.enabled ? Theme.overlay1 : (Bluetooth.connected.length > 0 ? Theme.blue : Theme.sky)
            }
        }

        BarButton {
            id: netButton

            active: barWindow.isOpen("network")
            tooltip: Network.type === "ethernet" ? `Ethernet: ${Network.connection}` : Network.type === "wifi" ? `Wi-Fi: ${Network.connection} (${Network.strength}%)` : (Network.wifiEnabled ? "Not connected" : "Wi-Fi: off")
            onClicked: barWindow.toggle("network", netButton)

            Icon {
                text: Network.icon
                color: Network.type === "none" ? Theme.mauve : Theme.blue
            }
        }

        BarButton {
            id: batteryButton

            visible: Battery.available
            active: barWindow.isOpen("battery")
            tooltip: Battery.summary
            onClicked: barWindow.toggle("battery", batteryButton)

            Icon {
                text: Battery.icon
                color: Battery.color
            }
        }

        BarButton {
            active: Panels.controlCenter
            tooltip: Notifs.dnd ? "Control center\nDo not disturb is on" : `Control center\n${Notifs.count} notification${Notifs.count === 1 ? "" : "s"}`
            onClicked: mouse => mouse.button === Qt.RightButton ? (Notifs.dnd = !Notifs.dnd) : Panels.toggleControlCenter()

            Icon {
                text: Icons.sliders
                color: Notifs.dnd ? Theme.mauve : Theme.blue

                // Unread notifications
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -4
                    anchors.topMargin: -1
                    width: 7
                    height: 7
                    radius: 4
                    color: Theme.accent
                    visible: Notifs.count > 0 && !Notifs.dnd
                }
            }
        }

        BarButton {
            active: Panels.powerMenu
            tooltip: "Power menu"
            onClicked: Panels.togglePowerMenu()

            Icon {
                text: Icons.power
                color: Theme.red
            }
        }
    }

    BarTooltip {
        bar: barWindow
    }

    // Popouts belong to the bar of their screen
    NetworkPopout {
        bar: barWindow
    }

    BluetoothPopout {
        bar: barWindow
    }

    AudioPopout {
        bar: barWindow
    }

    MediaPopout {
        bar: barWindow
    }

    CalendarPopout {
        bar: barWindow
    }

    WeatherPopout {
        bar: barWindow
    }

    BatteryPopout {
        bar: barWindow
    }
}
