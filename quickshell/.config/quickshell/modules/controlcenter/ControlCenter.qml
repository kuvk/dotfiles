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
    margins {
        right: 6
        bottom: 6
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: Math.round(420 * Theme.textScale)
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
            id: card
            width: parent.width
            height: parent.height - root.gap
            y: Math.round(root.gap - (height + root.gap) * (1 - reveal.value))
            color: Theme.panelBg
            radius: Theme.radius
            border.color: Theme.border
            border.width: Theme.borderWidth

            focus: root.shown
            Keys.onEscapePressed: Panels.controlCenter = false
            Keys.onPressed: event => {
                // Left/Right switch between media players while no control has the keyboard
                if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && card.activeFocus) {
                    Media.step(event.key === Qt.Key_Left ? -1 : 1);
                    event.accepted = true;
                    return;
                }
                // the keyboard: arrows and Ctrl+H / J / K / L through the controls (Nav)
                if (Nav.handle(event, card)) {
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
