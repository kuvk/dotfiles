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
    // 10% of the screen's height above its bottom edge
    margins.bottom: Math.round((screen?.height ?? 1080) * 0.1)
    exclusionMode: ExclusionMode.Ignore
    // A level: room for the bar. A state: as wide as the widest state (Osd.labels) at the
    // current text size, so they all match; its icon and name centered.
    implicitWidth: Osd.entry.level >= 0 ? 320 : stateWidth
    readonly property int stateWidth: {
        // advanceWidth() alone doesn't update when the font changes
        labelMetrics.font;
        const widest = Math.max(...Osd.labels.map(l => labelMetrics.advanceWidth(l)));
        return Math.ceil(iconWidth + row.spacing + widest) + 2 * padding;
    }
    readonly property int iconWidth: 20
    implicitHeight: 52
    mask: Region {}
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // space between the edge and the content
    readonly property int padding: 16

    FontMetrics {
        id: labelMetrics

        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

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
            id: row

            // a level: across the box, inside the padding; a state: its own width, centered
            anchors.centerIn: parent
            width: Osd.entry.level >= 0 ? parent.width - 2 * root.padding : implicitWidth
            spacing: 12

            Icon {
                Layout.preferredWidth: root.iconWidth
                text: Osd.entry.icon
                color: Osd.entry.dim ? Theme.dimText : Theme.foreground
            }

            // a level: one bar, or one per step (the keyboard light) with an equal gap between
            RowLayout {
                Layout.fillWidth: true
                visible: Osd.entry.level >= 0
                spacing: 6

                Repeater {
                    model: Osd.entry.steps > 1 ? Osd.entry.steps : 1

                    OsdBar {
                        required property int index

                        Layout.fillWidth: true
                        // this bar's share of the level
                        fill: Osd.entry.steps > 1 ? Math.max(0, Math.min(1, Osd.entry.level * Osd.entry.steps - index)) : Math.max(0, Osd.entry.level)
                    }
                }
            }

            // a state: its name
            StyledText {
                visible: Osd.entry.level < 0
                text: Osd.entry.label
                color: Osd.entry.dim ? Theme.dimText : Theme.foreground
                elide: Text.ElideRight
            }
        }
    }
}
