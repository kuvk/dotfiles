import QtQuick
import QtQuick.Layouts
import qs.config

// A slider on its own row, inset from the dropdown's edges, the row framed while the cursor is
// over it. `value`, `to` and moved() as StyledSlider's; dimmed while `muted`.
Rectangle {
    id: root

    property real value: 0
    property real to: 1
    property bool muted: false
    signal moved(real value)

    Layout.fillWidth: true
    implicitHeight: slider.implicitHeight + 16
    radius: Theme.smallRadius
    color: hover.hovered ? Theme.hoverFill : "transparent"
    border.width: hover.hovered ? Theme.controlBorder : 0
    border.color: Theme.hoverBorder

    HoverHandler {
        id: hover
    }

    StyledSlider {
        id: slider

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        value: root.value
        to: root.to
        opacity: root.muted ? 0.5 : 1
        onMoved: v => root.moved(v)
    }
}
