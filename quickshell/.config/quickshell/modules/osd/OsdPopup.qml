import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// On-screen display (services/Osd.qml says what each one shows): an icon and a bar for a
// level, or an icon and a name for a state, at the bottom center of the focused monitor.
// Clicks go through it.
PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: reveal.value > 0
    color: "transparent"
    anchors.bottom: true
    margins.bottom: 80
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 320
    implicitHeight: 52
    mask: Region {}
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Reveal {
        id: reveal

        shown: Osd.shown
    }

    Rectangle {
        anchors.fill: parent
        opacity: reveal.value
        // rises a little as it appears
        anchors.topMargin: (1 - reveal.value) * 8
        radius: Theme.radius
        color: Theme.panelBg
        border.color: Theme.border
        border.width: Theme.borderWidth

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Icon {
                Layout.preferredWidth: 20
                text: Osd.entry.icon
                color: Osd.entry.dim ? Theme.overlay1 : Theme.accent
            }

            // a level: the bar
            Rectangle {
                Layout.fillWidth: true
                visible: Osd.entry.level >= 0
                implicitHeight: 6
                radius: height / 2
                color: Theme.surface1

                Rectangle {
                    width: parent.width * Math.max(0, Osd.entry.level)
                    height: parent.height
                    radius: parent.radius
                    color: Osd.entry.dim ? Theme.overlay1 : Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // a state: its name
            StyledText {
                Layout.fillWidth: true
                visible: Osd.entry.level < 0
                text: Osd.entry.label
                elide: Text.ElideRight
            }
        }
    }
}
