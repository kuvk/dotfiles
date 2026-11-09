import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Volume and brightness (Control Center): each a label with its value on the right and the
// slider under it, as the audio dropdown; the volume's label mutes it
ColumnLayout {
    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true

        Caption {
            Layout.fillWidth: true
            text: "Volume"
        }

        IconButton {
            icon: Audio.icon
            color: Theme.labelText
            size: 18
            tooltip: Audio.muted ? "Unmute" : "Mute"
            onClicked: Audio.toggleMute(Audio.sink)
        }

        Caption {
            Layout.rightMargin: 6
            text: Audio.muted ? "Muted" : `${Math.round(Audio.volume * 100)}%`
        }
    }

    SliderRow {
        value: Audio.volume
        to: 1.2
        muted: Audio.muted
        onMoved: v => Audio.setVolume(Audio.sink, v)
    }

    SectionLabel {
        Layout.topMargin: 6
        visible: System.hasBrightness
        text: "Brightness"
        value: `${Math.round(System.brightness * 100)}%`
    }

    SliderRow {
        visible: System.hasBrightness
        value: System.brightness
        onMoved: v => System.setBrightness(v)
    }
}
