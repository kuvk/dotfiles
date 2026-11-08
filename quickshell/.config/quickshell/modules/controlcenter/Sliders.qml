import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Volume and brightness sliders (Control Center)
ColumnLayout {
    Layout.fillWidth: true
    spacing: 14

    // Sliders
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        IconButton {
            icon: Audio.icon
            color: Audio.muted ? Theme.overlay1 : Theme.highlight
            onClicked: Audio.toggleMute(Audio.sink)
        }

        StyledSlider {
            Layout.fillWidth: true
            value: Audio.volume
            to: 1.2
            color: Audio.muted ? Theme.overlay0 : Theme.highlight
            onMoved: v => Audio.setVolume(Audio.sink, v)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: System.hasBrightness
        spacing: 8

        Icon {
            Layout.preferredWidth: 30
            text: Icons.sun
            color: Theme.yellow
        }

        StyledSlider {
            Layout.fillWidth: true
            value: System.brightness
            color: Theme.yellow
            onMoved: v => System.setBrightness(v)
        }
    }
}
