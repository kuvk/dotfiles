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

    // explicit phases, so the overlay can never stay up if the service fails
    readonly property bool running: ["capture", "run", "reveal"].includes(SwitchFx.phase)
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
    // never takes the mouse: clicks go to whatever is underneath
    mask: Region {}
    WlrLayershell.namespace: "quickshell-transition"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onRunningChanged: {
        gap = 0;
        captured = 0;
    }

    onCapturedChanged: if (captured === 2) SwitchFx.screenReady()

    NumberAnimation on gap {
        running: SwitchFx.phase === "reveal"
        from: 0
        to: root.w / 2 + root.skew + 20
        duration: SwitchFx.revealMs
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
            id: view

            width: root.w
            height: root.h
            live: false
            onHasContentChanged: if (hasContent && SwitchFx.phase === "capture") root.captured++
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, root.k, 0, -(root.skew + half.edge), 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }

            // Set per phase, as a binding on hasContent would loop. Without a frame
            // by the end of the capture phase the source goes, so it can't capture
            // the new look late.
            Connections {
                target: SwitchFx

                function onPhaseChanged(): void {
                    if (SwitchFx.phase === "capture")
                        view.captureSource = root.screen;
                    else if (SwitchFx.phase === "idle" || !view.hasContent)
                        view.captureSource = null;
                }
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
