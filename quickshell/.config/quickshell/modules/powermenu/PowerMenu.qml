import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Replacement for wlogout: every monitor gets a blurred, dimmed overlay and the
// focused one shows a row of icon buttons (same proportions as before).
// Keys: l e u r s, arrows/Tab + Enter; Esc or a click on the background closes.
Scope {
    id: root

    readonly property bool shown: Panels.powerMenu
    readonly property var actions: System.sessionActions
    property int current: 0
    readonly property real reveal: revealer.value

    Reveal {
        id: revealer

        shown: root.shown
    }

    onShownChanged: current = 0

    function run(index: int): void {
        const action = actions[index];
        Panels.powerMenu = false;
        if (action)
            System.runAction(action.id);
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            readonly property bool main: modelData === Panels.focusedScreen

            screen: modelData
            visible: root.reveal > 0
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            // blur comes from the quickshell-.* layer rule (needs alpha above 0.5)
            WlrLayershell.namespace: "quickshell-powermenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.shown && main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                id: background

                anchors.fill: parent
                color: Theme.alpha(Theme.crust, Theme.gamemode ? 1 : 0.6)
                opacity: root.reveal
                focus: root.shown && win.main

                onFocusChanged: if (focus) forceActiveFocus()

                Keys.onPressed: event => {
                    const n = root.actions.length;
                    if (event.key === Qt.Key_Escape) {
                        Panels.powerMenu = false;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_H) {
                        root.current = (root.current + n - 1) % n;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.current = (root.current + 1) % n;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.run(root.current);
                    } else {
                        const i = root.actions.findIndex(a => a.key === event.text.toLowerCase());
                        if (i < 0)
                            return;
                        root.run(i);
                    }
                    event.accepted = true;
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Panels.powerMenu = false
                }

                // 15% side margins, 42% top/bottom, 5% between buttons
                RowLayout {
                    visible: win.main
                    anchors.fill: parent
                    anchors.leftMargin: win.width * 0.15
                    anchors.rightMargin: win.width * 0.15
                    anchors.topMargin: win.height * 0.42
                    anchors.bottomMargin: win.height * 0.42
                    spacing: win.width * 0.05
                    scale: 0.92 + 0.08 * root.reveal

                    Repeater {
                        model: root.actions

                        MouseArea {
                            id: button

                            required property var modelData
                            required property int index
                            readonly property bool selected: root.current === index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 90
                            Layout.minimumHeight: 90
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.current = index
                            onClicked: root.run(index)

                            Rectangle {
                                id: box

                                anchors.fill: parent
                                radius: Theme.radius * 2
                                color: button.selected ? Theme.alpha(Theme.surface1, Theme.gamemode ? 1 : 0.9) : Theme.alpha(Theme.surface0, Theme.gamemode ? 1 : 0.75)
                                border.color: button.selected ? Theme[button.modelData.color] : "transparent"
                                border.width: Theme.borderWidth

                                // tight shadow: small offset, soft edge
                                layer.enabled: !Theme.gamemode
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: "black"
                                    shadowOpacity: 0.55
                                    shadowBlur: 0.45
                                    shadowVerticalOffset: 4
                                    shadowHorizontalOffset: 0
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animDuration
                                    }
                                }
                            }

                            SessionIcon {
                                anchors.centerIn: parent
                                entry: button.modelData
                                size: 44
                                scale: button.selected ? 1.1 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.animDuration
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
