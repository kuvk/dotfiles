import QtQuick
import QtQuick.Layouts
import Quickshell
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 0

        BarButton {
            onClicked: Panels.toggleLauncher("apps")

            Icon {
                text: Icons.arch
                color: Theme.accent2
                font.pixelSize: 17
            }
        }

        Workspaces {
            screen: barWindow.screen
        }

        WindowTitle {
            screen: barWindow.screen
            Layout.maximumWidth: 260
        }

        Item {
            Layout.fillWidth: true
        }

        MediaWidget {
            id: media

            Layout.maximumWidth: 320
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
            bar: barWindow
        }

        BarButton {
            id: audioButton

            active: Panels.popout === "audio" && Panels.popoutScreen === barWindow.screen
            onClicked: mouse => mouse.button === Qt.RightButton ? Audio.toggleMute(Audio.sink) : barWindow.toggle("audio", audioButton)
            onWheel: wheel => Audio.setVolume(Audio.sink, Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

            Icon {
                text: Audio.icon
                color: Audio.muted ? Theme.red : Theme.mauve
            }
        }

        BarButton {
            id: btButton

            active: Panels.popout === "bluetooth" && Panels.popoutScreen === barWindow.screen
            onClicked: mouse => mouse.button === Qt.RightButton ? Bluetooth.toggle() : barWindow.toggle("bluetooth", btButton)

            Icon {
                text: !Bluetooth.enabled ? Icons.bluetoothOff : (Bluetooth.connected.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth)
                color: !Bluetooth.enabled ? Theme.overlay1 : (Bluetooth.connected.length > 0 ? Theme.blue : Theme.sky)
            }
        }

        BarButton {
            id: netButton

            active: Panels.popout === "network" && Panels.popoutScreen === barWindow.screen
            onClicked: barWindow.toggle("network", netButton)

            Icon {
                text: Network.icon
                color: Network.type === "none" ? Theme.mauve : Theme.blue
            }
        }

        Battery {}

        BarButton {
            visible: Hypr.layout !== ""
            onClicked: Hypr.nextLayout()

            StyledText {
                text: Hypr.layout
                color: Theme.accent
            }
        }

        BarButton {
            id: clockButton

            active: Panels.popout === "calendar" && Panels.popoutScreen === barWindow.screen
            onClicked: barWindow.toggle("calendar", clockButton)

            StyledText {
                text: Qt.formatDateTime(Time.date, "HH:mm")
                color: Theme.sky
                font.weight: Font.DemiBold
            }
        }

        BarButton {
            active: Panels.controlCenter
            onClicked: mouse => mouse.button === Qt.RightButton ? (Notifs.dnd = !Notifs.dnd) : Panels.toggleControlCenter()

            Icon {
                text: Notifs.dnd ? Icons.bellDnd : (Notifs.count > 0 ? Icons.bellBadge : Icons.bell)
                color: Notifs.dnd ? Theme.mauve : (Notifs.count > 0 ? Theme.green : Theme.blue)
            }
        }

        BarButton {
            onClicked: System.powerMenu()

            Icon {
                text: Icons.power
                color: Theme.red
            }
        }
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
}
