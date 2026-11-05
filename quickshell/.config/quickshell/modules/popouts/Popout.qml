import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Dropdown that slides out from under the bar, horizontally centered on the
// item that opened it. One click anywhere outside it (bar included) closes it.
PanelWindow {
    id: root

    required property var bar
    required property string name
    property int contentWidth: 340
    default property alias content: column.data

    readonly property bool shown: Panels.popout === name && Panels.popoutScreen === bar.screen
    readonly property real reveal: revealer.value

    screen: bar.screen
    visible: reveal > 0
    color: "transparent"
    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.max(6, Math.min((screen?.width ?? 0) - implicitWidth - 6, Panels.popoutX - implicitWidth / 2))
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight + Theme.padding * 2
    WlrLayershell.namespace: "quickshell-popout"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Reveal {
        id: revealer

        shown: root.shown
        duration: Theme.animDuration * 1.6
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root]
        onCleared: Panels.closePopout(root.name)
    }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: panel

            // The top edge tucks under the bar, so only sides and bottom show a border
            width: parent.width
            height: parent.height + Theme.borderWidth
            y: -Theme.borderWidth - height * (1 - root.reveal)
            color: Theme.panelBg
            border.color: Theme.border
            border.width: Theme.borderWidth
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Theme.radius
            bottomRightRadius: Theme.radius

            focus: root.shown
            Keys.onEscapePressed: Panels.closePopout(root.name)

            ColumnLayout {
                id: column

                anchors.fill: parent
                anchors.margins: Theme.padding
                anchors.topMargin: Theme.padding + Theme.borderWidth
                spacing: Theme.spacing
            }
        }
    }
}
