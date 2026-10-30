import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

RowLayout {
    id: root

    required property PwNode node
    property string icon

    Layout.fillWidth: true
    spacing: 8
    visible: node !== null

    IconButton {
        icon: root.icon
        color: root.node?.audio?.muted ? Theme.overlay1 : Theme.highlight
        onClicked: Audio.toggleMute(root.node)
    }

    StyledSlider {
        Layout.fillWidth: true
        value: root.node?.audio?.volume ?? 0
        to: 1.2
        color: root.node?.audio?.muted ? Theme.overlay0 : Theme.highlight
        onMoved: v => Audio.setVolume(root.node, v)
    }
}
