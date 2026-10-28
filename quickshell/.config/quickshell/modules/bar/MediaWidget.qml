import QtQuick
import qs.config
import qs.components
import qs.services

BarButton {
    id: root

    property bool shown: true

    visible: shown && Media.active !== null && Media.label !== ""
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
        // a waveform while playing, an outlined note when paused
        text: Media.active?.isPlaying ? Icons.waveform : Icons.musicOutline
        color: Media.active?.isPlaying ? Theme.sky : Theme.overlay2
    }

    StyledText {
        width: Math.min(implicitWidth, 260)
        text: Media.label
        color: Media.active?.isPlaying ? Theme.sky : Theme.overlay2
    }
}
