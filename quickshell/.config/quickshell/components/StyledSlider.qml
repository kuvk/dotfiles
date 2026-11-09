import QtQuick
import qs.config

// Minimal slider, value in [0, to]. Emits moved() while dragging. The fill and knob in the
// text color on a track of the selected fill, like every progress bar in the shell; without
// the knob (`knob: false`) it looks like a progress bar, and is dragged the same way.
Item {
    id: root

    property real value: 0
    property real to: 1
    property color color: Theme.foreground
    property bool knob: true
    signal moved(real value)

    implicitHeight: 18
    implicitWidth: 200

    function valueAt(x: real): real {
        return Math.max(0, Math.min(1, x / width)) * to;
    }

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: Theme.radius > 0 ? 3 : 0
        color: Theme.selectedFill

        Rectangle {
            width: Math.min(1, root.value / root.to) * parent.width
            height: parent.height
            radius: parent.radius
            color: root.color
        }
    }

    Rectangle {
        visible: root.knob
        x: Math.min(1, root.value / root.to) * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: Theme.radius > 0 ? 7 : 0
        color: root.color
        border.color: Theme.panelBg
        border.width: 2
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.valueAt(mouse.x));
        }
        onWheel: wheel => root.moved(Math.max(0, Math.min(root.to, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
