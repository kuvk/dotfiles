import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Centered content on a dark scrim over the monitor the network dropdown was on, like
// Omarchy's Wi-Fi QR and speed test overlays. Esc or a click on the scrim closes it.
PanelWindow {
    id: root

    required property bool shown
    property string layerName
    default property alias content: column.data
    readonly property real reveal: revealer.value
    signal closeRequested

    Reveal {
        id: revealer

        shown: root.shown
    }

    onShownChanged: if (shown) Qt.callLater(() => keys.forceActiveFocus())

    screen: Panels.overlayScreen ?? Panels.focusedScreen
    visible: reveal > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    // blur comes from the quickshell-.* layer rule
    WlrLayershell.namespace: layerName
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, Theme.gamemode ? 0.95 : 0.78)
        opacity: root.reveal

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: root.closeRequested()

        // Clicks on the content don't close it
        MouseArea {
            anchors.fill: column
        }

        ColumnLayout {
            id: column

            anchors.centerIn: parent
            spacing: 16
            opacity: root.reveal
            scale: 0.96 + 0.04 * root.reveal
        }
    }
}
