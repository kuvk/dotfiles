import QtQuick
import qs.config
import qs.components
import qs.services

// One OSD bar: a track and its `fill` (0..1), in the text color (greyed when the OSD's entry is
// dim), with marks at fixed values when it has them. Rounded ends, square where the shell's corners are (radius 0, Work-Game).
Rectangle {
    id: bar

    property real fill: 0
    // fixed values: the points marked on it (Ticks), none unless set
    property int ticks: 0

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

    Ticks {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        trackHeight: bar.height
        count: bar.ticks
        level: bar.fill
        fillColor: Osd.entry.dim ? Theme.dimText : Theme.foreground
    }
}
