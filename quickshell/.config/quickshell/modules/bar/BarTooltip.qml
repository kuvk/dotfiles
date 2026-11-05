import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Tooltip under the bar for the hovered item. Click-through.
PanelWindow {
    id: root

    required property var bar

    readonly property bool shown: Panels.tooltip !== "" && Panels.tooltipScreen === bar.screen
    property string text: ""
    readonly property real reveal: revealer.value

    Reveal {
        id: revealer

        shown: root.shown
    }

    onShownChanged: if (shown) text = Panels.tooltip

    Connections {
        target: Panels

        function onTooltipChanged(): void {
            if (Panels.tooltip !== "")
                root.text = Panels.tooltip;
        }
    }

    screen: bar.screen
    visible: reveal > 0
    color: "transparent"
    anchors {
        top: true
        left: true
    }
    margins {
        top: 6
        left: Math.round(Math.max(6, Math.min((screen?.width ?? 0) - implicitWidth - 6, Panels.tooltipX - implicitWidth / 2)))
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    // whole pixels, so fractional monitor scales don't cut the border
    implicitWidth: Math.ceil(label.implicitWidth + 24)
    implicitHeight: Math.ceil(label.implicitHeight + 16)
    mask: Region {}
    WlrLayershell.namespace: "quickshell-tooltip"
    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        anchors.fill: parent
        opacity: root.reveal
        color: Theme.panelBg
        radius: Theme.smallRadius
        border.color: Theme.border
        border.width: Theme.borderWidth

        StyledText {
            id: label

            anchors.centerIn: parent
            text: root.text.replace(/\n/g, "<br>")
            textFormat: Text.StyledText
            lineHeight: 1.15
        }
    }
}
