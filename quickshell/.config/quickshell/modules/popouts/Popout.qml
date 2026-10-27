import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// Dropdown under the bar, horizontally centered on the item that opened it.
// Clicking anywhere outside it (except its bar) closes it.
PanelWindow {
    id: root

    required property var bar
    required property string name
    property int contentWidth: 340
    default property alias content: column.data

    readonly property bool shown: Panels.popout === name && Panels.popoutScreen === bar.screen

    screen: bar.screen
    visible: shown
    color: "transparent"
    anchors {
        top: true
        left: true
    }
    margins {
        top: 6
        left: Math.max(6, Math.min((screen?.width ?? 0) - implicitWidth - 6, Panels.popoutX - implicitWidth / 2))
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight + Theme.padding * 2
    WlrLayershell.namespace: "quickshell-popout"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.shown
        windows: [root, root.bar]
        onCleared: Panels.popout = ""
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        focus: root.shown
        Keys.onEscapePressed: Panels.popout = ""

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: Theme.padding
            spacing: Theme.spacing
        }
    }
}
