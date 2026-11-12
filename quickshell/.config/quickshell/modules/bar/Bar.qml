import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services
import qs.modules.displays
import qs.modules.dropdowns
import qs.modules.audio
import qs.modules.network

PanelWindow {
    id: barWindow

    required property ShellScreen modelData
    // The status icons on the right (not the tray, not media): each in a slot of one width, so
    // their open-dropdown underline is the same length; the font's icons are 6 to 14 px wide at
    // the bar's 12 px. Less padding than other bar items keeps them no wider than before.
    readonly property int iconSlot: Math.ceil(Theme.barIconSize * 1.2)
    readonly property int iconPadding: 9
    // Settings > Bar > Per monitor: this monitor's modules, all of them for one not set yet
    function shows(id: string): bool {
        return Config.barShows(screen?.name ?? "", id);
    }

    // Open a dropdown centered under `item`
    function toggle(name: string, item: Item): void {
        const pos = item.mapToItem(null, item.width / 2, 0);
        // window coordinates, plus the floating bar's margin
        Panels.toggleDropdown(name, screen, pos.x + Theme.barMargin);
    }

    // SUPER+CTRL+M: the Displays dropdown from this bar's monitor icon
    function toggleDisplays(): void {
        toggle("displays", displaysButton);
    }

    function isOpen(name: string): bool {
        return Panels.dropdown === name && Panels.dropdownScreen === screen;
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
    Rectangle {
        anchors.fill: parent
        z: -1
        color: Theme.barBg
        radius: Theme.barRadius

        // the bar is part of the dropdowns' focus grab, so a click on its
        // empty space closes them here
        MouseArea {
            anchors.fill: parent
            onClicked: {
                Panels.dropdown = "";
                Panels.appMenu = false;
                Panels.controlCenter = false;
            }
        }
    }

    Component.onCompleted: Panels.registerBar(barWindow)
    Component.onDestruction: Panels.unregisterBar(barWindow)

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
                text: Distro.logo
                color: Hues.launcher
                font.pixelSize: Theme.iconSize
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
        visible: barWindow.shows("clock")
        active: barWindow.isOpen("calendar")
        tooltip: Qt.formatDateTime(Time.date, "dddd\nd MMMM yyyy")
        onClicked: barWindow.toggle("calendar", clockButton)

        BarText {
            text: Qt.formatDateTime(Time.date, Config.clockFormat)
            color: Theme.foreground
        }
    }

    BarButton {
        anchors.right: clockButton.left
        anchors.verticalCenter: parent.verticalCenter
        visible: barWindow.shows("layout") && Hypr.layout !== ""
        tooltip: `Keyboard layout\n${Hypr.layoutName || Hypr.layout}`
        onClicked: Hypr.nextLayout()

        BarText {
            text: Hypr.layout
            color: Theme.foreground
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
            font.pixelSize: Theme.barIconSize
            text: Weather.icon
            color: Hues.weather
        }

        BarText {
            text: `${Weather.temp}°`
            color: Theme.foreground
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
            sidePadding: barWindow.iconPadding
            visible: barWindow.shows("stayAwake")
            tooltip: System.stayAwake ? "Allow Idle Lock & Screensaver" : "Stay Awake"
            onClicked: System.stayAwake = !System.stayAwake

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Icons.coffee
                color: Hues.stayAwake
            }
        }

        // Click: normal, Work, Game, normal
        BarButton {
            sidePadding: barWindow.iconPadding
            visible: barWindow.shows("workGame")
            tooltip: `Work-Game: ${System.modeLabel}`
            onClicked: System.cycleMode()

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Icons.rocket
                color: Hues.mode
            }
        }

        BarButton {
            sidePadding: barWindow.iconPadding
            id: audioButton

            visible: barWindow.shows("audio")
            active: barWindow.isOpen("audio")
            tooltip: `${Audio.muted ? "Muted" : `Volume ${Math.round(Audio.volume * 100)}%`}\n${Audio.nodeName(Audio.sink)}`
            onClicked: mouse => mouse.button === Qt.RightButton ? Audio.toggleMute(Audio.sink) : barWindow.toggle("audio", audioButton)
            onWheel: wheel => Audio.setVolume(Audio.sink, Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Audio.icon
                color: Hues.audio
            }
        }

        BarButton {
            sidePadding: barWindow.iconPadding
            id: btButton

            visible: barWindow.shows("bluetooth")
            active: barWindow.isOpen("bluetooth")
            tooltip: !Bluetooth.enabled ? "Bluetooth\nOff" : Bluetooth.connected.length > 0 ? `Bluetooth\n${Bluetooth.connected.map(d => d.name).join("\n")}` : "Bluetooth\nOn, nothing connected"
            onClicked: mouse => mouse.button === Qt.RightButton ? Bluetooth.toggle() : barWindow.toggle("bluetooth", btButton)

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: !Bluetooth.enabled ? Icons.bluetoothOff : (Bluetooth.connected.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth)
                color: Hues.bluetooth
            }
        }

        BarButton {
            sidePadding: barWindow.iconPadding
            id: netButton

            visible: barWindow.shows("network")
            active: barWindow.isOpen("network")
            tooltip: Network.tooltip
            onClicked: barWindow.toggle("network", netButton)

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Network.icon
                // disabled color when Wi-Fi is off, like Bluetooth
                color: Hues.network
            }
        }

        BarButton {
            sidePadding: barWindow.iconPadding
            id: batteryButton

            visible: barWindow.shows("battery") && Battery.available
            active: barWindow.isOpen("battery")
            tooltip: Battery.summary.split(" · ").join("\n")
            onClicked: barWindow.toggle("battery", batteryButton)

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Battery.icon
                color: Hues.battery
            }
        }

        BarButton {
            sidePadding: barWindow.iconPadding
            id: displaysButton

            visible: barWindow.shows("displays")
            active: barWindow.isOpen("displays")
            tooltip: "Displays"
            onClicked: barWindow.toggle("displays", displaysButton)

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Icons.display
                color: Hues.system
            }
        }

        BarButton {
            sidePadding: barWindow.iconPadding
            visible: barWindow.shows("controlCenter")
            active: Panels.controlCenter && Panels.overlayScreen === barWindow.screen
            tooltip: `Control Center\nNotifications: ${Notifs.count}${Notifs.dnd ? "\nDo not disturb" : ""}`
            onClicked: mouse => mouse.button === Qt.RightButton ? (Notifs.dnd = !Notifs.dnd) : Panels.toggleControlCenter()

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Icons.sliders
                color: Hues.notifications

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
            sidePadding: barWindow.iconPadding
            visible: barWindow.shows("power")
            active: Panels.powerMenu
            tooltip: "Power Menu"
            onClicked: Panels.togglePowerMenu()

            Icon {
                font.pixelSize: Theme.barIconSize
                width: barWindow.iconSlot
                text: Icons.power
                color: Hues.power
            }
        }
    }

    BarTooltip {
        bar: barWindow
    }

    // Dropdowns belong to the bar of their screen
    NetworkDropdown {
        bar: barWindow
    }

    BluetoothDropdown {
        bar: barWindow
    }

    AudioDropdown {
        bar: barWindow
    }

    MediaDropdown {
        bar: barWindow
    }

    CalendarDropdown {
        bar: barWindow
    }

    WeatherDropdown {
        bar: barWindow
    }

    BatteryDropdown {
        bar: barWindow
    }

    DisplaysDropdown {
        bar: barWindow
    }

    TrayMenu {
        bar: barWindow
    }
}
