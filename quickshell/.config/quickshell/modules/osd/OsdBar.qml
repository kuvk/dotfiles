import QtQuick
import qs.config
import qs.services

// One OSD bar: a track and its `fill` (0..1), in the accent (greyed when the OSD's entry is
// dim). Rounded ends, square where the shell's corners are (radius 0, Work-Game).
Rectangle {
    id: bar

    property real fill: 0

    implicitHeight: 6
    radius: Theme.radius > 0 ? height / 2 : 0
    color: Theme.selectedFill

    Rectangle {
        width: bar.width * bar.fill
        height: bar.height
        radius: bar.radius
        color: Osd.entry.dim ? Theme.dimText : Theme.foreground

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
