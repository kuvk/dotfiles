import QtQuick
import qs.config
import qs.services

// Every slider in the shell, value in [0, to]: the fill in the text color on a track of the
// selected fill, like every progress bar, without a knob; click, drag or scroll it. Emits
// moved() while dragging. SliderRow frames it in dropdowns; SettingSlider adds a label in
// Settings.
Item {
    id: root

    property real value: 0
    property real to: 1
    property color color: Theme.foreground
    // what a key press or a wheel step moves, in `value`'s units (5% of `to` unless set)
    property real step: to * 0.05
    // fixed values: the number of points from 0 to `to`, each marked (Ticks) and stepped to
    property int ticks: 0
    signal moved(real value)

    implicitHeight: 18
    implicitWidth: 200

    // one step from the value, kept in range; with ticks, onto the next point
    function stepped(dir: int): real {
        const size = root.ticks > 1 ? root.to / (root.ticks - 1) : root.step;
        const v = root.ticks > 1 ? Math.round(root.value / size + dir) * size : root.value + dir * size;
        return Math.max(0, Math.min(root.to, Math.round(v * 10000) / 10000));
    }

    // the keyboard: Left / Right or Ctrl+H / L by a step; Up / Down move on (Nav). With the
    // keyboard on it, the fill is the accent (no outline: it would hide the rounded ends)
    activeFocusOnTab: true
    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const dir = event.key === Qt.Key_Left || (ctrl && event.key === Qt.Key_H) ? -1 : event.key === Qt.Key_Right || (ctrl && event.key === Qt.Key_L) ? 1 : 0;
        if (dir !== 0) {
            root.moved(root.stepped(dir));
            event.accepted = true;
        }
    }

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
            color: root.activeFocus ? Theme.accent : root.color
        }
    }

    Ticks {
        anchors.verticalCenter: track.verticalCenter
        width: track.width
        trackHeight: track.height
        count: root.ticks
        level: root.value / root.to
        fillColor: root.activeFocus ? Theme.accent : root.color
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.valueAt(mouse.x));
        }
        onWheel: wheel => root.moved(root.stepped(wheel.angleDelta.y > 0 ? 1 : -1))
    }

}
