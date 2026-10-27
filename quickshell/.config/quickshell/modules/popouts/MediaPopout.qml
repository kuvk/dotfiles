import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

Popout {
    id: root

    name: "media"
    contentWidth: 380

    MediaCard {
        Layout.fillWidth: true
    }

    StyledText {
        visible: Media.players.length > 1
        text: "Players"
        color: Theme.subtext0
        font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
        model: Media.players.length > 1 ? Media.players : []

        ListItem {
            required property MprisPlayer modelData

            icon: Media.iconFor(modelData)
            label: modelData.identity
            sublabel: modelData.trackTitle ?? ""
            highlighted: modelData === Media.active
            implicitHeight: 40
            onClicked: Media.pinned = modelData
        }
    }
}
