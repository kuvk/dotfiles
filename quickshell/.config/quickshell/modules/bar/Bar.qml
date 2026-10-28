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
    // The profile's primary monitor (Displays); with none known yet, every bar is primary
    readonly property bool primary: Displays.primaryName === "" || Displays.primaryName === screen?.name

    function shows(id: string): bool {
        return Config.barShows(primary, id);
    }

    // Open a popout centered under `item`
    function toggle(name: string, item: Item): void {
        const pos = item.mapToItem(null, item.width / 2, 0);
        // window coordinates, plus the floating bar's margin
        Panels.togglePopout(name, screen, pos.x + Theme.barMargin);
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
    margins {
        top: Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    // Background: full width and square, or floating with rounded corners
    // and the window border
    Rectangle {
        anchors.fill: parent
        z: -1
        color: Theme.barBg
        radius: Theme.barRadius
        border.color: Theme.barMargin > 0 ? Theme.border : "transparent"
        border.width: Theme.barMargin > 0 ? Theme.borderWidth : 0
    }

    // Left: launcher, workspaces, focused window (no hover dots here)
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        BarButton {
            id: launcherButton

            visible: barWindow.shows("launcher")
            indicator: false
            tooltip: "Applications"
            onClicked: Panels.toggleAppMenu()

            Icon {
                text: Icons.arch
                color: launcherButton.containsMouse || (Panels.appMenu && Panels.overlayScreen === barWindow.screen) ? Theme.accent : Theme.accent2
                font.pixelSize: 17
            }
        }

        Workspaces {
            anchors.verticalCenter: parent.verticalCenter
            visible: barWindow.shows("workspaces")
            screen: barWindow.screen
        }

        WindowTitle {
            anchors.verticalCenter: parent.verticalCenter
            shown: barWindow.shows("windowTitle")
            screen: barWindow.screen
        }
    }

    // Center: the clock sits exactly in the middle; layout to its left, weather to its right
    BarButton {
        id: clockButton

        anchors.centerIn: parent
        active: barWindow.isOpen("calendar")
        tooltip: Qt.formatDateTime(Time.date, "dddd\nd MMMM yyyy")
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
        visible: barWindow.shows("layout") && Hypr.layout !== ""
        tooltip: `Keyboard layout\n${Hypr.layoutName || Hypr.layout}`
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
        visible: barWindow.shows("weather") && Weather.ready
        active: barWindow.isOpen("weather")
        tooltip: `${Weather.description}\nFeels like ${Weather.feelsLike}${Weather.unit}\n${Weather.location}`
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

            shown: barWindow.shows("media")
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

        Tray {
            shown: barWindow.shows("tray")
        }

        BarButton {
            visible: barWindow.shows("workGame")
            tooltip: System.gamemode ? "Leave Work-Game Mode" : "Work-Game Mode"
            onClicked: System.toggleGamemode()

            Icon {
                text: Icons.rocket
                color: System.gamemode ? Theme.mauve : Theme.overlay1
            }
        }

        BarButton {
            visible: barWindow.shows("stayAwake")
            tooltip: System.stayAwake ? "Allow Idle Lock & Screensaver" : "Stay Awake"
            onClicked: System.stayAwake = !System.stayAwake

            Icon {
                text: Icons.coffee
                color: System.stayAwake ? Theme.accent : Theme.overlay1
            }
        }

        BarButton {
            id: audioButton

            visible: barWindow.shows("audio")
            active: barWindow.isOpen("audio")
            tooltip: `${Audio.muted ? "Muted" : `Volume ${Math.round(Audio.volume * 100)}%`}\n${Audio.nodeName(Audio.sink)}`
            onClicked: mouse => mouse.button === Qt.RightButton ? Audio.toggleMute(Audio.sink) : barWindow.toggle("audio", audioButton)
            onWheel: wheel => Audio.setVolume(Audio.sink, Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

            Icon {
                text: Audio.icon
                color: Audio.color
            }
        }

        BarButton {
            id: btButton

            visible: barWindow.shows("bluetooth")
            active: barWindow.isOpen("bluetooth")
            tooltip: !Bluetooth.enabled ? "Bluetooth\nOff" : Bluetooth.connected.length > 0 ? `Bluetooth\n${Bluetooth.connected.map(d => d.name).join("\n")}` : "Bluetooth\nOn, nothing connected"
            onClicked: mouse => mouse.button === Qt.RightButton ? Bluetooth.toggle() : barWindow.toggle("bluetooth", btButton)

            Icon {
                text: !Bluetooth.enabled ? Icons.bluetoothOff : (Bluetooth.connected.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth)
                color: !Bluetooth.enabled ? Theme.overlay1 : (Bluetooth.connected.length > 0 ? Theme.blue : Theme.sky)
            }
        }

        BarButton {
            id: netButton

            visible: barWindow.shows("network")
            active: barWindow.isOpen("network")
            tooltip: Network.tooltip
            onClicked: barWindow.toggle("network", netButton)

            Icon {
                text: Network.icon
                color: Network.type === "none" ? Theme.mauve : Theme.blue
            }
        }

        BarButton {
            id: batteryButton

            visible: barWindow.shows("battery") && Battery.available
            active: barWindow.isOpen("battery")
            tooltip: Battery.summary.split(" · ").join("\n")
            onClicked: barWindow.toggle("battery", batteryButton)

            Icon {
                text: Battery.icon
                color: Battery.color
            }
        }

        BarButton {
            visible: barWindow.shows("controlCenter")
            active: Panels.controlCenter && Panels.overlayScreen === barWindow.screen
            tooltip: `Control Center\nNotifications: ${Notifs.count}${Notifs.dnd ? "\nDo not disturb" : ""}`
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
            visible: barWindow.shows("displays")
            active: Panels.displays
            tooltip: "Displays"
            onClicked: Panels.toggleDisplays()

            Icon {
                text: Icons.display
                color: Theme.teal
            }
        }

        BarButton {
            visible: barWindow.shows("power")
            active: Panels.powerMenu
            tooltip: "Power Menu"
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

    TrayMenu {
        bar: barWindow
    }
}
