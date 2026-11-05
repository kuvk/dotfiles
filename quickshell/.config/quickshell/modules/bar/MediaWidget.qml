import QtQuick
import qs.config
import qs.components
import qs.services

BarButton {
    id: root

    visible: Media.active !== null && Media.label !== ""
    onWheel: wheel => wheel.angleDelta.y > 0 ? Media.active?.previous() : Media.active?.next()

    // Small fixed-size visualizer in place of the player icon (Settings can
    // turn it off); idle bar bottoms show when nothing sounds
    CavaBars {
        anchors.verticalCenter: parent.verticalCenter
        visible: Config.cava
        width: 26
        height: Theme.iconSize
        count: 8
        spacing: 1
        minHeight: 2
    }

    Icon {
        visible: !Config.cava
        text: Media.iconFor(Media.active)
        color: Theme.sky
    }

    StyledText {
        width: Math.min(implicitWidth, 260)
        text: Media.label
        color: Media.active?.isPlaying ? Theme.sky : Theme.overlay2
    }
}
