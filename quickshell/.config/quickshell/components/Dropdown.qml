import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// Dropdown that drops out from under the bar and settles a few pixels below
// it with a full border, like tooltips and the Control Center. Horizontally
// centered on the item that opened it. One click anywhere outside closes it.
PanelWindow {
    id: root

    required property var bar
    required property string name
    // keys the panel doesn't handle itself (Escape closes it)
    signal keyPressed(var event)
    property int contentWidth: 340
    default property alias content: column.data

    readonly property bool shown: Panels.dropdown === name && Panels.dropdownScreen === bar.screen
    readonly property real reveal: revealer.value

    // Gap under the bar, and a transparent margin so fractional monitor
    // scales never cut the right or bottom border
    readonly property int gap: 6
    // room around the panel: a transparent margin, and the shadow's
    readonly property int pad: 4 + Theme.shadowPad
    // wider with bigger text
    readonly property int panelWidth: Math.round(contentWidth * Theme.textScale)
    readonly property int panelHeight: Math.ceil(column.implicitHeight + Theme.padding * 2)
    // While open, a change in height (switching tabs, content shown or hidden) slides the
    // bottom edge. The panel is drawn inside a window as tall as the space under the bar:
    // resizing a layer window makes it flash as if it reopened, so its size never changes,
    // and input outside the panel goes through (mask).
    property real shownHeight: panelHeight
    readonly property int roomBelowBar: (screen?.height ?? 0) - Theme.barHeight - Theme.barMargin

    Behavior on shownHeight {
        enabled: root.reveal === 1

        NumberAnimation {
            duration: Theme.animDuration * 1.6
            easing.type: Easing.OutCubic
        }
    }

    property Region panelRegion: Region {
        item: panel
    }

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
    implicitHeight: Math.max(panelHeight + gap + pad, roomBelowBar)
    mask: panelRegion
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
            height: Math.round(root.shownHeight)
            color: Theme.panelBg
            radius: Theme.radius
            border.color: Theme.border
            border.width: Theme.borderWidth
            layer.enabled: Theme.shadows
            layer.effect: ShellShadow {}

            focus: root.shown
            Keys.onEscapePressed: Panels.closeDropdown(root.name)
            Keys.onPressed: event => root.keyPressed(event)

            // Inside the border: while the height slides, content is cut there, not drawn over it
            Item {
                anchors.fill: parent
                anchors.margins: Theme.borderWidth
                clip: true

                ColumnLayout {
                    id: column

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.padding - Theme.borderWidth
                    // its full height, also while the panel is shorter
                    height: root.panelHeight - Theme.padding * 2
                    spacing: Theme.spacing
                }
            }
        }
    }
}
