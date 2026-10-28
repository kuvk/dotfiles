import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// One per monitor: shows the capture of the old look and opens it from the
// middle out, the opening slanted like a diagonal wipe. The two halves are
// sheared clipping Items (no shader layers); the capture inside each gets the
// inverse shear so it stays in place.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool running: Transition.phase !== "idle"
    readonly property real w: width
    readonly property real h: height
    readonly property real skew: h * 0.3
    readonly property real k: skew / Math.max(1, h)
    // half width of the opening
    property real gap: 0
    property int captured: 0

    screen: modelData
    visible: running
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-transition"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onRunningChanged: {
        gap = 0;
        captured = 0;
    }

    onCapturedChanged: if (captured === 2) Transition.screenReady()

    NumberAnimation on gap {
        running: Transition.phase === "reveal"
        from: 0
        to: root.w / 2 + root.skew + 20
        duration: Transition.revealMs
        easing.type: Easing.InOutCubic
    }

    component Half: Item {
        id: half

        // left edge of the half in its own (unsheared) coordinates
        property real edge: 0

        x: 0
        y: 0
        height: root.h
        clip: true
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, -root.k, 0, root.skew + half.edge, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        ScreencopyView {
            width: root.w
            height: root.h
            live: false
            captureSource: Transition.phase === "capture" || hasContent && root.running ? root.screen : null
            onHasContentChanged: if (hasContent && Transition.phase === "capture") root.captured++
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, root.k, 0, -(root.skew + half.edge), 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }
    }

    // Left of the opening: from past the left edge to the slanted line that
    // crosses the middle of the screen at x = w/2 - gap
    Half {
        edge: -root.skew - 10
        width: Math.max(0, root.w / 2 - root.gap + root.skew / 2 + 10)
    }

    // Right of the opening
    Half {
        edge: root.w / 2 + root.gap - root.skew / 2
        width: Math.max(0, root.w / 2 - root.gap + root.skew / 2 + 10)
    }
}
