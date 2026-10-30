import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Dropdown that drops out from under the bar and settles a few pixels below
// it with a full border, like tooltips and the Control Center. Horizontally
// centered on the item that opened it. One click anywhere outside closes it.
PanelWindow {
    id: root

    required property var bar
    required property string name
    property int contentWidth: 340
    default property alias content: column.data

    readonly property bool shown: Panels.dropdown === name && Panels.dropdownScreen === bar.screen
    readonly property real reveal: revealer.value

    // Gap under the bar, and a transparent margin so fractional monitor
    // scales never cut the right or bottom border
    readonly property int gap: 6
    readonly property int pad: 4
    readonly property int panelWidth: contentWidth
    readonly property int panelHeight: Math.ceil(column.implicitHeight + Theme.padding * 2)

    screen: bar.screen
    visible: reveal > 0
    color: "transparent"
    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.round(Math.max(2, Math.min((screen?.width ?? 0) - implicitWidth - 2, Panels.dropdownX - implicitWidth / 2)))
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: panelWidth + pad * 2
    implicitHeight: panelHeight + gap + pad
    WlrLayershell.namespace: "quickshell-dropdown"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Reveal {
        id: revealer

        shown: root.shown
        duration: Theme.animDuration * 1.6
    }

    HyprlandFocusGrab {
        active: root.shown
        // the bars too: clicking another bar icon switches to its dropdown
        windows: [root].concat(Panels.bars)
        onCleared: Panels.closeDropdown(root.name)
    }

    // Clipped at the bar's edge, so the panel appears to drop out of it
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: panel

            x: root.pad
            y: Math.round(root.gap - (root.panelHeight + root.gap) * (1 - root.reveal))
            width: root.panelWidth
            height: root.panelHeight
            color: Theme.panelBg
            radius: Theme.radius
            border.color: Theme.border
            border.width: Theme.borderWidth

            focus: root.shown
            Keys.onEscapePressed: Panels.closeDropdown(root.name)

            ColumnLayout {
                id: column

                anchors.fill: parent
                anchors.margins: Theme.padding
                spacing: Theme.spacing
            }
        }
    }
}
