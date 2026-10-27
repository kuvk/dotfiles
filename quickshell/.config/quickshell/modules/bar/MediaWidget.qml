import QtQuick
import qs.config
import qs.components
import qs.services

BarButton {
    id: root

    visible: Media.active !== null && Media.label !== ""
    onWheel: wheel => wheel.angleDelta.y > 0 ? Media.active?.previous() : Media.active?.next()

    Icon {
        text: Media.iconFor(Media.active)
        color: Theme.sky
    }

    StyledText {
        width: Math.min(implicitWidth, 260)
        text: Media.label
        color: Media.active?.isPlaying ? Theme.sky : Theme.overlay2
    }
}
