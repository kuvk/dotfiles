import QtQuick
import qs.config

// Every slider in the shell, value in [0, to]: the fill in the text color on a track of the
// selected fill, like every progress bar, without a knob; click, drag or scroll it. Emits
// moved() while dragging. SliderRow frames it in dropdowns; SettingSlider adds a label in
// Settings.
Item {
    id: root

    property real value: 0
    property real to: 1
    property color color: Theme.foreground
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
