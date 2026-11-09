import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Settings > Style > Lock screen > Preview: the lock screen's look on the focused monitor,
// without locking. A click or Esc closes it.
PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: Panels.lockPreview
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-lockpreview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) Qt.callLater(() => closer.forceActiveFocus())

    LockView {
        anchors.fill: parent
        screen: root.screen
        preview: true
        // the clock and password show here, whichever monitor locking would pick
        mainOverride: true
    }

    Item {
        id: closer

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Panels.lockPreview = false

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.lockPreview = false
        }
    }
}
