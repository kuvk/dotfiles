import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Replacement for wlogout with the same look: a dimmed full-screen overlay
// with one row of large buttons. Keys: l e u r s (like the wlogout layout),
// arrows/Tab + Enter, Esc or a click on the background closes.
PanelWindow {
    id: root

    readonly property bool shown: Panels.powerMenu
    readonly property var actions: System.sessionActions
    property int current: 0

    function run(index: int): void {
        const action = actions[index];
        Panels.powerMenu = false;
        if (action)
            System.runAction(action.id);
    }

    screen: Panels.focusedScreen
    visible: shown || fade.running
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShownChanged: {
        current = 0;
        if (shown)
            content.forceActiveFocus();
    }

    Rectangle {
        id: content

        anchors.fill: parent
        color: Theme.alpha(Theme.surface0, Theme.gamemode ? 0.9 : 0.5)
        opacity: root.shown ? 1 : 0
        focus: root.shown

        Behavior on opacity {
            NumberAnimation {
                id: fade

                duration: Theme.animDuration
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Panels.powerMenu = false;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_H) {
                root.current = (root.current + root.actions.length - 1) % root.actions.length;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                root.current = (root.current + 1) % root.actions.length;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.run(root.current);
            } else {
                const i = root.actions.findIndex(a => a.key === event.text.toLowerCase());
                if (i >= 0)
                    root.run(i);
                else
                    return;
            }
            event.accepted = true;
        }

        // Click outside the buttons closes, like wlogout
        MouseArea {
            anchors.fill: parent
            onClicked: Panels.powerMenu = false
        }

        // Same proportions as wlogout-dynamic.sh: 15% side margins,
        // 42% top/bottom margins, 5% column spacing
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.width * 0.15
            anchors.rightMargin: root.width * 0.15
            anchors.topMargin: root.height * 0.42
            anchors.bottomMargin: root.height * 0.42
            spacing: root.width * 0.05
            scale: root.shown ? 1 : 0.92

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animDuration * 1.5
                    easing.type: Easing.OutBack
                }
            }

            Repeater {
                model: root.actions

                MouseArea {
                    id: button

                    required property var modelData
                    required property int index
                    readonly property bool selected: root.current === index || containsMouse

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 100
                    Layout.minimumHeight: 100
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = index
                    onClicked: root.run(index)

                    // shadow: 1px 2px 4px rgba(0,0,0,0.8)
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.topMargin: 2
                        anchors.rightMargin: -1
                        anchors.bottomMargin: -2
                        radius: Theme.gamemode ? 0 : 16
                        color: Qt.rgba(0, 0, 0, 0.35)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.gamemode ? 0 : 16
                        color: button.selected ? Theme.alpha(Theme.overlay0, 0.8) : Theme.alpha(Theme.surface0, 0.5)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animDuration
                            }
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        text: button.modelData.icon
                        color: Theme[button.modelData.color]
                        font.pixelSize: 40
                    }

                    StyledText {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: button.modelData.label.toLowerCase()
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}
