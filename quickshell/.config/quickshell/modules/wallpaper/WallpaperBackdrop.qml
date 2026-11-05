import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// While the wallpaper or theme carousel is open, every other monitor gets the
// same blurred, dimmed overlay as the power menu; the carousel stays on the
// monitor it opened on. A click on one of them closes it.
Scope {
    id: root

    readonly property bool shown: Panels.wallpapers !== "" || Panels.themes

    Reveal {
        id: revealer

        shown: root.shown
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            visible: revealer.value > 0 && modelData !== (Panels.overlayScreen ?? Panels.focusedScreen)
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            // blur comes from the quickshell-.* layer rule (needs alpha above 0.5)
            WlrLayershell.namespace: "quickshell-wallpapers-backdrop"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.crust, Theme.gamemode ? 1 : 0.6)
                opacity: revealer.value

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Panels.wallpapers = "";
                        Panels.themes = false;
                    }
                }
            }
        }
    }
}
