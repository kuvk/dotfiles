import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// One wallpaper in the carousel: a slanted slice that widens into the full card when selected (wallpaper picker)
Loader {
    id: slot

    // the wallpaper picker: the list, the selection and the card geometry
    required property var picker

    required property var modelData
    required property int index
    // fractional distance from the (animated) selection
    readonly property real d: index - picker.position
    readonly property bool isSelected: index === picker.selected
    // visible slice inside the fixed-size card
    readonly property real visibleWidth: picker.lerp(picker.cardWidth, picker.sliceWidth, d)
    readonly property real visibleHeight: picker.lerp(picker.cardHeight, picker.sliceHeight, d)
    readonly property real sliceLeft: (picker.cardWidth - visibleWidth) / 2
    readonly property real sliceTop: (picker.cardHeight - visibleHeight) / 2

    active: Math.abs(index - picker.selected) <= picker.radius
    visible: active
    z: 1000 - Math.round(Math.abs(d) * 10)
    width: picker.cardWidth
    height: picker.cardHeight
    x: (parent?.width ?? 0) / 2 + picker.centerOffset(d) - width / 2

    sourceComponent: Item {
        id: card

        // The visible parallelogram is a sheared, clipping
        // Item (stencil clip, no layers or shader masks, so it
        // survives the layer window being recreated on show).
        // The picture inside gets the inverse shear and stays
        // fixed to the card while the slice grows and shrinks.
        Item {
            id: slice

            readonly property real k: picker.skew / Math.max(1, slot.visibleHeight)

            x: slot.sliceLeft
            y: slot.sliceTop
            width: Math.max(0, slot.visibleWidth - picker.skew)
            height: slot.visibleHeight
            clip: true
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -slice.k, 0, picker.skew, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }

            Item {
                width: picker.cardWidth
                height: picker.cardHeight
                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(1, slice.k, 0, -(slot.sliceLeft + slice.k * slot.sliceTop + picker.skew), 0, 1, 0, -slot.sliceTop, 0, 0, 1, 0, 0, 0, 0, 1)
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.lighterBackground
                }

                Image {
                    anchors.fill: parent
                    source: slot.modelData.thumb ? "file://" + slot.modelData.thumb : (picker.kind === "static" ? "file://" + slot.modelData.path : "")
                    sourceSize.width: 1024
                    sourceSize.height: 640
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: !slot.modelData.thumb && picker.kind === "live"
                    text: Icons.play
                    color: Theme.dimText
                    font.pixelSize: 28
                }
            }

            // dim the slices
            Rectangle {
                anchors.fill: parent
                color: Theme.darkerBackground
                opacity: Math.min(1, Math.abs(slot.d)) * 0.45
            }
        }

        // Outline
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: slot.isSelected ? Theme.accent : Theme.alpha(Theme.darkerBackground, 0.9)
                // also smooths the clip's hard slanted edge
                strokeWidth: slot.isSelected ? Math.max(2, Theme.borderWidth) : 1.5
                startX: slot.sliceLeft + picker.skew
                startY: slot.sliceTop
                PathLine { x: slot.sliceLeft + slot.visibleWidth; y: slot.sliceTop }
                PathLine { x: slot.sliceLeft + slot.visibleWidth - picker.skew; y: slot.sliceTop + slot.visibleHeight }
                PathLine { x: slot.sliceLeft; y: slot.sliceTop + slot.visibleHeight }
                PathLine { x: slot.sliceLeft + picker.skew; y: slot.sliceTop }
            }
        }

        // Current wallpaper marker
        Rectangle {
            visible: slot.modelData.current && slot.isSelected
            x: slot.sliceLeft + slot.visibleWidth - 22
            y: slot.sliceTop + 12
            width: 10
            height: 10
            radius: 5
            color: Theme.accent
        }

        // Clicks only on the visible slice
        MouseArea {
            x: slot.sliceLeft
            y: slot.sliceTop
            width: slot.visibleWidth
            height: slot.visibleHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (slot.isSelected) {
                    picker.apply(false);
                } else {
                    picker.moved = true;
                    picker.selected = slot.index;
                }
            }
        }
    }
}
