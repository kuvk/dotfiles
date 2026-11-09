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

    // gap under the bar (the panel settles this far below it)
    readonly property int gap: 6

    screen: Panels.overlayScreen ?? Panels.focusedScreen
    visible: reveal.value > 0
    color: "transparent"
    anchors {
        top: true
        right: true
        bottom: true
    }
    // 6 px from the screen's right and bottom edges; with the shadow the window reaches the
    // edges and keeps that space inside, with room for the shadow on the left
    readonly property int panelWidth: Math.round(420 * Theme.textScale)
    readonly property int edge: Theme.shadows ? 0 : 6
    margins {
        right: root.edge
        bottom: root.edge
    }
    // only the panel takes the mouse, not the room around it
    mask: Region {
        item: panel
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: panelWidth + (Theme.shadows ? Theme.shadowPad + 6 : 0)
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand like the dropdowns: the focus grab below hands this window the
    // keyboard and closes it on a click anywhere else (bar included). With
    // Exclusive focus Hyprland never reported those clicks to the grab.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            System.refresh();
            Network.refresh();
        }
    }

    HyprlandFocusGrab {
        active: root.shown
        // the bars too: clicking another bar icon switches to its dropdown
        windows: [root].concat(Panels.bars)
        onCleared: Panels.controlCenter = false
    }

    Reveal {
        id: reveal

        shown: root.shown
        duration: Theme.animDuration * 1.6
    }

    // Clipped at the bar's edge, so it drops out of it like the dropdowns
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: panel

            x: Theme.shadows ? Theme.shadowPad : 0
            width: root.panelWidth
            height: parent.height - root.gap - (6 - root.edge)
            y: Math.round(root.gap - (height + root.gap) * (1 - reveal.value))
            color: Theme.panelBg
            radius: Theme.radius
            border.color: Theme.border
            border.width: Theme.borderWidth
            layer.enabled: Theme.shadows
            layer.effect: ShellShadow {}

            focus: root.shown
            Keys.onEscapePressed: Panels.controlCenter = false
            Keys.onPressed: event => {
                // Left/Right switch between media players
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    Media.step(event.key === Qt.Key_Left ? -1 : 1);
                    event.accepted = true;
                    return;
                }
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

                // Header like the dropdowns': its icon and name on the left, notifications
                // under it; the time and date on the right
                Hero {
                    icon: Icons.sliders
                    iconColor: Hues.notifications
                    title: "Control Center"
                    status: Notifs.dnd ? "DO NOT DISTURB" : (Notifs.count > 0 ? `${Notifs.count} NOTIFICATION${Notifs.count === 1 ? "" : "S"}` : "NO NOTIFICATIONS")

                    ColumnLayout {
                        spacing: 1

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: Qt.formatDateTime(Time.date, "HH:mm")
                            font.pixelSize: Theme.titleSize
                            font.weight: Font.Bold
                        }

                        Caption {
                            Layout.alignment: Qt.AlignRight
                            text: Qt.formatDateTime(Time.date, "ddd d MMMM").toUpperCase()
                        }
                    }
                }

                Separator {}

                // Settings, Displays, Keybindings, System information
                ShellShortcuts {
                    Layout.fillWidth: true
                }

                Toggles {}

                Separator {
                    visible: media.visible
                }

                MediaCard {
                    id: media

                    Layout.fillWidth: true
                }

                Sliders {}

                Separator {}

                NotificationList {}

                Separator {}

                SessionRow {}
            }
        }
    }
}
